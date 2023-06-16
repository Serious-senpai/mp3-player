import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";

const _platform = MethodChannel("com.haruka.mp3_player/utils", JSONMethodCodec());

final audioMimeType = {
  "audio/x-wav",
  "audio/x-aiff",
  "audio/mpeg",
  "audio/mp4",
  "application/ogg",
};

const seperator = SizedBox.square(dimension: 10.0);

Image fallbackToLogo(String? path, {double? width, double? height}) => path == null
    ? Image.asset(
        "assets/logo.jpg",
        fit: BoxFit.cover,
        width: width,
        height: height,
      )
    : Image.file(
        File(path),
        fit: BoxFit.cover,
        width: width,
        height: height,
      );

Future<bool> isAudioFile(String path) async {
  var ext = extension(path);
  if (ext[0] == ".") ext = ext.substring(1);

  var mimeType = await _platform.invokeMapMethod("getMimeTypeFromExtension", {"extension": ext});
  if (mimeType == null) return false;
  return audioMimeType.contains(mimeType["mimetype"]);
}

Future<void> launchUri(String uri) => _platform.invokeMapMethod("launchUri", {"uri": uri});

Future<String?> getDataDirectory() async {
  var result = await _platform.invokeMapMethod("getDataDirectory");
  return result?["path"];
}

Future<String?> getDownloadCacheDirectory() async {
  var result = await _platform.invokeMapMethod("getDownloadCacheDirectory");
  return result?["path"];
}

Future<String?> getExternalStorageDirectory() async {
  var result = await _platform.invokeMapMethod("getExternalStorageDirectory");
  return result?["path"];
}

Future<String?> getStorageDirectory() async {
  var result = await _platform.invokeMapMethod("getStorageDirectory");
  return result?["path"];
}

Future<List<String>?> getExternalFilesDirs() async {
  var result = await _platform.invokeMapMethod("getExternalFilesDirs");
  var paths = result?["paths"];

  return paths != null ? List<String>.from(paths) : null;
}

Future<List<String>> getCommonDirectories() async {
  var results = <String>{};

  for (var func in [
    getExternalStorageDirectory,
    getStorageDirectory,
  ]) {
    var result = await func();
    if (result != null) results.add(result);
  }

  var paths = await getExternalFilesDirs();
  if (paths != null) results.addAll(paths);

  return List<String>.from(results);
}
