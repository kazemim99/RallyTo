import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

/// The envelope every `/api` response comes in, mirroring the backend's `ApiResponseMiddleware` (success) and
/// `ExceptionHandlingMiddleware` (error), forked from AsanRezerve.
///
/// Success (2xx except 204; null members are omitted):
/// ```json
/// { "success": true, "statusCode": 200, "message": "Request completed successfully", "data": …,
///   "metadata": { "requestId", "traceId", "timestamp", "duration", "path", "method", "version" } }
/// ```
/// Error (`statusCode` is a STRING here, e.g. "400"):
/// ```json
/// { "success": false, "statusCode": "400", "message": "…", "data": null,
///   "error": { "code": "…", "message": "…", "errors": { "field": ["…"] } },
///   "metadata": { "requestId", "traceId", "timestamp", "path", "method" } }
/// ```
@JsonSerializable(genericArgumentFactories: true, createToJson: false)
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.statusCode,
    this.message,
    this.data,
    this.error,
    this.errors,
    this.metadata,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$ApiResponseFromJson(json, fromJsonT);

  @JsonKey(defaultValue: false)
  final bool success;

  /// The HTTP status. The success envelope writes it as a number and the error envelope as a string; both are read.
  @JsonKey(fromJson: _statusCodeFromJson)
  final int? statusCode;

  final String? message;
  final T? data;
  final ApiError? error;

  /// Top-level per-field errors (`ApiResponse.Errors` on the server). The middleware puts them in [error] instead,
  /// but the DTO carries the member, so it is read when present.
  final Map<String, List<String>>? errors;

  final ResponseMetadata? metadata;

  bool get isSuccess => success && error == null;

  /// The first per-field message, from [error] or from [errors].
  String? get firstFieldError {
    for (final messages in [...?error?.errors?.values, ...?errors?.values]) {
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }
}

/// The `error` member of a failed response.
@JsonSerializable(createToJson: false)
class ApiError {
  const ApiError({this.code, this.message, this.errors});

  factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);

  /// Machine-readable, e.g. `TOO_MANY_REQUESTS`.
  final String? code;
  final String? message;

  /// Per-field messages, keyed by field name.
  final Map<String, List<String>>? errors;
}

/// The `metadata` member: `traceId` is the id to quote to support (also the `X-Trace-Id` header).
@JsonSerializable(createToJson: false)
class ResponseMetadata {
  const ResponseMetadata({
    this.requestId,
    this.traceId,
    this.timestamp,
    this.duration,
    this.path,
    this.method,
    this.version,
  });

  factory ResponseMetadata.fromJson(Map<String, dynamic> json) => _$ResponseMetadataFromJson(json);

  final String? requestId;
  final String? traceId;
  final DateTime? timestamp;

  /// Milliseconds the server spent (success responses only).
  final int? duration;
  final String? path;
  final String? method;

  /// API version (success responses only).
  final String? version;
}

int? _statusCodeFromJson(Object? value) => switch (value) {
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};
