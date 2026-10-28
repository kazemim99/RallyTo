// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiResponse<T> _$ApiResponseFromJson<T>(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
    ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      statusCode: _statusCodeFromJson(json['statusCode']),
      message: json['message'] as String?,
      data: _$nullableGenericFromJson(json['data'], fromJsonT),
      error: json['error'] == null ? null : ApiError.fromJson(json['error'] as Map<String, dynamic>),
      errors: (json['errors'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      metadata: json['metadata'] == null ? null : ResponseMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );

T? _$nullableGenericFromJson<T>(Object? input, T Function(Object? json) fromJson) =>
    input == null ? null : fromJson(input);

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) => ApiError(
  code: json['code'] as String?,
  message: json['message'] as String?,
  errors: (json['errors'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
  ),
);

ResponseMetadata _$ResponseMetadataFromJson(Map<String, dynamic> json) => ResponseMetadata(
  requestId: json['requestId'] as String?,
  traceId: json['traceId'] as String?,
  timestamp: json['timestamp'] == null ? null : DateTime.parse(json['timestamp'] as String),
  duration: (json['duration'] as num?)?.toInt(),
  path: json['path'] as String?,
  method: json['method'] as String?,
  version: json['version'] as String?,
);
