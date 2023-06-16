import "dart:convert";

import "package:async_locks/async_locks.dart";

import "state.dart";
import "tracks.dart";

class Playlist {
  static final playlists = <int, Playlist>{};
  static final _playlistsLock = Lock();
  static final _streamEvent = Event();
  static Stream<List<Playlist>>? _playlistsStream;
  static Stream<List<Playlist>> get playlistsStream => _playlistsStream ??= _playlistsStreamImpl().asBroadcastStream();

  static Stream<List<Playlist>> _playlistsStreamImpl() async* {
    while (true) {
      yield List<Playlist>.from(playlists.values);
      await _streamEvent.wait();
      _streamEvent.clear();
    }
  }

  final int id;

  String _title;
  String get title => _title;

  final List<Track> items;
  final DateTime createdAt;

  final ApplicationState _state;

  bool get isPlaying => _state.currentPlaylist == this;
  int? get playingIndex => isPlaying ? _state.index : null;

  String? get thumbnailPath {
    for (var item in items) {
      var path = item.trackInfo.thumbnailPath;
      if (path != null) return path;
    }

    return null;
  }

  String get displayArtist {
    var artists = <String>[];
    for (var item in items) {
      var artist = item.trackInfo.artist;
      if (artist != null) {
        artists.add(artist);
        if (artists.length == 2) break;
      }
    }

    if (artists.isNotEmpty) {
      var result = artists.join(", ");
      result += " and more";
      return result;
    }

    return "Unknown artists";
  }

  Playlist._({required this.id, required String title, required this.items, required this.createdAt, required ApplicationState state})
      : _title = title,
        _state = state {
    playlists[id] = this;
  }

  Future<void> add(Track track) => addAll([track]);

  Future<void> addAll(Iterable<Track> tracks) async {
    items.addAll(tracks);
    await push();

    if (isPlaying) {
      await _state.update(playlist: this);
    }
  }

  Future<void> rename(String newTitle) async {
    _title = newTitle;
    await push();
  }

  Future<void> remove(int index) async {
    items.removeAt(index);

    if (isPlaying && index < _state.index) {
      await _state.update(playlist: this, index: _state.index - 1);
    }

    await push();
  }

  Future<void> push() async {
    await _state.database.update(
      "playlists",
      {
        "id": id,
        "title": _title,
        "items": jsonEncode(List<String>.generate(items.length, (index) => items[index].uri)),
        "created_at": createdAt.toIso8601String(),
      },
      where: "id = ?",
      whereArgs: [id],
    );

    _streamEvent.set();
  }

  static Future<Playlist> fromRow(Map<String, dynamic> row, {required ApplicationState state}) async {
    var result = await _playlistsLock.run(
      () async {
        var cached = playlists[row["id"]];
        if (cached != null) return cached;

        var rawItems = List<String>.from(jsonDecode(row["items"]));
        var items = <Track>[];
        for (var path in rawItems) {
          var track = await Track.fromPath(path);
          if (track != null) {
            items.add(track);
          }
        }

        return Playlist._(id: row["id"], title: row["title"], items: items, createdAt: DateTime.parse(row["created_at"]), state: state);
      },
    );

    _streamEvent.set();
    return result;
  }

  static Future<Playlist> fromId(int id, {required ApplicationState state}) async {
    var cached = playlists[id];
    if (cached != null) return cached;

    var rows = await state.database.query("playlists", where: "id = ?", whereArgs: [id]);
    return await fromRow(rows.single, state: state);
  }

  static Future<Playlist> create(String title, {required ApplicationState state}) async {
    var id = await state.database.insert(
      "playlists",
      {
        "title": title,
        "items": "[]",
        "created_at": DateTime.now().toIso8601String(),
      },
    );

    return await fromId(id, state: state);
  }

  static Future<List<Playlist>> fetchAll({required ApplicationState state}) async {
    var rows = await state.database.query("playlists");
    var results = <Playlist>[];
    for (var row in rows) {
      results.add(await fromRow(row, state: state));
    }

    _streamEvent.set();
    return results;
  }

  @override
  bool operator ==(covariant Playlist other) {
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
