import "package:flutter/services.dart";

class TrackInfo {
  static const _platform = MethodChannel("com.haruka.mp3_player/media_metadata", JSONMethodCodec());

  final String path;

  String? album;
  String? albumArtist;
  String? artist;
  String? author;
  String? compilation;
  String? composer;
  String? date;
  String? duration;
  String? genre;
  String? mimetype;
  String? title;
  String? year;

  String? thumbnailPath;

  TrackInfo._({required this.path});

  void update({required Map<String, String?> info, String? thumbnailPath}) {
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
    title = info["title"];
    year = info["year"];
    this.thumbnailPath = thumbnailPath;
  }

  Future<void> fetch() async {
    var info = await _platform.invokeMapMethod<String, String?>("extractMetadata", {"path": path}) ?? <String, String?>{};
    var thumbnailData = await _platform.invokeMapMethod<String, String?>("getEmbeddedPicture", {"path": path});
    update(info: info, thumbnailPath: thumbnailData?["path"]);
  }

  static Future<TrackInfo> extractInfo(String path) async {
    var trackInfo = TrackInfo._(path: path);
    await trackInfo.fetch();
    return trackInfo;
  }
}
