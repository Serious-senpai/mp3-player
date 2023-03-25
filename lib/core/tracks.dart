import "dart:convert";
import "dart:io";

import "package:assets_audio_player/assets_audio_player.dart";
import "package:async_locks/async_locks.dart";
import "package:flutter/material.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:permission_handler/permission_handler.dart";
import "package:sqflite/sqflite.dart";

import "client.dart";
import "errors.dart";
import "youtube.dart";

/// Abstract class for [Track]s that are playable
abstract class Track {
  static final _localTrackMatcher = RegExp(r"(?<=\[!LOCAL\])(.+)");
  static final _youtubeTrackMatcher = RegExp(r"(?<=\[!YOUTUBE\])(.+)");

  static final _trackCache = <String, Track>{};

  /// Clear the internal cache
  static void clearCache() => _trackCache.clear();

  /// The URI of the track
  String uri;

  /// The title of the track
  String title;

  /// The artist of the track
  String? artist;

  /// The album of the track
  String? album;

  final MP3Client _state;

  /// An unique URI that can be used to identify the type of track([LocalTrack], [YouTubeTrack],...)
  /// as well as its [uri]
  String get databaseUri;

  /// Initialize a new [Track]
  Track({
    required this.uri,
    required this.title,
    this.artist,
    this.album,
    required MP3Client client,
  }) : _state = client;

  /// A [Widget] that displays the thumbnail of the track
  Widget displayThumbnail({double? size, BoxFit? fit}) => Image.asset(
        "assets/logo.jpg",
        width: size,
        height: size,
        fit: fit,
      );

  /// Edit the title of the track
  Future<bool> editTitle({required String newTitle});

  /// Convert this track to a playable [Audio]
  Future<Audio> toAudio() async => Audio("assets/silence.mp3");

  static final _createTrackLock = Lock();

  /// Create a new [Track] of a suitable type
  static Future<Track?> createTrack({
    required MP3Client client,
    required String databaseUri,
    bool allowHTTPRequest = true,
  }) =>
      _createTrackLock.run(
        () async {
          var cached = _trackCache[databaseUri];
          if (cached != null) return cached;

          var realUri = _localTrackMatcher.stringMatch(databaseUri);
          if (realUri != null) {
            var track = await LocalTrack.fromPath(client: client, realUri: realUri);
            if (track != null) _trackCache[databaseUri] = track;
            return track;
          }

          realUri = _youtubeTrackMatcher.stringMatch(databaseUri);
          if (realUri != null) {
            var track = await YouTubeTrack.fromId(
              client: client,
              videoId: realUri,
              allowHTTPRequest: allowHTTPRequest,
            );

            if (track != null) _trackCache[databaseUri] = track;

            return track;
          }

          throw LogicalFlowException(createTrack);
        },
      );
}

/// Represents a [Track] from a local file in the filesystem
class LocalTrack extends Track {
  @override
  String get databaseUri => "[!LOCAL]$uri";

  Future<String?>? _thumbnailPathFuture;

  /// Construct a new [LocalTrack]
  LocalTrack({
    required String uri,
    required String title,
    String? artist,
    String? album,
    required MP3Client client,
  }) : super(
          uri: uri,
          title: title,
          artist: artist,
          album: album,
          client: client,
        );

  @override
  Widget displayThumbnail({double? size, BoxFit? fit}) {
    _thumbnailPathFuture = _thumbnailPathFuture ?? saveThumbnailImage();
    return FutureBuilder(
      future: _thumbnailPathFuture,
      builder: (context, snapshot) => snapshot.data == null
          ? super.displayThumbnail(size: size, fit: fit)
          : Image.file(
              File(snapshot.data!),
              errorBuilder: (context, error, stackTrace) => super.displayThumbnail(size: size, fit: fit),
              width: size,
              height: size,
              fit: fit,
            ),
    );
  }

  @override
  Future<bool> editTitle({required String newTitle}) async {
    var status = await _state.tagger.writeTag(path: uri, tagField: "title", value: newTitle) ?? false;
    if (!status) {
      var permissionStatus = await Permission.storage.request();
      if (permissionStatus.isGranted) {
        status = await _state.tagger.writeTag(path: uri, tagField: "title", value: newTitle) ?? false;
      }
    }

    if (status) title = newTitle;

    return status;
  }

  Future<String?> saveThumbnailImage() async {
    var data = await _state.tagger.readArtwork(path: uri);
    if (data != null) {
      try {
        var tempDir = await getTemporaryDirectory();
        var originalTitle = basenameWithoutExtension(uri);
        var thumbnailPath = join(tempDir.path, "$originalTitle.jpg");

        var writer = File(thumbnailPath);
        if (!await writer.exists()) {
          await writer.writeAsBytes(data);
        }

        return thumbnailPath;
      } on MissingPlatformDirectoryException {
        // pass
      }
    }

    return null;
  }

  @override
  Future<Audio> toAudio() async {
    var thumbnailPath = await saveThumbnailImage();
    return Audio.file(
      uri,
      metas: Metas(
        title: title,
        artist: artist,
        album: album,
        image: thumbnailPath != null
            ? MetasImage(
                path: thumbnailPath,
                type: ImageType.file,
              )
            : null,
      ),
    );
  }

  /// Create a [LocalTrack] from a local path
  static Future<LocalTrack?> fromPath({required MP3Client client, required String realUri}) async {
    var exists = await File(realUri).exists();
    if (!exists) {
      return null;
    }

    var tag = await client.tagger.readTags(path: realUri);
    var title = basenameWithoutExtension(realUri);
    if (tag != null && tag.title != null && tag.title!.isNotEmpty) {
      title = tag.title!;
    }

    return LocalTrack(
      uri: realUri,
      title: title,
      artist: tag?.artist,
      album: tag?.album,
      client: client,
    );
  }

  @override
  String toString() => "<LocalTrack title=$title artist=$artist>";
}

/// Represents a YouTube track
class YouTubeTrack extends Track {
  static final _analyzer = Uri.https("www.y2mate.com", "/mates/analyzeV2/ajax");
  static final _converter = Uri.https("www.y2mate.com", "/mates/convertV2/index");

  @override
  String get databaseUri => "[!YOUTUBE]$uri";

  /// The video ID
  String get videoId => uri;

  /// The [YouTubeClient] associated with this track
  YouTubeClient get ytClient => _state.ytClient!;

  /// Construct a new [YouTubeTrack]
  YouTubeTrack({
    required String videoId,
    required String title,
    String? author,
    required MP3Client client,
  }) : super(
          uri: videoId,
          title: title,
          artist: author,
          album: "YouTube",
          client: client,
        );

  /// The track's URL
  Uri get url => Uri.https("youtube.com", "/watch", {"v": videoId});

  /// The track's thumbnail URL
  Uri get thumbnailUrl => Uri.https("img.youtube.com", "/vi/$videoId/mqdefault.jpg");

  @override
  Widget displayThumbnail({double? size, BoxFit? fit}) => Image.network(
        thumbnailUrl.toString(),
        errorBuilder: (context, error, stackTrace) => super.displayThumbnail(size: size, fit: fit),
        width: size,
        height: size,
        fit: fit,
      );

  @override
  Future<bool> editTitle({required String newTitle}) async {
    var updated = await _state.database.update(
      "youtube",
      {"title": newTitle},
      where: "id = ?",
      whereArgs: [videoId],
    );

    if (updated == 1) {
      title = newTitle;
      return true;
    }

    return false;
  }

  @override
  Future<Audio> toAudio() async {
    try {
      var audioUrl = await getAudioUrl();
      return Audio.network(
        audioUrl.toString(),
        metas: Metas(
          title: title,
          artist: artist,
          image: MetasImage.network(thumbnailUrl.toString()),
        ),
      );
    } on SocketException {
      return super.toAudio();
    }
  }

  /// Fetch the audio URL for this track
  Future<Uri> getAudioUrl() async {
    var response = await ytClient.client.post(
      _analyzer,
      body: {"k_query": url.toString()},
      encoding: const Utf8Codec(allowMalformed: true),
    );

    if (response.statusCode != 200) {
      throw HTTPException(response, getAudioUrl);
    }

    var data = Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    var audioData = Map<String, Map<String, dynamic>>.from(data["links"]["mp3"]);
    var key = audioData.values.first["k"];

    response = await ytClient.client.post(
      _converter,
      body: {"vid": videoId, "k": key},
      encoding: const Utf8Codec(allowMalformed: true),
    );

    if (response.statusCode != 200) {
      throw HTTPException(response, getAudioUrl);
    }

    data = Map<String, String>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    return Uri.parse(data["dlink"]);
  }

  /// Insert the metadata of this track to the database
  Future<void> save() => _state.database.insert(
        "youtube",
        {"id": videoId, "title": title, "author": artist},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  /// Create a [YouTubeTrack] from a [videoId]
  static Future<YouTubeTrack?> fromId({
    required MP3Client client,
    required String videoId,
    bool allowHTTPRequest = true,
  }) async {
    var results = await client.database.query(
      "youtube",
      distinct: true,
      where: "id = ?",
      whereArgs: [videoId],
    );

    if (results.isNotEmpty) {
      assert(results.length == 1);
      var row = Map<String, String>.from(results[0]);
      return YouTubeTrack(videoId: videoId, title: row["title"]!, author: row["author"]!, client: client);
    }

    return allowHTTPRequest ? client.ytClient?.fetch(videoId: videoId) : null;
  }

  @override
  String toString() => "<YouTubeTrack videoId=$videoId title=$title>";
}
