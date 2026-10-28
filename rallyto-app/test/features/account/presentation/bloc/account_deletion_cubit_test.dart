import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/account/domain/account_repository.dart';
import 'package:rallyto_app/features/account/presentation/bloc/account_deletion_cubit.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';

import '../../../../helpers/fake_account.dart';
import '../../../../helpers/fake_auth.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// Deleting the account (spec identity-access › Account deletion): a fresh code first, a resend once the server's wait
/// is over, a wrong or expired code that keeps the account, and a deletion that ends the session on sign-out's path.
void main() {
  late FakeAccountRepository account;
  late TokenStorage tokens;
  late AuthSessionCubit session;
  late FakeCountdown countdown;
  late List<String> hooks;

  setUp(() async {
    account = FakeAccountRepository();
    tokens = memoryTokenStorage();
    session = AuthSessionCubit(tokens);
    await session.signIn(testSession(profileCompleted: true));
    hooks = [];
    session.addBeforeSignOut(
      () async => hooks.add('unregister push with ${(await tokens.readSession())?.accessToken}'),
    );
    countdown = FakeCountdown();
  });

  tearDown(() => session.close());

  Future<AccountDeletionCubit> started() async {
    final cubit = AccountDeletionCubit(account, session, countdown);
    addTearDown(cubit.close);
    await cubit.start();
    return cubit;
  }

  group('the code', () {
    test('is asked for once on start; the boxes open and the resend wait starts', () async {
      final cubit = await started();
      await cubit.start();

      expect(account.codeRequests, 1);
      expect(cubit.state.status, AccountDeletionStatus.idle);
      expect(cubit.state.codeSent, isTrue);
      expect(cubit.state.canSubmit, isTrue);
      expect(cubit.state.resendSecondsLeft, 60);
      expect(countdown.started, [60]);
      expect(cubit.state.canResend, isFalse);
    });

    test('while it is asked for, nothing can be submitted', () async {
      account.gate = Completer<void>();
      final cubit = AccountDeletionCubit(account, session, countdown);
      addTearDown(cubit.close);

      final starting = cubit.start();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AccountDeletionStatus.requesting);
      expect(await cubit.submit('2222'), isFalse);

      account.gate!.complete();
      await starting;
      expect(account.deletions, isEmpty);
    });

    test('a resend waits for the countdown, then sends another code and says so', () async {
      account.codeAnswers = [
        const Right(DeletionCode(expiresInSeconds: 120, resendAfterSeconds: 60)),
        const Right(DeletionCode(expiresInSeconds: 120, resendAfterSeconds: 90)),
      ];
      final cubit = await started();

      await cubit.resend();
      expect(account.codeRequests, 1, reason: 'the wait is not over');

      countdown.runOut(60);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendSecondsLeft, 0);
      expect(cubit.state.canResend, isTrue);

      await cubit.resend();
      expect(account.codeRequests, 2);
      expect(cubit.state.resentCount, 1);
      expect(cubit.state.resendSecondsLeft, 90);
    });

    test("too soon after the last SMS: the server's wait runs and the boxes stay closed until a code goes", () async {
      account.codeAnswers = [
        const Left(AuthFailure('x', code: 'OTP_RESEND_TOO_SOON', statusCode: 429, retryAfterSeconds: 40)),
        const Right(DeletionCode(expiresInSeconds: 120, resendAfterSeconds: 60)),
      ];
      final cubit = await started();

      expect(cubit.state.codeSent, isFalse);
      expect(cubit.state.canSubmit, isFalse);
      expect(cubit.state.error, AppStrings.deletionTooSoon);
      expect(cubit.state.resendSecondsLeft, 40);

      countdown.runOut(40);
      await Future<void>.delayed(Duration.zero);
      await cubit.resend();

      expect(cubit.state.codeSent, isTrue);
      expect(cubit.state.error, isNull);
    });
  });

  group('deleting', () {
    test('a wrong code keeps the account and the session, says so in Persian and clears the boxes', () async {
      final cubit = await started();

      final deleted = await cubit.submit('1111');

      expect(deleted, isFalse);
      expect(account.deletions, ['1111']);
      expect(cubit.state.error, AppStrings.deletionCodeInvalid);
      expect(cubit.state.errorCount, 1);
      expect(cubit.state.status, AccountDeletionStatus.idle);
      expect(session.state, isA<Authenticated>());
      expect(hooks, isEmpty);

      cubit.codeChanged();
      expect(cubit.state.error, isNull, reason: 'typing again clears it');
    });

    test('an expired code says to get a new one', () async {
      account.deleteAnswers = (_) => const Left(AuthFailure('server words', code: 'CODE_EXPIRED', statusCode: 400));
      final cubit = await started();

      await cubit.submit('2222');

      expect(cubit.state.error, AppStrings.deletionCodeExpired);
    });

    test("an unknown refusal shows the server's own message", () async {
      account.deleteAnswers = (_) => const Left(AuthFailure('به دلیل تلاش‌های ناموفق…', code: 'VERIFICATION_BLOCKED'));
      final cubit = await started();

      await cubit.submit('2222');

      expect(cubit.state.error, 'به دلیل تلاش‌های ناموفق…');
    });

    test('an incomplete code is not sent', () async {
      final cubit = await started();

      expect(await cubit.submit('22'), isFalse);

      expect(account.deletions, isEmpty);
      expect(cubit.state.error, AppStrings.codeIncomplete);
    });

    test('Persian digits are sent as ASCII', () async {
      final cubit = await started();

      await cubit.submit('۲۲۲۲');

      expect(account.deletions, ['2222']);
    });

    test("the right code deletes, then the session ends on sign-out's path with the deletion notice", () async {
      final cubit = await started();

      final deleted = await cubit.submit('2222');

      expect(deleted, isTrue);
      expect(cubit.state.status, AccountDeletionStatus.deleted);
      expect(hooks, ['unregister push with access-1'], reason: 'the before-sign-out hooks ran with the session');
      expect(await tokens.readSession(), isNull);
      expect(session.state, const Unauthenticated(notice: AppStrings.accountDeletedNotice));
      expect(cubit.state.canSubmit, isFalse);
      expect(await cubit.submit('2222'), isFalse, reason: 'nothing more to delete');
      expect(account.deletions, ['2222']);
    });
  });
}
