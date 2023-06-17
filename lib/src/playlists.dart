import "dart:convert";

import "package:async_locks/async_locks.dart";

import "state.dart";
import "tracks.dart";

/// Represents a playlist, which contains a list of playable [Track]s
class Playlist {
  /// Mapping of IDs to their corresponding [Playlist]s
  static final playlists = <int, Playlist>{};
  static final _playlistsLock = Lock();
  static final _streamEvent = Event();
  static Stream<List<Playlist>>? _playlistsStream;

  /// A [Stream] that broadcast data about the state of all [Playlist]s
  static Stream<List<Playlist>> get playlistsStream => _playlistsStream ??= _playlistsStreamImpl().asBroadcastStream();

  static Stream<List<Playlist>> _playlistsStreamImpl() async* {
    while (true) {
      yield List<Playlist>.from(playlists.values);
      await _streamEvent.wait();
      _streamEvent.clear();
    }
  }

  /// The playlist unique ID
  final int id;

  String _title;

  /// The playlist title
  String get title => _title;

  /// List of [Track]s in this playlist
  final List<Track> items;

  /// The [DateTime] when this playlist was created
  final DateTime createdAt;

  final ApplicationState _state;

  /// Whether one of the [Track]s in this playlist is currently being played by the application
  bool get isPlaying => _state.currentPlaylist == this;

  /// The index of the [Track] that is currently being played, will be `null` if [isPlaying] is `false`
  int? get playingIndex => isPlaying ? _state.index : null;

  /// The artwork (thumbnail) of this playlist
  ///
  /// This is the artwork of the first [Track] in [items] that has one. If no [Track] owns an artwork,
  /// `null` is returned
  String? get thumbnailPath {
    for (var item in items) {
      var path = item.trackInfo.thumbnailPath;
      if (path != null) return path;
    }

    return null;
  }

  /// Returns a [String] displaying the artists of the [Track]s in [items]
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

  /// Add a [Track] to this playlist
  Future<void> add(Track track) => addAll([track]);

  /// Add a number of [Track]s to this playlist
  Future<void> addAll(Iterable<Track> tracks) async {
    items.addAll(tracks);
    await push();

    if (isPlaying) {
      await _state.update(playlist: this);
    }
  }

  /// Rename this playlist (i.e. change its [title])
  Future<void> rename(String newTitle) async {
    _title = newTitle;
    await push();
  }

  /// Remove a [Track] from this playlist
  Future<void> remove(int index) async {
    items.removeAt(index);

    if (isPlaying && index < _state.index) {
      await _state.update(playlist: this, index: _state.index - 1);
    }

    await push();
  }

  /// Sync this playlist data to the local database
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

  /// Delete this playlist
  Future<void> delete() async {
    await _state.database.delete(
      "playlists",
      where: "id = ?",
      whereArgs: [id],
    );

    playlists.remove(id);
    if (isPlaying) {
      await _state.stop();
    }

    _streamEvent.set();
  }

  /// Construct a [Playlist] from a database row
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

  /// Construct a [Playlist] from its ID
  ///
  /// Throws [StateError] if no such [Playlist] is found
  static Future<Playlist> fromId(int id, {required ApplicationState state}) async {
    var cached = playlists[id];
    if (cached != null) return cached;

    var rows = await state.database.query("playlists", where: "id = ?", whereArgs: [id]);
    return await fromRow(rows.single, state: state);
  }

  /// Create a new [Playlist] and return it
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

  /// Fetch all [Playlist]s in the database
  static Future<List<Playlist>> fetchAll({required ApplicationState state}) async {
    var rows = await state.database.query("playlists");
    var results = <Playlist>[];
    for (var row in rows) {
      results.add(await fromRow(row, state: state));
    }

    _streamEvent.set();
    return results;
  }

  /// Compare this object to another [Playlist]
  ///
  /// Two [Playlist]s are considered equal if they have the same [id]
  @override
  bool operator ==(covariant Playlist other) {
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
