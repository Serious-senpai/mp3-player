import "dart:convert";

import "package:http/http.dart";

/// Exception for all custom errors thrown by this application
class MP3PlayerException implements Exception {
  /// The error message
  final String message;

  /// The function that threw the exception
  final Function func;

  /// Construct a new [MP3PlayerException]
  MP3PlayerException(this.message, this.func);

  @override
  String toString() => "At function $func\n$message\n";
}

/// Indicates that a logical control flow path shouldn't have been reached
class LogicalFlowException extends MP3PlayerException {
  /// Construct a new [LogicalFlowException]
  LogicalFlowException(Function func) : super("Shouldn't reach here", func);
}

/// Errors regarding HTTP responses
class HTTPException extends MP3PlayerException {
  /// The HTTP response that caused the error
  final Response response;

  /// Construct a new [HTTPException]
  HTTPException(this.response, Function func) : super("HTTP status ${response.statusCode}:\n${utf8.decode(response.bodyBytes)}", func);
}
