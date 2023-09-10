import "dart:convert";

import "package:http/http.dart";

import "channels.dart";
import "client.dart";

/// Represents a YouTube video when only title and ID are available.
///
/// This is the instance obtained from https://docs.invidious.io/api/common_types/#playlistobject (see "videos")
class PartialVideo {
  static final Uri _analyzer = Uri.https("www.y2mate.com", "/mates/analyzeV2/ajax");
  static final Uri _converter = Uri.https("www.y2mate.com", "/mates/convertV2/index");

  final String title;
  final String videoId;

  final YouTubeClient _client;

  PartialVideo._(this.title, this.videoId, this._client);
  PartialVideo.fromJson(
    Map<String, dynamic> data, {
    required YouTubeClient client,
  })  : title = data["title"],
        videoId = data["videoId"],
        _client = client;

  Uri get uri => Uri.https("www.youtube.com", "/watch", {"v": videoId});
  Uri get thumbnailUri => Uri.https("img.youtube.com", "/vi_webp/$videoId/hqdefault.webp");

  Future<String?> getAudioUrl() async {
    var key = await _analyze();
    if (key != null) return await _convert(key);

    return null;
  }

  Future<String?> _analyze() async {
    for (var i = 0; i < 3; i++) {
      try {
        var response = await _client.http.post(_analyzer, body: {"k_query": uri.toString(), "k_page": "mp3", "hl": "en"});
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        return data["links"]["mp3"]["mp3128"]["k"] as String;
      } on Object {
        // pass
      }
    }

    return null;
  }

  Future<String?> _convert(String key) async {
    for (var i = 0; i < 3; i++) {
      try {
        var response = await _client.http.post(_converter, body: {"vid": videoId, "k": key});
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        return data["dlink"] as String;
      } on Object {
        // pass
      }
    }

    return null;
  }

  Future<Video?> toVideo() => Video.get(videoId, client: _client);
}

/// Represents a YouTube video
///
/// See available fields:
/// - https://docs.invidious.io/api/common_types/#videoobject
/// - https://docs.invidious.io/api/#get-apiv1channelssearchucid
class Video extends PartialVideo {
  static final _cache = <String, Video>{};

  final PartialChannel channel;
  final String description;
  final int viewCount;
  final int lengthSeconds;
  final String publishedText;

  Video._(
    String title,
    String videoId,
    this.channel,
    this.description,
    this.viewCount,
    this.lengthSeconds,
    this.publishedText,
    YouTubeClient client,
  ) : super._(title, videoId, client);

  factory Video.fromJson(Map<String, dynamic> data, {required YouTubeClient client}) {
    var videoId = data["videoId"] as String;
    var cached = _cache[videoId];
    if (cached != null) return cached;

    return _cache[videoId] = Video._(
      data["title"],
      videoId,
      PartialChannel.fromJson(data, client: client),
      data["description"],
      data["viewCount"],
      data["lengthSeconds"],
      data["publishedText"],
      client,
    );
  }

  static Future<Video?> get(String videoId, {required YouTubeClient client}) async {
    var cached = _cache[videoId];
    if (cached != null) return cached;

    var response = await client.get(
      pathSegments: ["api", "v1", "videos", videoId],
      queryParameters: {"fields": "title,videoId,author,authorId,description,viewCount,lengthSeconds,publishedText"},
    );

    if (response == null) return null;
    return Video.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>, client: client);
  }
}
