class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic body;

  const ApiException({
    this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException(statusCode: $statusCode, message: $message)';
    }

    return 'ApiException(message: $message)';
  }
}
