import "dart:convert";
import "dart:core";
import "dart:io";

import "package:async_locks/async_locks.dart";
import "package:http/http.dart";
import "package:sqflite/sqflite.dart";

import "client.dart";
import "errors.dart";
import "tracks.dart";

class YouTubeClient {
  static final _invidiousInstance = Uri.https("api.invidious.io", "/instances.json");

  /// List of Invidious instances
  List<String> instances;

  /// Internal [Client] to perform requests
  final Client client;

  /// [MP3Client] of this application
  final MP3Client mp3Client;

  YouTubeClient._({
    required this.client,
    required this.instances,
    required this.mp3Client,
  });

  final _optimizeLock = Lock();

  /// Ping all instances and sort them according to their response time
  Future<void> sortInstances() => _optimizeLock.run(
        () async {
          var ping = <String, int>{};

          var stopWatch = Stopwatch();
          for (var instance in instances) {
            stopWatch.reset();
            stopWatch.start();
            var response = await client.get(Uri.https(instance, "/api/v1/stats"));
            var time = stopWatch.elapsedMilliseconds;
            stopWatch.stop();

            if (response.statusCode >= 400) {
              time += 1000000000;
            }

            ping[instance] = time;
          }

          instances.sort((first, second) => ping[first]!.compareTo(ping[second]!));
        },
      );

  /// Search for a list of [YouTubeTrack] from a searching [query]
  Future<List<YouTubeTrack>> search(String query) async {
    for (var instance in instances) {
      var response = await client.get(Uri.https(
        instance,
        "/api/v1/search",
        {
          "q": query,
          "page": "0",
          "sort_by": "relevance",
          "type": "video",
        },
      ));
      if (response.statusCode == 200) {
        var data = List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(response.bodyBytes)));

        return List<YouTubeTrack>.generate(
          data.length,
          (index) {
            var item = data[index];
            return YouTubeTrack(
              videoId: item["videoId"],
              title: item["title"],
              author: item["author"],
              client: mp3Client,
            );
          },
        );
      }
    }

    throw LogicalFlowException(search);
  }

  /// Create a [YouTubeTrack] from [videoId]
  Future<YouTubeTrack?> fetch({required String videoId}) async {
    try {
      for (var instance in instances) {
        var response = await client.get(Uri.https(instance, "/api/v1/videos/$videoId"));
        if (response.statusCode == 200) {
          var data = Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
          var title = data["title"], author = data["artist"];
          await mp3Client.database.insert("youtube", {"id": videoId, "title": title, "author": author}, conflictAlgorithm: ConflictAlgorithm.ignore);
          return YouTubeTrack(videoId: videoId, title: title, author: author, client: mp3Client);
        }
      }
    } on SocketException {
      // pass
    }

    // Video may have been deleted/made private
    return null;
  }

  /// Create a new [YouTubeClient] associated with an [MP3Client]
  static Future<YouTubeClient> create(MP3Client mp3client) async {
    var client = Client();
    var response = await client.get(_invidiousInstance);
    var data = List<List<dynamic>>.from(jsonDecode(utf8.decode(response.bodyBytes)));

    var instances = <String>[];
    for (var instance in data) {
      var hostName = instance[0];
      var status = Map<String, dynamic>.from(instance[1]);
      if (hostName is String) {
        if (!hostName.endsWith(".i2p") && !hostName.endsWith(".onion") && status["api"] == true) {
          instances.add(hostName);
        }
      } else {
        throw LogicalFlowException(create);
      }
    }

    var result = YouTubeClient._(client: client, instances: instances, mp3Client: mp3client);
    return result;
  }
}
