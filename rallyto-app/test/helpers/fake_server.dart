import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:rallyto_app/core/api/client/dio_client.dart';
import 'package:rallyto_app/core/api/interceptors/error_interceptor.dart';

/// The API as a Dio adapter: answers by «METHOD path» (an unknown one is a 404) and records every request, so a
/// repository runs over the real client stack (error interceptor, retrofit, envelope) without a network.
class FakeServer implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions options)> routes = {};
  final List<RequestOptions> requests = [];

  /// «METHOD path» of every request, in order.
  List<String> get calls => [for (final r in requests) '${r.method} ${r.path}'];

  /// The JSON body of the last request.
  Map<String, dynamic> get lastJson => requests.last.data as Map<String, dynamic>;

  /// A Dio for the API at `https://api.test` over this server.
  Dio dio() =>
      DioFactory.create(baseUrl: 'https://api.test', interceptors: [ErrorInterceptor()], logging: false)
        ..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    return route == null ? errorBody(404, 'NOT_FOUND', 'Not found') : route(options);
  }

  @override
  void close({bool force = false}) {}
}

/// The success envelope around [data].
ResponseBody okBody(Object? data, {int status = 200}) => _json(status, {
  'success': true,
  'statusCode': status,
  'message': 'Request completed successfully',
  'data': data,
  'metadata': {'traceId': 'trace-1'},
});

/// The error envelope.
ResponseBody errorBody(int status, String code, String message) => _json(status, {
  'success': false,
  'statusCode': '$status',
  'message': message,
  'data': null,
  'error': {'code': code, 'message': message},
  'metadata': {'traceId': 'trace-1'},
});

/// 204: no body at all.
ResponseBody noContentBody() => ResponseBody.fromString('', 204);

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
