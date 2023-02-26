import "dart:io";

import "package:flutter/material.dart";
import "package:fluttertoast/fluttertoast.dart";
import "package:url_launcher/url_launcher.dart";

import "errors.dart";

typedef _AsyncFunction<T> = Future<T> Function();

class _FutureSingleton {
  final _cache = <_AsyncFunction<dynamic>, Future<dynamic>>{};

  Future<T> getFuture<T>(_AsyncFunction<T> asyncFunction) {
    if (_cache[asyncFunction] != null) {
      var future = _cache[asyncFunction];
      if (future is Future<T>) {
        return future;
      } else {
        throw LogicalFlowException(getFuture<T>);
      }
    }

    return reloadFuture(asyncFunction);
  }

  Future<T> reloadFuture<T>(_AsyncFunction<T> asyncFunction) => _cache[asyncFunction] = asyncFunction();
}

/// Object that manages a single instance of each future from
/// asynchronous functions
final futureSingleton = _FutureSingleton();

/// Objects holding a pair of value
class Pair<T1, T2> {
  T1 first;
  T2 second;

  @override
  int get hashCode => first.hashCode ^ second.hashCode;

  Pair(this.first, this.second);

  @override
  bool operator ==(covariant Pair<T1, T2> other) => other.first == first && other.second == second;
}

/// A transparent [SizedBox] with a width and height of 10.0
const seperator = SizedBox(width: 10.0, height: 10.0);

/// Default color for icons
const defaultIconColor = Colors.white;

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

/// Display an error indicator with error message [content]
Widget errorIndicator({String? content, double size = 60}) {
  var sizedBox = SizedBox(
    width: size,
    height: size,
    child: Icon(Icons.highlight_off, size: size),
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

/// An empty view
const empty = SizedBox(width: 0.0, height: 0.0);

Future<bool> checkPath(String path) async {
  var exists = await File(path).exists();
  if (!exists) {
    return false;
  }

  return true;
}

/// Launch [url] in an external browser
Future<void> launch(Uri url) async {
  var status = await launchUrl(url, mode: LaunchMode.externalApplication);

  if (!status) {
    await Fluttertoast.showToast(msg: "Cannot launch $url");
  }
}
