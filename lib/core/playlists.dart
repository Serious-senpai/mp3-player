import "dart:convert";

import "package:async_locks/async_locks.dart";

import "client.dart";
import "tracks.dart";

final _playlistsUpdateEvent = Event();
Stream<void> _playlistsStream() async* {
  while (true) {
    await _playlistsUpdateEvent.wait();
    _playlistsUpdateEvent.clear();
  }
}

Stream<void>? _playlistsStreamInstance;
Stream<void> playlistsUpdateSignal() => _playlistsStreamInstance = _playlistsStreamInstance ?? _playlistsStream().asBroadcastStream();

void updatePlaylists() => _playlistsUpdateEvent.set();

/// Represents a playlist, which is a collection of [Track]s
class PlaylistData {
  final int _id;
  String _name;
  final List<Track> _tracks;
  final DateTime _createdAt;

  /// The length of the playlist
  int get length => _tracks.length;

  /// ID of this playlist in the database
  int get id => _id;

  /// The playlist's name
  String get name => _name;

  /// Tracks of this playlist
  List<Track> get tracks => _tracks;

  /// When the playlist was created
  DateTime get createdAt => _createdAt;

  @override
  int get hashCode => _id.hashCode;

  /// Whether this playlist is being played
  bool get playing => this == _state.playingInfo.playlist;

  final MP3Client _state;

  PlaylistData(this._id, this._name, this._tracks, this._createdAt, this._state);

  /// A [String] displaying the artists of this playlist's tracks
  String get displayArtists {
    var artists = <String>{};
    for (var track in tracks) {
      if (track.artist != null) {
        artists.add(track.artist!);
        if (artists.length > 2) {
          break;
        }
      }
    }

    if (artists.length == 3) {
      var artistsList = List<String>.from(artists);
      artistsList.removeLast();

      return "${artistsList.join(", ")} and more";
    }

    if (artists.isEmpty) {
      return "No artists found";
    }

    return artists.join(", ");
  }

  /// Push data from this instance to the database
  Future<void> push() => _state.database.update(
        "playlists",
        {
          "id": id,
          "name": name,
          "items": jsonEncode(
            List<String>.generate(
              tracks.length,
              (index) => tracks[index].databaseUri,
            ),
          ),
          "created_at": createdAt.toIso8601String(),
        },
        where: "id = ?",
        whereArgs: [id],
      );

  /// Remove this playlist from the database
  Future<void> removePlaylist() => _state.database.delete("playlists", where: "id = ?", whereArgs: [id]);

  /// Add a [Track] to this playlist and immediately [push] to the database
  Future<void> add(Track track) => addAll([track]);

  /// Add a number of [Track]s to this playlist and immediately [push] to the database
  Future<void> addAll(Iterable<Track> tracks) {
    this.tracks.addAll(tracks);
    return push();
  }

  /// Remove a [Track] at [index]
  Future<void> remove(int index) async {
    tracks.removeAt(index);
    if (playing) {
      if (index < _state.playingInfo.index!) {
        _state.playingInfo.updateIndex(-1);
      }
    }
    await push();
  }

  /// Remove all [Track]s from this playlist and immediately [push] to the database
  Future<void> clear() async {
    tracks.clear();
    await push();
  }

  /// Rename this playlist
  Future<void> rename(String newName) async {
    _name = newName;
    await push();
  }

  Track operator [](int index) => tracks[index];

  @override
  bool operator ==(dynamic other) {
    return other is PlaylistData && other.id == id;
  }

  @override
  String toString() => "<PlaylistData id=$id name=$name tracks = $_tracks>";
}
