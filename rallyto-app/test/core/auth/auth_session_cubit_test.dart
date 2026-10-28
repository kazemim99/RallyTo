import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/api/models/api_response.dart';
import 'package:rallyto_app/core/api/models/auth_models.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';

import '../../helpers/memory_secure_storage.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 8, 30);
  late TokenStorage tokens;
  late AuthSessionCubit cubit;

  setUp(() {
    tokens = memoryTokenStorage();
    cubit = AuthSessionCubit(tokens, clock: () => now);
  });

  tearDown(() => cubit.close());

  test('starts signed out, and stays so when nothing is stored', () async {
    expect(cubit.state, const Unauthenticated());
    await cubit.restore();
    expect(cubit.state, const Unauthenticated());
  });

  test('restores a stored session with its onboarding state and roles', () async {
    await tokens.saveSession(
      testSession(profileCompleted: false, refreshTokenExpiresAt: now.add(const Duration(days: 30))),
    );

    await cubit.restore();

    expect(cubit.state, const Authenticated(profileCompleted: false, roles: ['Player']));
  });

  test('a stored session whose refresh token has run out is cleared, not restored', () async {
    await tokens.saveSession(testSession(refreshTokenExpiresAt: now.subtract(const Duration(minutes: 1))));

    await cubit.restore();

    expect(cubit.state, const Unauthenticated());
    expect(await tokens.readSession(), isNull);
  });

  test('signing in stores the session; signing out clears it', () async {
    await cubit.signIn(testSession(profileCompleted: true));
    expect(cubit.state, const Authenticated(profileCompleted: true, roles: ['Player']));
    expect((await tokens.readSession())?.accessToken, 'access-1');

    await cubit.signOut();
    expect(cubit.state, const Unauthenticated());
    expect(await tokens.readSession(), isNull);
  });

  test('work added before sign-out runs while the session is still stored, then the session is cleared', () async {
    await cubit.signIn(testSession(profileCompleted: true));
    final seen = <String?>[];
    cubit.addBeforeSignOut(() async => seen.add((await tokens.readSession())?.accessToken));

    await cubit.signOut();

    expect(seen, ['access-1'], reason: 'the device token is unregistered with a valid session');
    expect(cubit.state, const Unauthenticated());
    expect(await tokens.readSession(), isNull);
  });

  test('work before sign-out that fails or hangs does not keep the player signed in', () async {
    await cubit.signIn(testSession(profileCompleted: true));
    cubit
      ..addBeforeSignOut(() async => throw StateError('offline'))
      ..addBeforeSignOut(() => Future<void>.delayed(const Duration(milliseconds: 1), () => throw StateError('late')));

    await cubit.signOut();

    expect(cubit.state, const Unauthenticated());
  });

  test('signed out already, there is nothing to run before signing out', () async {
    var runs = 0;
    cubit.addBeforeSignOut(() async => runs++);

    await cubit.signOut();

    expect(runs, 0);
  });

  test('follows the storage when the session changes elsewhere (a refresh, a refused refresh)', () async {
    await cubit.signIn(testSession(profileCompleted: false));

    final states = <AuthState>[];
    final subscription = cubit.stream.listen(states.add);
    await tokens.saveSession(testSession(accessToken: 'access-2', profileCompleted: true));
    await tokens.clear();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(states, [
      const Authenticated(profileCompleted: true, roles: ['Player']),
      const Unauthenticated(),
    ]);
  });

  group('completing the profile (onboarding answered 201)', () {
    test('lets the player past onboarding, and is stored for the next start, with the tokens unchanged', () async {
      await cubit.signIn(testSession(profileCompleted: false));

      await cubit.markProfileCompleted();

      expect(cubit.state, const Authenticated(profileCompleted: true, roles: ['Player']));
      final stored = await tokens.readSession();
      expect(stored?.profileCompleted, isTrue);
      expect(stored?.accessToken, 'access-1');
      expect(stored?.refreshToken, 'refresh-1');
    });

    test('signed out, it does nothing', () async {
      await cubit.markProfileCompleted();

      expect(cubit.state, const Unauthenticated());
      expect(await tokens.readSession(), isNull);
    });
  });

  group('signing out', () {
    test('clears the session, then revokes the refresh token on the server with the access token', () async {
      final api = _SignOutApi();
      final withApi = AuthSessionCubit(tokens, api: api, clock: () => now);
      addTearDown(withApi.close);
      await withApi.signIn(testSession(accessToken: 'access-9', refreshToken: 'refresh-9'));

      await withApi.signOut();

      expect(withApi.state, const Unauthenticated());
      expect(await tokens.readSession(), isNull);
      expect(api.calls, [('refresh-9', 'Bearer access-9')]);
    });

    test('is best effort: a failing server call still signs out', () async {
      final api = _SignOutApi()..fails = true;
      final withApi = AuthSessionCubit(tokens, api: api, clock: () => now);
      addTearDown(withApi.close);
      await withApi.signIn(testSession());

      await withApi.signOut();

      expect(withApi.state, const Unauthenticated());
      expect(await tokens.readSession(), isNull);
      expect(api.calls, hasLength(1));
    });

    test('without a session, nothing is sent', () async {
      final api = _SignOutApi();
      final withApi = AuthSessionCubit(tokens, api: api, clock: () => now);
      addTearDown(withApi.close);

      await withApi.signOut();

      expect(api.calls, isEmpty);
    });
  });

  group('a session the server ended (suspended, banned, inactive)', () {
    const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';

    test("signs out with the server's message, which survives the clear that came with it", () async {
      await cubit.signIn(testSession(profileCompleted: true));

      await tokens.clear(reason: message);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const Unauthenticated(message: message));
      expect(await tokens.readSession(), isNull);
    });

    test('the message goes when dismissed, or when the player signs in again', () async {
      await cubit.signIn(testSession());
      await tokens.clear(reason: message);
      await Future<void>.delayed(Duration.zero);

      cubit.dismissSignOutMessage();
      expect(cubit.state, const Unauthenticated());

      await tokens.clear(reason: message);
      await Future<void>.delayed(Duration.zero);
      await cubit.signIn(testSession(profileCompleted: true));
      expect(cubit.state, const Authenticated(profileCompleted: true, roles: ['Player']));
    });
  });

  group('an account the player deleted', () {
    const notice = 'حساب کاربری شما حذف شد.';

    test(
      'runs the before-sign-out hooks with the session, clears it, revokes nothing, and leaves the notice',
      () async {
        final api = _SignOutApi();
        final withApi = AuthSessionCubit(tokens, api: api, clock: () => now);
        addTearDown(withApi.close);
        await withApi.signIn(testSession(profileCompleted: true));
        final seen = <String?>[];
        withApi.addBeforeSignOut(() async => seen.add((await tokens.readSession())?.accessToken));

        await withApi.signOutDeletedAccount(notice);

        expect(seen, ['access-1'], reason: 'the device token is unregistered on the same path as sign-out');
        expect(await tokens.readSession(), isNull);
        expect(withApi.state, const Unauthenticated(notice: notice));
        expect(api.calls, isEmpty, reason: 'the server already revoked every refresh token');
      },
    );

    test('the account-ended 401 a hook meets (the account is gone) does not replace the notice', () async {
      await cubit.signIn(testSession(profileCompleted: true));
      // What the auth interceptor does when the unregister call is answered 401 ACCOUNT_INACTIVE.
      cubit.addBeforeSignOut(() => tokens.clear(reason: 'حساب کاربری فعال نیست.'));

      await cubit.signOutDeletedAccount(notice);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const Unauthenticated(notice: notice));
    });

    test('the notice goes when dismissed; after the next sign-in, server messages show again', () async {
      await cubit.signIn(testSession());
      await cubit.signOutDeletedAccount(notice);

      cubit.dismissSignOutMessage();
      expect(cubit.state, const Unauthenticated());

      await cubit.signIn(testSession(profileCompleted: true));
      await tokens.clear(reason: 'تعلیق');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const Unauthenticated(message: 'تعلیق'));
    });
  });
}

/// Records sign-out calls; the sign-in calls are not used here.
class _SignOutApi implements AuthApi {
  final List<(String, String?)> calls = [];
  bool fails = false;

  @override
  Future<void> signOut(RefreshTokenRequest body, String? authorization) async {
    calls.add((body.refreshToken, authorization));
    if (fails) throw Exception('offline');
  }

  @override
  Future<ApiResponse<OtpSendResponse>> sendOtp(OtpSendRequest body) => throw UnimplementedError();

  @override
  Future<ApiResponse<TokenResponse>> verifyOtp(OtpVerifyRequest body) => throw UnimplementedError();

  @override
  Future<ApiResponse<TokenResponse>> refresh(RefreshTokenRequest body) => throw UnimplementedError();
}
