import "dart:convert";

import "channels.dart";
import "client.dart";
import "playlists.dart";
import "videos.dart";

enum SearchType {
  video,
  playlist,
  channel, // Not yet implemented, just putting it here for now
}

extension AsString on SearchType {
  String asString() {
    return toString().split(".").last;
  }
}

/// Represents a search result from YouTube
///
/// https://docs.invidious.io/api/#get-apiv1search
class SearchResult {
  final List<Channel> channels;
  final List<Playlist> playlists;
  final List<Video> videos;

  final YouTubeClient _client;

  SearchResult.empty({required YouTubeClient client})
      : channels = <Channel>[],
        playlists = <Playlist>[],
        videos = <Video>[],
        _client = client;

  factory SearchResult.fromJson(List<Map<String, dynamic>> data, {required YouTubeClient client}) {
    var result = SearchResult.empty(client: client);
    for (var d in data) {
      switch (d["type"]) {
        case "channel":
          result.channels.add(Channel.fromJson(d, client: client));
          break;

        case "playlist":
          result.playlists.add(Playlist.fromJson(d, client: client));
          break;

        case "video":
          result.videos.add(Video.fromJson(d, client: client));
          break;
      }
    }

    return result;
  }

  bool get isEmpty => playlists.isEmpty && videos.isEmpty;

  void empty() {
    playlists.clear();
    videos.clear();
  }

  void update(SearchResult other) {
    playlists.addAll(other.playlists);
    videos.addAll(other.videos);
  }

  static Future<SearchResult?> get(String query, {required int page, required SearchType type, required YouTubeClient client}) async {
    var response = await client.get(
      pathSegments: ["api", "v1", "search"],
      queryParameters: {"q": query, "page": page.toString(), "type": type.asString()},
    );

    if (response == null) return null;
    return SearchResult.fromJson(List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(response.bodyBytes))), client: client);
  }
}
