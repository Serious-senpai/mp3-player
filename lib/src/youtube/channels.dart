import "dart:convert";

import "package:flutter/material.dart";

import "client.dart";
import "images.dart";
import "playlists.dart";
import "videos.dart";

class PartialChannel {
  final String author;
  final String authorId;

  final YouTubeClient _client;

  PartialChannel._(this.author, this.authorId, this._client);
  PartialChannel.fromJson(Map<String, dynamic> data, {required YouTubeClient client})
      : author = data["author"],
        authorId = data["authorId"],
        _client = client;

  @override
  String toString() => author;

  Future<Channel?> toChannel() => Channel.get(authorId, client: _client);
}

class Channel extends PartialChannel {
  static final _cache = <String, Channel>{};

  final List<ImageObject> thumbnails;
  final int subCount;
  final String description;

  Channel._(
    String author,
    String authorId,
    this.thumbnails,
    this.subCount,
    this.description,
    YouTubeClient client,
  ) : super._(author, authorId, client);

  factory Channel.fromJson(Map<String, dynamic> data, {required YouTubeClient client}) {
    var authorId = data["authorId"];
    var cached = _cache[authorId];
    if (cached != null) return cached;

    var thumbnailsData = List<Map<String, dynamic>>.from(data["authorThumbnails"]);
    return _cache[authorId] = Channel._(
      data["author"],
      data["authorId"],
      List<ImageObject>.from(thumbnailsData.map((d) => ImageObject.fromJson(d))),
      data["subCount"],
      data["description"],
      client,
    );
  }

  Future<List<Playlist>> fetchPlaylists() async {
    var results = <Playlist>[];
    var response = await _client.get(
      pathSegments: ["api", "v1", "channels", authorId, "playlists"],
    );
    if (response == null) return results;
    var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    for (var d in List<Map<String, dynamic>>.from(data["playlists"])) {
      var playlist = Playlist.fromJson(d, client: _client); // Invidious bug: playlists here are empty
      for (int i = 0; i < 3; i++) {
        var fullPlaylist = await playlist.refetch(); // Fetch it again via /api/v1/playlists
        if (fullPlaylist != null) {
          results.add(fullPlaylist);
          break;
        }
      }
    }

    var token = data["continuation"];
    while (token != null) {
      var response = await _client.get(
        pathSegments: ["api", "v1", "channels", authorId, "playlists"],
        queryParameters: {"continuation": token},
      );
      if (response == null) return results;
      var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      for (var d in List<Map<String, dynamic>>.from(data["playlists"])) {
        var playlist = Playlist.fromJson(d, client: _client);
        for (int i = 0; i < 3; i++) {
          var fullPlaylist = await playlist.refetch();
          if (fullPlaylist != null) {
            results.add(fullPlaylist);
            break;
          }
        }
      }

      token = data["continuation"];
    }

    return results;
  }

  Future<List<Video>> fetchVideos() async {
    var results = <Video>[];
    var response = await _client.get(
      pathSegments: ["api", "v1", "channels", authorId, "videos"],
    );

    if (response == null) return results;
    var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    for (var d in List<Map<String, dynamic>>.from(data["videos"])) {
      results.add(Video.fromJson(d, client: _client));
    }

    var token = data["continuation"];
    while (token != null) {
      var response = await _client.get(
        pathSegments: ["api", "v1", "channels", authorId, "videos"],
        queryParameters: {"continuation": token},
      );

      if (response == null) return results;
      var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      for (var d in List<Map<String, dynamic>>.from(data["videos"])) {
        results.add(Video.fromJson(d, client: _client));
      }

      token = data["continuation"];
    }

    return results;
  }

  Future<T?> navigate<T>(BuildContext context) => Navigator.pushNamed(context, "/youtube/channel", arguments: this);

  static Future<Channel?> get(String channelId, {required YouTubeClient client}) async {
    var cached = _cache[channelId];
    if (cached != null) return cached;

    var response = await client.get(
      pathSegments: ["api", "v1", "channels", channelId],
      queryParameters: {"fields": "author,authorId,authorThumbnails,subCount,description"},
    );

    if (response == null) return null;
    var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return Channel.fromJson(data, client: client);
  }
}
