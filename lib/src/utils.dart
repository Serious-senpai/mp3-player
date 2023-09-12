import "dart:io";

import "package:async_locks/async_locks.dart";
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

abstract class _StreamWrapper<T> {
  abstract final T _value; // may not be final
  final Event _update = Event();

  Stream<T>? _stream;
  Stream<T> get stream => _stream ??= _createValueStream().asBroadcastStream();

  Stream<T> _createValueStream() async* {
    while (true) {
      yield _value;
      _update.clear();
      await _update.wait();
    }
  }
}

class ValueStream<T> extends _StreamWrapper<T> {
  @override
  T _value;

  ValueStream(T initial) : _value = initial;

  T get value => _value;
  set value(T newValue) {
    _value = newValue;
    _update.set();
  }
}

class MapStream<K, V> extends _StreamWrapper<Map<K, V>> {
  @override
  final Map<K, V> _value = <K, V>{};

  MapStream([Map<K, V>? initial]) {
    if (initial != null) _value.addAll(initial);
  }

  Iterable<K> get keys => _value.keys;
  Iterable<V> get values => _value.values;

  void clear() {
    _value.clear();
    _update.set();
  }

  V? remove(K key) {
    var value = _value.remove(key);
    _update.set();

    return value;
  }

  V? operator [](K key) => _value[key];
  void operator []=(K key, V value) {
    _value[key] = value;
    _update.set();
  }
}

/// A square [SizedBox] of size 10 * 10
const seperator = SizedBox.square(dimension: 10.0);

/// Display a loading indicator above [content]
Widget loadingIndicator({String? content, double size = 60}) {
  var sizedBox = SizedBox(
    width: size,
    height: size,
    child: const CircularProgressIndicator(),
  );

  var children = <Widget>[sizedBox];
  if (content != null) {
    children.addAll(
      [
        seperator,
        Text(content),
      ],
    );
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: children,
  );
}

Image logo({BoxFit fit = BoxFit.cover, double? width, double? height}) => Image.asset(
      "assets/logo.jpg",
      fit: fit,
      width: width,
      height: height,
    );

/// Construct an [Image] from a give file [path].
///
/// If [path] is `null`, display the application icon instead.
Image fallbackToLogo(String? path, {BoxFit fit = BoxFit.cover, double? width, double? height}) => path == null
    ? logo(fit: fit, width: width, height: height)
    : Image.file(
        File(path),
        fit: fit,
        width: width,
        height: height,
      );

/// Returns the MIME type of the given file at [path] (if any)
Future<String?> getMimeType(String path) async {
  var ext = extension(path);
  if (ext.isEmpty) return null;
  if (ext[0] == ".") ext = ext.substring(1);

  var mimeType = await _platform.invokeMapMethod("getMimeTypeFromExtension", {"extension": ext});
  return mimeType?["mimeType"];
}

/// Whether a file [path] points to an audio file
Future<bool> isAudioFile(String path) async {
  return _audioMimeType.contains(await getMimeType(path));
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

/// Share a file via other apps
Future<void> shareFile(String path) async {
  await _platform.invokeMethod(
    "shareFile",
    {
      "path": path,
      "mimeType": await getMimeType(path),
    },
  );
}

/// Display a toast message
Future<void> showToast(String content) => _platform.invokeMethod("showToast", {"content": content});

// https://stackoverflow.com/a/2703882
final _reserved = {"|", "\\", "?", "*", "<", "\"", ":", ">", "/", "'"};

String removeReservedCharacters(String fileName) {
  String result = "";
  for (var i = 0; i < fileName.length; i++) {
    if (!_reserved.contains(fileName[i])) {
      result += fileName[i];
    }
  }

  return result;
}

// https://stackoverflow.com/a/1162194
String ngettext(String first, String second, int value) {
  return value == 1 ? first : second;
}
