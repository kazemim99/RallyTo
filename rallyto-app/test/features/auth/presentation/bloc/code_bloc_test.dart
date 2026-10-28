import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_error_codes.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';
import 'package:rallyto_app/features/auth/presentation/bloc/code_bloc.dart';

import '../../../../helpers/fake_auth.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// Code entry: a verified code signs in (tokens stored, session state updated); a wrong one is said inline; a
/// suspended account is said in a dialog; a new code is offered once the server's resend wait is over.
void main() {
  const phone = '09121234567';

  late FakeAuthRepository repository;
  late FakeCountdown countdown;
  late TokenStorage tokens;
  late AuthSessionCubit session;
  late CodeBloc bloc;

  setUp(() {
    repository = FakeAuthRepository();
    countdown = FakeCountdown();
    tokens = memoryTokenStorage();
    session = AuthSessionCubit(tokens);
    bloc = CodeBloc(repository, session, countdown, challengeFor(phone))..add(const CodeStarted());
  });

  tearDown(() async {
    await bloc.close();
    await session.close();
  });

  /// Lets the bloc (and storage, which yields once per operation) finish what was added so far.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('a correct code', () {
    test('in Persian digits is sent in ASCII, stores the tokens and signs in, profile not yet completed', () async {
      bloc.add(const CodeSubmitted('۴۸۲۱'));
      await settle();

      expect(repository.verified, [(phone, '4821')]);
      expect(bloc.state.status, CodeStatus.verified);
      expect(session.state, const Authenticated(profileCompleted: false, roles: ['Player']));
      final stored = await tokens.readSession();
      expect(stored?.accessToken, 'access-new');
      expect(stored?.refreshToken, 'refresh-new');
    });

    test('of an onboarded player signs in with the profile completed', () async {
      repository.verifyAnswers = [Right(sessionFromServer(profileCompleted: true))];

      bloc.add(const CodeSubmitted('4821'));
      await settle();

      expect(session.state, const Authenticated(profileCompleted: true, roles: ['Player']));
    });
  });

  group('a wrong code', () {
    const message = 'کد واردشده اشتباه است';

    setUp(() {
      repository.verifyAnswers = [
        const Left(AuthFailure(message, code: AuthErrorCodes.codeInvalid, statusCode: 400)),
        Right(sessionFromServer()),
      ];
    });

    test("shows the server's message inline and keeps the player signed out", () async {
      bloc.add(const CodeSubmitted('1111'));
      await settle();

      expect(bloc.state.error, message);
      expect(bloc.state.errorCount, 1, reason: 'the screen clears the boxes for the next try');
      expect(bloc.state.status, CodeStatus.idle);
      expect(bloc.state.blockedMessage, isNull);
      expect(session.state, const Unauthenticated());
      expect(await tokens.readSession(), isNull);
    });

    test('the message goes as the player edits, and the next code can still sign in', () async {
      bloc.add(const CodeSubmitted('1111'));
      await settle();
      bloc.add(const CodeChanged());
      await settle();
      expect(bloc.state.error, isNull);

      bloc.add(const CodeSubmitted('4821'));
      await settle();
      expect(session.state, isA<Authenticated>());
    });
  });

  test('an incomplete code is refused without calling the server', () async {
    bloc.add(const CodeSubmitted('48'));
    await settle();

    expect(bloc.state.error, AppStrings.codeIncomplete);
    expect(repository.verified, isEmpty);
  });

  test('an expired code says so inline', () async {
    const message = 'کد منقضی شده است. کد جدید بگیرید';
    repository.verifyAnswers = [const Left(AuthFailure(message, code: AuthErrorCodes.codeExpired, statusCode: 400))];

    bloc.add(const CodeSubmitted('4821'));
    await settle();

    expect(bloc.state.error, message);
  });

  group('a blocked account', () {
    test(
      'suspended: the server message (with its Jalali end date) goes to the dialog, and the player stays out',
      () async {
        const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';
        repository.verifyAnswers = [
          const Left(AuthFailure(message, code: AuthErrorCodes.accountSuspended, statusCode: 403)),
        ];

        bloc.add(const CodeSubmitted('4821'));
        await settle();

        expect(bloc.state.blockedMessage, message);
        expect(bloc.state.error, isNull, reason: 'a dialog, not the inline line');
        expect(bloc.state.status, CodeStatus.idle);
        expect(session.state, const Unauthenticated());
        expect(await tokens.readSession(), isNull);

        bloc.add(const CodeBlockedDismissed());
        await settle();
        expect(bloc.state.blockedMessage, isNull);
      },
    );

    test('banned: the same', () async {
      const message = 'حساب شما مسدود شده است';
      repository.verifyAnswers = [
        const Left(AuthFailure(message, code: AuthErrorCodes.accountBanned, statusCode: 403)),
      ];

      bloc.add(const CodeSubmitted('4821'));
      await settle();

      expect(bloc.state.blockedMessage, message);
      expect(session.state, const Unauthenticated());
    });
  });

  group('resend', () {
    test("waits out the server's resendAfterSeconds first", () async {
      await settle();

      expect(countdown.started, [60]);
      expect(bloc.state.resendSecondsLeft, 60);
      expect(bloc.state.canResend, isFalse);

      bloc.add(const CodeResendRequested());
      await settle();
      expect(repository.sentTo, isEmpty, reason: 'no resend before the countdown ends');

      countdown.tick(59);
      await settle();
      expect(bloc.state.resendSecondsLeft, 59);
    });

    test('after the countdown, sends a new code, confirms it and starts the wait again', () async {
      await settle();
      countdown.runOut(60);
      await settle();
      expect(bloc.state.canResend, isTrue);

      bloc.add(const CodeResendRequested());
      await settle();

      expect(repository.sentTo, [phone]);
      expect(bloc.state.resentCount, 1);
      expect(bloc.state.error, isNull);
      expect(countdown.started, [60, 60]);
      expect(bloc.state.resendSecondsLeft, 60);
      expect(bloc.state.canResend, isFalse);
    });

    test("a refused resend (429) shows the message and waits the server's Retry-After", () async {
      const message = 'تعداد درخواست‌های کد بیش از حد مجاز است';
      repository.sendAnswers = [
        (_) => const Left(
          AuthFailure(message, code: AuthErrorCodes.otpSendLimit, statusCode: 429, retryAfterSeconds: 600),
        ),
      ];
      await settle();
      countdown.runOut(60);
      await settle();

      bloc.add(const CodeResendRequested());
      await settle();

      expect(bloc.state.error, message);
      expect(bloc.state.resendSecondsLeft, 600);
      expect(countdown.started, [60, 600]);
    });
  });
}
