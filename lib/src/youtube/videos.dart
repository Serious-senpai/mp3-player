import "dart:convert";

import "client.dart";

/// Represents a YouTube video when only title and ID are available.
///
/// This is the instance obtained from https://docs.invidious.io/api/common_types/#playlistobject (see "videos")
class PartialVideo {
  final String title;
  final String videoId;

  final YouTubeClient _client;

  Uri get thumbnailUri => Uri.https("img.youtube.com", "/vi_webp/$videoId/mqdefault.webp");

  PartialVideo.fromJson(Map<String, dynamic> data, {required YouTubeClient client})
      : title = data["title"],
        videoId = data["videoId"],
        _client = client;
}

/// Represents a YouTube video
///
/// See available fields:
/// - https://docs.invidious.io/api/common_types/#videoobject
/// - https://docs.invidious.io/api/#get-apiv1channelssearchucid
class Video extends PartialVideo {
  final String author;
  final String authorId;
  final String description;
  final int viewCount;
  final int lengthSeconds;
  final String publishedText;

  Video.fromJson(Map<String, dynamic> data, {required YouTubeClient client})
      : author = data["author"],
        authorId = data["authorId"],
        description = data["description"],
        viewCount = data["viewCount"],
        lengthSeconds = data["lengthSeconds"],
        publishedText = data["publishedText"],
        super.fromJson(data, client: client);

  static Future<Video?> get(String videoId, {required YouTubeClient client}) async {
    var response = await client.get(
      pathSegments: ["api", "v1", "videos", videoId],
      queryParameters: {"fields": "title,videoId,author,authorId,description,viewCount,lengthSeconds,publishedText"},
    );

    if (response == null) return null;
    return Video.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>, client: client);
  }
}
