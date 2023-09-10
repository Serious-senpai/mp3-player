import "dart:convert";

import "client.dart";
import "images.dart";

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

  final List<Image> thumbnails;

  Channel._(String author, String authorId, this.thumbnails, YouTubeClient client) : super._(author, authorId, client);

  factory Channel.fromJson(Map<String, dynamic> data, {required YouTubeClient client}) {
    var authorId = data["authorId"];
    var cached = _cache[authorId];
    if (cached != null) return cached;

    var thumbnailsData = List<Map<String, dynamic>>.from(data["authorThumbnails"]);
    return _cache[authorId] = Channel._(
      data["author"],
      data["authorId"],
      List<Image>.from(thumbnailsData.map((d) => Image.fromJson(d))),
      client,
    );
  }

  static Future<Channel?> get(String channelId, {required YouTubeClient client}) async {
    var cached = _cache[channelId];
    if (cached != null) return cached;

    var response = await client.get(
      pathSegments: ["api", "v1", "channels", channelId],
      queryParameters: {"fields": "author,authorId,authorThumbnails"},
    );

    if (response == null) return null;
    var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return Channel.fromJson(data, client: client);
  }
}
