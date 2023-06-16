import "package:async_locks/async_locks.dart";
import "package:path/path.dart";

import "track_info.dart";
import "utils.dart";

class Track {
  static final _cache = <String, Track>{};
  static final _cacheLock = Lock();

  final String uri;
  final TrackInfo trackInfo;

  String get title => trackInfo.title ?? basenameWithoutExtension(uri);

  Map<String, String?> get data => {
        "title": title,
        "artist": trackInfo.artist,
        "uri": uri,
        "thumbnailPath": trackInfo.thumbnailPath,
      };

  Track._({required this.uri, required this.trackInfo}) {
    _cache[uri] = this;
  }

  static Future<Track?> fromPath(String path) => _cacheLock.run(
        () async {
          var cached = _cache[path];
          if (cached != null) return cached;

          if (!await isAudioFile(path)) return null;

          return Track._(uri: path, trackInfo: await TrackInfo.extractInfo(path));
        },
      );

  @override
  String toString() => "<Track title=$title>";
}
