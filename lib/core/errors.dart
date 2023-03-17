import "dart:convert";

import "package:http/http.dart";

class MP3PlayerException implements Exception {
  final String message;
  final Function func;

  MP3PlayerException(this.message, this.func);

  @override
  String toString() => "At function $func\n$message\n";
}

class LogicalFlowException extends MP3PlayerException {
  LogicalFlowException(Function func) : super("Shouldn't reach here", func);
}

class HTTPException extends MP3PlayerException {
  final Response response;

  HTTPException(this.response, Function func) : super("HTTP status ${response.statusCode}:\n${utf8.decode(response.bodyBytes)}", func);
}
