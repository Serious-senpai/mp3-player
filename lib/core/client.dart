import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:assets_audio_player/assets_audio_player.dart";
import "package:async_locks/async_locks.dart";
import "package:audiotagger/audiotagger.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:rxdart/rxdart.dart";
import "package:sqflite/sqflite.dart";

import "playlists.dart";
import "tracks.dart";
import "utils.dart";

class _PlayingInfo {
  /// The playing playlist
  PlaylistData? get playlist => state.value.first;

  /// The playing index
  int? get index => state.value.second;

  /// The playing track
  Track? get track => isPlaying ? playlist![index!] : null;

  final _player = AssetsAudioPlayer();
  final _completer = Event();
  final _rng = Random();

  /// [ValueNotifier] of the current playing track
  final state = ValueNotifier<Pair<PlaylistData?, int?>>(Pair<PlaylistData?, int?>(null, null));

  /// Whether the player is currently playing a track
  bool get isPlaying => playlist != null && index != null;

  bool _repeatOne = false;
  bool _shuffle = false;

  bool get repeatOne => _repeatOne;
  bool get shuffle => _shuffle;

  /// The stream of [RealtimePlayingInfos] for stream builders to listen to
  ValueStream<RealtimePlayingInfos> get realtimePlayingInfos => _player.realtimePlayingInfos;

  bool _stopRequest = true;

  int? _indexUpdate;

  _PlayingInfo() {
    _completer.set();
  }

  void update(PlaylistData? playlist, int? index) {
    state.value = Pair<PlaylistData?, int?>(playlist, index);
  }

  Future<void> play({required PlaylistData playlist, required int index}) async {
    if (isPlaying) await stop();

    update(playlist, index);
    Directory? tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } on MissingPlatformDirectoryException {
      // pass
    }

    _stopRequest = _repeatOne = _shuffle = false;
    while (!_stopRequest) {
      var track = this.track!;

      String? thumbnailPath;
      if (tempDir != null && track.thumbnail != null) {
        thumbnailPath = join(tempDir.path, "${track.title}.jpg");
        await File(thumbnailPath).writeAsBytes(track.thumbnail!);
      }

      var audio = Audio.file(
        track.path,
        metas: Metas(
          title: track.title,
          artist: track.artist,
          album: track.album,
          image: thumbnailPath != null
              ? MetasImage(
                  path: thumbnailPath,
                  type: ImageType.file,
                )
              : null,
        ),
      );

      _completer.clear();
      await _player.open(
        audio,
        showNotification: true,
        notificationSettings: NotificationSettings(
          customNextAction: (_) async => next(),
          customPlayPauseAction: (_) async => playOrPause(),
          customPrevAction: (_) async => previous(),
          customStopAction: (_) async => stop(),
        ),
        playInBackground: PlayInBackground.enabled,
        audioFocusStrategy: const AudioFocusStrategy.request(resumeAfterInterruption: true),
        forceOpen: true,
      );
      var subscription = _player.playlistAudioFinished.listen(
        (event) {
          _completer.set();
          if (_stopRequest) return;
          if (_indexUpdate == null) {
            if (_repeatOne) {
              _indexUpdate = 0;
            } else if (_shuffle) {
              _indexUpdate = _rng.nextInt(playlist.length);
            } else {
              _indexUpdate = 1;
            }
          }

          updateIndex(_indexUpdate!);
          _indexUpdate = null;
        },
      );

      await _completer.wait();
      subscription.cancel();
    }
  }

  Future<void> stop() async {
    _stopRequest = true;
    await _player.stop();
    update(null, null);
  }

  Future<void> previous() async {
    _indexUpdate = -1;
    await _player.stop();
  }

  Future<void> next() async {
    _indexUpdate = 1;
    await _player.stop();
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> playOrPause() => _player.playOrPause();
  Future<void> seek(Duration value) => _player.seek(value);

  void toggleRepeat() => _repeatOne = !_repeatOne;
  void toggleShuffle() => _shuffle = !_shuffle;

  void updateIndex(int change) {
    if (isPlaying) {
      var length = playlist!.length, index = this.index! + change;

      if (index < 0) {
        index += length * (-index / length).ceil();
      }

      index %= length;
      update(playlist, index);
    }
  }
}

class Client {
  /// The local SQLite database
  final Database database;

  /// [Audiotagger] to fetch tags from MP3 files
  final tagger = Audiotagger();

  final _playlistCache = <int, PlaylistData>{};
  final _trackCache = <String, Track>{};

  /// Information about the current track
  final playingInfo = _PlayingInfo();

  Client(this.database);

  /// Fetch a playlist (if exists) from the database with the given [id]
  Future<PlaylistData?> fetchPlaylist(int id) async {
    var result = await database.query(
      "playlists",
      distinct: true,
      where: "id = ?",
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      assert(result.length == 1);
      return playlistFromRow(result[0]);
    }

    return null;
  }

  /// Fetch all playlists from the database
  Future<List<PlaylistData>> fetchPlaylists() async {
    var playlists = <PlaylistData>[];
    var results = await database.query("playlists", distinct: true);
    for (var result in results) {
      playlists.add(await playlistFromRow(result));
    }

    return playlists;
  }

  /// Construct a playlist from a database row
  Future<PlaylistData> playlistFromRow(Map<String, dynamic> row) async {
    if (_playlistCache[row["id"]] != null) {
      return _playlistCache[row["id"]]!;
    }

    var tracks = <Track>[];
    for (String path in jsonDecode(row["items"])) {
      var track = await createTrack(path);
      if (track != null) {
        tracks.add(track);
      }
    }

    return _playlistCache[row["id"]] = PlaylistData(row["id"], row["name"], tracks, DateTime.parse(row["created_at"]), this);
  }

  /// Remove a [PlaylistData] from the cache and the database
  ///
  /// The [fetchPlaylists] method is then reloaded in [futureSingleton]
  Future<void> removePlaylist(int id) async {
    _playlistCache.remove(id);
    await database.delete(
      "playlists",
      where: "id = ?",
      whereArgs: [id],
    );

    futureSingleton.reloadFuture(fetchPlaylists);
  }

  /// Create a new playlist
  Future<PlaylistData> createPlaylist(String name) async {
    var id = await database.insert(
      "playlists",
      {
        "name": name,
        "items": "[]",
        "created_at": DateTime.now().toIso8601String(),
      },
    );

    futureSingleton.reloadFuture(fetchPlaylists);

    var result = await fetchPlaylist(id);
    return result!;
  }

  /// Create a [Track] from a local path
  Future<Track?> createTrack(String path) async {
    if (_trackCache[path] != null) {
      return _trackCache[path];
    }

    if (!await checkPath(path)) {
      return null;
    }

    var tag = await tagger.readTags(path: path);
    var title = basenameWithoutExtension(path);
    if (tag != null && tag.title != null && tag.title!.isNotEmpty) {
      title = tag.title!;
    }

    return _trackCache[path] = Track(
      path: path,
      title: title,
      artist: tag?.artist,
      album: tag?.album,
      thumbnail: await tagger.readArtwork(path: path),
      client: this,
    );
  }

  Future<void> play({required PlaylistData playlist, required int index}) => playingInfo.play(playlist: playlist, index: index);
  Future<void> previous() => playingInfo.previous();
  Future<void> next() => playingInfo.next();
  Future<void> resume() => playingInfo.resume();
  Future<void> pause() => playingInfo.pause();
  Future<void> stop() => playingInfo.stop();
  Future<void> seek(Duration value) => playingInfo.seek(value);
  void toggleRepeat() => playingInfo.toggleRepeat();
  void toggleShuffle() => playingInfo.toggleShuffle();

  /// Create a [Client] instance
  static Future<Client> create() async {
    var databaseDir = await getDatabasesPath();
    var database = await openDatabase(
      join(databaseDir, "mp3_player.db"),
      version: 1,
      onCreate: (database, version) async {
        var batch = database.batch();
        batch.execute("CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, items TEXT NOT NULL, created_at TEXT NOT NULL)");

        await batch.commit(noResult: true);
      },
    );

    return Client(database);
  }
}
