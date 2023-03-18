import "dart:async";
import "dart:io";
import "dart:math";

import "package:assets_audio_player/assets_audio_player.dart";
import "package:async_locks/async_locks.dart";
import "package:audiotagger/audiotagger.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart";
import "package:rxdart/rxdart.dart";
import "package:sqflite/sqflite.dart";

import "playlists.dart";
import "tracks.dart";
import "utils.dart";
import "youtube.dart";

/// Display the current process of the audio player
class PlayingInfo {
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

  /// Whether we are looping over a track
  bool get repeatOne => _repeatOne;

  /// Whether we are playing tracks from a playlist in a random order
  bool get shuffle => _shuffle;

  /// The stream of [RealtimePlayingInfos] for stream builders to listen to
  ValueStream<RealtimePlayingInfos> get realtimePlayingInfos => _player.realtimePlayingInfos;

  bool _stopRequest = true;

  int? _indexUpdate;

  /// Initialize a new [PlayingInfo] instance
  PlayingInfo() {
    _completer.set();
  }

  /// Update the current playing track
  void update(PlaylistData? playlist, int? index) {
    state.value = Pair<PlaylistData?, int?>(playlist, index);
  }

  /// Stop a the playing track (if any) and play a new one.
  ///
  /// This method set [repeatOne] and [shuffle] back to false.
  Future<void> play({required PlaylistData playlist, required int index}) async {
    if (isPlaying) await stop();

    update(playlist, index);

    _stopRequest = _repeatOne = _shuffle = false;
    while (!_stopRequest) {
      var track = this.track!;

      var audio = await track.toAudio();
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

  /// Stop the internal player
  Future<void> stop() async {
    _stopRequest = true;
    await _player.stop();
    update(null, null);
  }

  /// Skip to the previous track in the playlist
  Future<void> previous() async {
    _indexUpdate = -1;
    await _player.stop();
  }

  /// Skip to the next track in the playlist
  Future<void> next() async {
    _indexUpdate = 1;
    await _player.stop();
  }

  /// Pause the current playing track
  Future<void> pause() => _player.pause();

  /// Resume the current playing track
  Future<void> resume() => _player.play();

  /// Toggle between [pause] and [resume]
  Future<void> playOrPause() => _player.playOrPause();

  /// Seek the current track to a specific position
  Future<void> seek(Duration value) => _player.seek(value);

  /// Toggle [repeatOne]
  void toggleRepeat() => _repeatOne = !_repeatOne;

  /// Toggle [shuffle]
  void toggleShuffle() => _shuffle = !_shuffle;

  /// Update [index] by a specific change
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

/// This is the heart of the application that manages all operations of the backend
class MP3Client {
  /// The local SQLite database
  final Database database;

  /// [Audiotagger] to fetch tags from MP3 files
  final tagger = Audiotagger();

  /// Information about the current track
  final playingInfo = PlayingInfo();

  /// The [YouTubeClient] to access content from YouTube, will be null when Internet
  /// is not available
  YouTubeClient? ytClient;

  Future<List<PlaylistData>>? _fetchPlaylistsFuture;

  /// A [Future] of [fetchPlaylists] for a future builder to listen to
  Future<List<PlaylistData>> get fetchPlaylistsFuture => _fetchPlaylistsFuture = _fetchPlaylistsFuture ?? PlaylistData.fetchPlaylists(client: this);

  /// Construct a new [MP3Client]
  MP3Client(this.database);

  /// Initialize the internal [YouTubeClient] if it hasn't been initialized yet
  ///
  /// May throw [SocketException] if Internet is not available
  Future<void> initializeYtClient() async {
    if (ytClient == null) {
      ytClient = await YouTubeClient.create(this);
      PlaylistData.clearCache();
      Track.clearCache();
      updateFetchPlaylistsFuture();
    }
  }

  /// Refresh [fetchPlaylistsFuture]
  void updateFetchPlaylistsFuture() {
    _fetchPlaylistsFuture = PlaylistData.fetchPlaylists(client: this);
  }

  /// See [PlayingInfo.play]
  Future<void> play({required PlaylistData playlist, required int index}) => playingInfo.play(playlist: playlist, index: index);

  /// See [PlayingInfo.previous]
  Future<void> previous() => playingInfo.previous();

  /// See [PlayingInfo.next]
  Future<void> next() => playingInfo.next();

  /// See [PlayingInfo.resume]
  Future<void> resume() => playingInfo.resume();

  /// See [PlayingInfo.pause]
  Future<void> pause() => playingInfo.pause();

  /// See [PlayingInfo.stop]
  Future<void> stop() => playingInfo.stop();

  /// See [PlayingInfo.seek]
  Future<void> seek(Duration value) => playingInfo.seek(value);

  /// See [PlayingInfo.toggleRepeat]
  void toggleRepeat() => playingInfo.toggleRepeat();

  /// See [PlayingInfo.toggleShuffle]
  void toggleShuffle() => playingInfo.toggleShuffle();

  /// Create a [MP3Client] instance and attempt to initialize [ytClient]
  static Future<MP3Client> create() async {
    var databaseDir = await getDatabasesPath();
    var database = await openDatabase(
      join(databaseDir, "mp3_player.db"),
      onOpen: (database) async {
        var batch = database.batch();
        batch.execute("CREATE TABLE IF NOT EXISTS playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, items TEXT NOT NULL, created_at TEXT NOT NULL);");
        batch.execute("CREATE TABLE IF NOT EXISTS youtube (id TEXT PRIMARY KEY, title TEXT NOT NULL);");

        await batch.commit(noResult: true);
      },
    );

    var result = MP3Client(database);
    try {
      result.initializeYtClient();
    } on SocketException {
      // pass
    }

    await PlaylistData.fetchPlaylists(client: result);
    return result;
  }
}
