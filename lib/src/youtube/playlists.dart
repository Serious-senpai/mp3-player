import "dart:convert";

import "channels.dart";
import "client.dart";
import "videos.dart";

/// Represents a YouTube playlist
///
/// See available fields:
/// - https://docs.invidious.io/api/common_types/#playlistobject
/// - https://docs.invidious.io/api/#get-apiv1search
class Playlist {
  final String title;
  final String playlistId;
  final PartialChannel channel;
  final List<PartialVideo> videos;

  final YouTubeClient _client;

  Playlist.fromJson(Map<String, dynamic> data, {required YouTubeClient client})
      : title = data["title"],
        playlistId = data["playlistId"],
        channel = PartialChannel.fromJson(data, client: client),
        videos = List<PartialVideo>.from(
          List<Map<String, dynamic>>.from(
            data["videos"],
          ).map(
            (e) => PartialVideo.fromJson(e, client: client),
          ),
        ),
        _client = client;

  Uri? get thumbnailUri => videos.isNotEmpty ? videos[0].thumbnailUri : null;

  static Future<Playlist?> get(String playlistId, {required YouTubeClient client}) async {
    var response = await client.get(
      pathSegments: ["api", "v1", "playlists", playlistId],
      queryParameters: {"fields": "title,playlistId,author,authorId,videos"},
    );

    if (response == null) return null;
    var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return Playlist.fromJson(data, client: client);
  }
}
