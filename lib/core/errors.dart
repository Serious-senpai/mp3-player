class MP3PlayerException implements Exception {
  final String message;
  final Function func;

  MP3PlayerException(this.message, this.func);

  @override
  String toString() => "At function $func\n$message\n";
}

class OperationException extends MP3PlayerException {
  final dynamic exception;

  OperationException(Function func, this.exception) : super("Exception: $exception", func);
}

class LogicalFlowException extends MP3PlayerException {
  LogicalFlowException(Function func) : super("Shouldn't reach here", func);
}
