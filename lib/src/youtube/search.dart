import "dart:convert";

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
  final List<Playlist> playlists;
  final List<Video> videos;

  final YouTubeClient _client;

  SearchResult(List<Map<String, dynamic>> data, {required YouTubeClient client})
      : playlists = <Playlist>[],
        videos = <Video>[],
        _client = client {
    for (var d in data) {
      switch (d["type"]) {
        case "playlist":
          playlists.add(Playlist.fromJson(d, client: client));
          break;

        case "video":
          videos.add(Video.fromJson(d, client: client));
          break;
      }
    }
  }

  SearchResult.empty({required YouTubeClient client})
      : playlists = <Playlist>[],
        videos = <Video>[],
        _client = client;

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
    print("Searching $query, page = $page, type = ${type.asString()}");
    var response = await client.get(
      pathSegments: ["api", "v1", "search"],
      queryParameters: {"q": query, "page": page.toString(), "type": type.asString()},
    );

    if (response == null) return null;
    return SearchResult(List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(response.bodyBytes))), client: client);
  }
}
