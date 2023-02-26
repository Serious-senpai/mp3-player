import "dart:typed_data";

import "package:flutter/material.dart";
import "package:permission_handler/permission_handler.dart";

import "client.dart";

class Track {
  String path;

  String title;
  String? artist;
  String? album;
  Uint8List? thumbnail;

  final Client _state;

  Track({
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.thumbnail,
    required Client client,
  }) : _state = client;

  Image displayThumbnail({double? size}) => thumbnail == null
      ? Image.asset(
          "assets/logo.jpg",
          width: size,
          height: size,
          fit: BoxFit.contain,
        )
      : Image.memory(
          thumbnail!,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

  Future<bool> editTitle(String newTitle) async {
    var status = await _state.tagger.writeTag(path: path, tagField: "title", value: newTitle) ?? false;
    if (!status) {
      var permissionStatus = await Permission.manageExternalStorage.request();
      if (permissionStatus.isGranted) {
        status = await _state.tagger.writeTag(path: path, tagField: "title", value: newTitle) ?? false;
      }
    }

    if (status) title = newTitle;

    return status;
  }

  @override
  String toString() => "<Track title=$title artist=$artist>";
}
