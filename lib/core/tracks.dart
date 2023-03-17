import "dart:convert";
import "dart:io";

import "package:assets_audio_player/assets_audio_player.dart";
import "package:flutter/material.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:permission_handler/permission_handler.dart";

import "client.dart";
import "errors.dart";
import "utils.dart";
import "youtube.dart";

abstract class Track {
  static final _localTrackMatcher = RegExp(r"(?<=\[!LOCAL\])(.+)");
  static final _youtubeTrackMatcher = RegExp(r"(?<=\[!YOUTUBE\])(.+)");

  String uri;

  String title;
  String? artist;
  String? album;

  final MP3Client _state;

  String get databaseUri => throw UnimplementedError();

  Track({
    required this.uri,
    required this.title,
    this.artist,
    this.album,
    required MP3Client client,
  }) : _state = client;

  Widget displayThumbnail({double? size}) => throw UnimplementedError();
  Future<bool> editTitle(String newTitle) => throw UnimplementedError();
  Future<Audio> toAudio() => throw UnimplementedError();

  static Future<Track?> createTrack({
    required MP3Client client,
    required String uri,
    required Map<String, Track> cache,
  }) async {
    if (cache[uri] != null) {
      return cache[uri];
    }

    var realUri = _localTrackMatcher.stringMatch(uri);
    if (realUri != null) {
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

    realUri = _youtubeTrackMatcher.stringMatch(uri);
    if (realUri != null) {
      return client.ytClient.fetch(realUri);
    }

    throw LogicalFlowException(createTrack);
  }
}

class LocalTrack extends Track {
  @override
  String get databaseUri => "[LOCAL]$uri";

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
  Widget displayThumbnail({double? size}) => FutureBuilder(
        future: futureSingleton.getFuture(createThumbnailImage),
        builder: (context, snapshot) => snapshot.data == null
            ? Image.asset(
                "assets/logo.jpg",
                width: size,
                height: size,
                fit: BoxFit.contain,
              )
            : Image.file(
                File(snapshot.data!),
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
      );

  @override
  Future<bool> editTitle(String newTitle) async {
    var status = await _state.tagger.writeTag(path: uri, tagField: "title", value: newTitle) ?? false;
    if (!status) {
      var permissionStatus = await Permission.manageExternalStorage.request();
      if (permissionStatus.isGranted) {
        status = await _state.tagger.writeTag(path: uri, tagField: "title", value: newTitle) ?? false;
      }
    }

    if (status) title = newTitle;

    return status;
  }

  Future<String?> createThumbnailImage() async {
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
    var thumbnailPath = await createThumbnailImage();
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

  @override
  String toString() => "<LocalTrack title=$title artist=$artist>";
}

class YouTubeTrack extends Track {
  static final _analyzer = Uri.https("www.y2mate.com", "/mates/analyzeV2/ajax");
  static final _converter = Uri.https("www.y2mate.com", "/mates/convertV2/index");

  @override
  String get databaseUri => "[YOUTUBE]$uri";

  /// The video ID
  String get videoId => uri;

  /// The [YouTubeClient] associated with this track
  YouTubeClient get ytClient => _state.ytClient;

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
  Uri get thumbnailUrl => Uri.https("img.youtube.com", "/vi/$videoId/0.jpg");

  @override
  Widget displayThumbnail({double? size}) => Image.network(
        thumbnailUrl.toString(),
        width: size,
        height: size,
        fit: BoxFit.contain,
      );

  @override
  Future<bool> editTitle(String newTitle) async {
    var updateCount = await _state.database.update(
      "youtube",
      {"title": newTitle},
      where: "id = ?",
      whereArgs: [videoId],
    );

    return updateCount == 1;
  }

  @override
  Future<Audio> toAudio() async {
    var audioUrl = await getAudioUrl();
    return Audio.network(
      audioUrl.toString(),
      metas: Metas(
        title: title,
        artist: artist,
        image: MetasImage.network(thumbnailUrl.toString()),
      ),
    );
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

  @override
  String toString() => "<YouTubeTrack videoId=$videoId title=$title>";
}
