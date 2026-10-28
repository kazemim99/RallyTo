import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:injectable/injectable.dart';

import '../../auth/auth_error_codes.dart';
import '../../auth/auth_session.dart';
import '../../auth/token_storage.dart';
import '../client/dio_names.dart';
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/auth_models.dart';

/// Adds the access token to every request, and on a 401 renews the session once and retries.
///
/// Refresh tokens are single-use: each refresh rotates them, and the old one is refused from then on. When the
/// access token expires, every request in flight fails together; if each refreshed on its own, all but the first
/// would send an already-used token, be refused, and end the session. So every 401 waits on ONE shared refresh
/// ([_refreshing], static, because each Dio gets its own interceptor) and retries with its result.
///
/// [_dio] is the `authDio` client, which has no auth interceptor: the refresh and the retries go through it, so a
/// 401 on them is final instead of starting another refresh.
///
/// A 401 whose code says the account itself is over (`ACCOUNT_SUSPENDED`, `ACCOUNT_BANNED`, `ACCOUNT_INACTIVE`) is
/// never refreshed: the session is cleared with the server's message, which the sign-in screen then shows.
@injectable
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, @Named(DioNames.auth) this._dio);

  final TokenStorage _tokens;
  final Dio _dio;

  /// The refresh in progress, shared by every request that fails with 401 while it runs.
  static Future<_RefreshResult>? _refreshing;

  /// Whether a refresh is running now.
  @visibleForTesting
  static bool get isRefreshing => _refreshing != null;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _tokens.accessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Unreadable storage: the request goes out without a token, and a 401 takes it from there.
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || err.requestOptions.path.endsWith(ApiPaths.refresh)) {
      return handler.next(err);
    }
    if (await _endIfAccountEnded(err)) return handler.next(err);

    // Every path ends in exactly one handler call: an async interceptor that throws leaves its request hanging.
    try {
      final String token;
      final sentWith = '${err.requestOptions.headers['Authorization'] ?? ''}'.replaceFirst('Bearer ', '');
      final current = await _tokens.accessToken();
      if (current != null && current.isNotEmpty && current != sentWith) {
        // Another request renewed the session while this one was out: retry with that token, do not refresh again.
        token = current;
      } else {
        final result = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
        final transient = result.transientError;
        if (transient != null) {
          // The refresh got no answer (offline, timeout, server down). The session is kept, and the request fails
          // the way the refresh did, so the player sees "no connection" rather than "sign in again".
          return handler.next(
            DioException(
              requestOptions: err.requestOptions,
              response: transient.response,
              type: transient.type,
              error: transient.error,
              message: transient.message,
            ),
          );
        }
        final refreshed = result.accessToken;
        if (refreshed == null) return handler.next(err);
        token = refreshed;
      }

      final retried = await _dio.fetch<dynamic>(
        err.requestOptions.copyWith(headers: {...err.requestOptions.headers, 'Authorization': 'Bearer $token'}),
      );
      handler.resolve(retried);
    } on DioException catch (e) {
      await _endIfAccountEnded(e);
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  /// One refresh. The session is cleared when the server refuses it (or there is nothing to refresh with), and kept
  /// when the server could not be reached.
  Future<_RefreshResult> _refresh() async {
    final refreshToken = await _tokens.refreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokens.clear();
      return const _RefreshResult.refused();
    }

    try {
      final response = await _dio.post<Object?>(
        ApiPaths.refresh,
        data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
      );
      final body = response.data;
      final tokens = body is Map<String, dynamic>
          ? ApiResponse<TokenResponse>.fromJson(
              body,
              (json) => TokenResponse.fromJson(json as Map<String, dynamic>),
            ).data
          : null;
      if (tokens != null && tokens.accessToken.isNotEmpty && tokens.refreshToken.isNotEmpty) {
        await _tokens.saveSession(AuthSession.fromTokens(tokens));
        return _RefreshResult.refreshed(tokens.accessToken);
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == null || status >= 500 || status == 408 || status == 429) return _RefreshResult.transient(e);
      if (await _endIfAccountEnded(e)) return const _RefreshResult.refused();
    } catch (_) {
      // An answer that is not a token pair: treated as a refusal below.
    }

    await _tokens.clear();
    return const _RefreshResult.refused();
  }

  /// Clears the session with the server's message when [error] says the account is over; true when it did.
  Future<bool> _endIfAccountEnded(DioException error) async {
    final message = accountEndedMessage(error.response);
    if (message == null) return false;
    try {
      await _tokens.clear(reason: message);
    } catch (_) {
      // Storage failed: the cached session is gone all the same, and the request fails as it would anyway.
    }
    return true;
  }
}

/// The outcome of one refresh: a new access token, a refusal (both null: the session is over), or an error that left
/// the session as it was.
class _RefreshResult {
  const _RefreshResult.refreshed(String this.accessToken) : transientError = null;
  const _RefreshResult.refused() : accessToken = null, transientError = null;
  const _RefreshResult.transient(DioException this.transientError) : accessToken = null;

  final String? accessToken;
  final DioException? transientError;
}
