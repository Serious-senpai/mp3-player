import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:sqflite/sqflite.dart";

import "state.dart";
import "tracks.dart";

/// Contains the metadata of a [Track], obtained from the native side
///
/// See also: https://developer.android.com/reference/android/media/MediaMetadataRetriever
class TrackInfo {
  static const _platform = MethodChannel("com.haruka.mp3_player/media_metadata", JSONMethodCodec());

  /// The path of the [Track] in the filesystem (should be the same as [Track.uri])
  final String path;

  /// The track's album
  String? album;

  /// The track's album artist
  String? albumArtist;

  /// The track's artist
  String? artist;

  /// The track's author
  String? author;

  /// The track's compilation status
  String? compilation;

  /// The track's composer
  String? composer;

  /// The track's created or modified date
  String? date;

  /// The track's duration
  String? duration;

  /// The track's genre
  String? genre;

  /// The track's MIME type
  String? mimetype;

  /// The track's title
  String? title;

  /// The track's created or modified year
  String? year;

  /// Path to the thumbnail of the track
  String? thumbnailPath;

  final ApplicationState _state;

  TrackInfo._({required this.path, required ApplicationState state}) : _state = state;

  /// Update this track with provided metadata and [thumbnailPath]
  void update({Map<String, String?>? info, String? title, String? thumbnailPath}) {
    if (info != null) {
      album = info["album"];
      albumArtist = info["album_artist"];
      artist = info["artist"];
      author = info["author"];
      compilation = info["compilation"];
      composer = info["composer"];
      date = info["date"];
      duration = info["duration"];
      genre = info["genre"];
      mimetype = info["mimetype"];
      // title = info["title"];
      year = info["year"];
    }

    this.title = title;
    if (thumbnailPath != null) {
      this.thumbnailPath = thumbnailPath;
    }
  }

  Future<void> editTitle(String newTitle) {
    title = newTitle;
    return _state.database.update("titles", {"title": newTitle}, where: "path = ?", whereArgs: [path]);
  }

  /// Fetch information from [path] and [update] this track metadata
  Future<void> fetch() async {
    var info = await _platform.invokeMapMethod<String, String?>("extractMetadata", {"path": path}) ?? <String, String?>{};
    var thumbnailData = await _platform.invokeMapMethod<String, String?>("getEmbeddedPicture", {"path": path});

    var rows = await _state.database.query("titles", where: "path = ?", whereArgs: [path]);
    if (rows.isEmpty) {
      await _state.database.insert(
        "titles",
        {"path": path, "title": info["title"] ?? basenameWithoutExtension(path)},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      rows = await _state.database.query("titles", where: "path = ?", whereArgs: [path]);
    }

    update(info: info, title: rows.single["title"] as String, thumbnailPath: thumbnailData?["path"]);
  }

  /// Extract metadata of a given audio file at [path]
  static Future<TrackInfo> extractInfo(String path, {required ApplicationState state}) async {
    var trackInfo = TrackInfo._(path: path, state: state);
    await trackInfo.fetch();
    return trackInfo;
  }
}
