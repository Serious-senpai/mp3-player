import "package:async_locks/async_locks.dart";
import "package:path/path.dart";

import "track_info.dart";
import "utils.dart";

/// Represents an audio source
class Track {
  static final _cache = <String, Track>{};
  static final _cacheLock = Lock();

  /// Path to the audio file in the filesystem (should be the same as [TrackInfo.thumbnailPath])
  final String uri;

  /// The track metadata
  final TrackInfo trackInfo;

  /// The track's title
  String get title => trackInfo.title ?? basenameWithoutExtension(uri);

  /// The track's data to send to the native side during a play request
  Map<String, String?> get data => {
        "title": title,
        "artist": trackInfo.artist,
        "uri": uri,
        "thumbnailPath": trackInfo.thumbnailPath,
      };

  Track._({required this.uri, required this.trackInfo}) {
    _cache[uri] = this;
  }

  /// Create a [Track] from an audio file [path], will be `null` if [path] does not point
  /// to an audio file
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
