import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";

const _platform = MethodChannel("com.haruka.mp3_player/utils", JSONMethodCodec());

final _audioMimeType = {
  "audio/x-wav",
  "audio/x-aiff",
  "audio/mpeg",
  "audio/mp4",
  "application/ogg",
};

/// A square [SizedBox] of size 10 * 10
const seperator = SizedBox.square(dimension: 10.0);

/// Construct an [Image] from a give file [path].
///
/// If [path] is `null`, display the application icon instead.
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

/// Whether a file [path] points to an audio file
Future<bool> isAudioFile(String path) async {
  var ext = extension(path);
  if (ext[0] == ".") ext = ext.substring(1);

  var mimeType = await _platform.invokeMapMethod("getMimeTypeFromExtension", {"extension": ext});
  if (mimeType == null) return false;
  return _audioMimeType.contains(mimeType["mimetype"]);
}

/// Launch the native web browser to the specified [uri]
Future<void> launchUri(String uri) => _platform.invokeMapMethod("launchUri", {"uri": uri});

/// Get the absolute path to the device's external storages
/// See also: https://developer.android.com/reference/android/content/Context#getExternalFilesDirs(java.lang.String)
Future<List<Directory>?> getExternalFilesDirs() async {
  var result = await _platform.invokeMapMethod("getExternalFilesDirs");
  var paths = List<String>.from(result?["paths"]);
  return List<Directory>.generate(
    paths.length,
    (index) => Directory(normalize(join(paths[index], "../../../.."))),
  );
}
