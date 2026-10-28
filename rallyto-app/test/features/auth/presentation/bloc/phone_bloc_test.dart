import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_error_codes.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';
import 'package:rallyto_app/features/auth/presentation/bloc/phone_bloc.dart';

import '../../../../helpers/fake_auth.dart';

/// Phone entry: a number typed in any digits is checked as an Iranian mobile, sent in its canonical form, and the
/// send button waits out the server's `Retry-After`.
void main() {
  late FakeAuthRepository repository;
  late FakeCountdown countdown;
  late PhoneBloc bloc;

  setUp(() {
    repository = FakeAuthRepository();
    countdown = FakeCountdown();
    bloc = PhoneBloc(repository, countdown);
  });

  tearDown(() => bloc.close());

  /// Lets the bloc handle everything added so far.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> submit(String phone) async {
    bloc
      ..add(PhoneChanged(phone))
      ..add(const PhoneSubmitted());
    await settle();
  }

  test('a valid number in Persian digits is sent in canonical form, and the code is on its way', () async {
    final states = <PhoneState>[];
    final sub = bloc.stream.listen(states.add);

    await submit('۰۹۱۲ ۱۲۳ ۴۵۶۷');
    await sub.cancel();

    expect(repository.sentTo, ['09121234567']);
    expect(states.map((s) => s.status), [PhoneStatus.editing, PhoneStatus.sending, PhoneStatus.codeSent]);
    expect(bloc.state.challenge, challengeFor('09121234567'));
    expect(bloc.state.fieldError, isNull);
    expect(bloc.state.serverError, isNull);
  });

  test('+98 and 10-digit forms are accepted too', () async {
    await submit('+98 912 123 4567');
    await submit('9121234567');

    expect(repository.sentTo, ['09121234567', '09121234567']);
  });

  group('an invalid number', () {
    test('is refused inline without calling the server', () async {
      await submit('0912123');

      expect(bloc.state.fieldError, AppStrings.phoneInvalid);
      expect(bloc.state.status, PhoneStatus.editing);
      expect(repository.sentTo, isEmpty);
    });

    test('an empty field asks for the number', () async {
      await submit('');

      expect(bloc.state.fieldError, AppStrings.phoneRequired);
      expect(repository.sentTo, isEmpty);
    });

    test('a landline is not a mobile', () async {
      await submit('02188776655');

      expect(bloc.state.fieldError, AppStrings.phoneInvalid);
    });

    test('the message follows the typing once shown, and goes when the number is right', () async {
      await submit('0912');
      bloc.add(const PhoneChanged('091212'));
      await settle();
      expect(bloc.state.fieldError, AppStrings.phoneInvalid);

      bloc.add(const PhoneChanged('09121234567'));
      await settle();
      expect(bloc.state.fieldError, isNull);
    });

    test("the server's INVALID_PHONE_NUMBER message goes under the field", () async {
      const message = 'شماره موبایل نامعتبر است';
      repository.sendAnswers = [
        (_) => const Left(AuthFailure(message, code: AuthErrorCodes.invalidPhoneNumber, statusCode: 400)),
      ];

      await submit('09121234567');

      expect(bloc.state.fieldError, message);
      expect(bloc.state.serverError, isNull);
    });
  });

  group('429 with Retry-After', () {
    const message = 'لطفاً ۴۵ ثانیه دیگر دوباره تلاش کنید';

    setUp(() {
      repository.sendAnswers = [
        (_) => const Left(
          AuthFailure(message, code: AuthErrorCodes.otpResendTooSoon, statusCode: 429, retryAfterSeconds: 3),
        ),
        (phone) => Right(challengeFor(phone)),
      ];
    });

    test("shows the server's message and holds the button for the server's wait", () async {
      await submit('09121234567');

      expect(bloc.state.serverError, message);
      expect(bloc.state.cooldownSeconds, 3);
      expect(bloc.state.canSubmit, isFalse);
      expect(countdown.started, [3]);

      bloc.add(const PhoneSubmitted());
      await settle();
      expect(repository.sentTo, hasLength(1), reason: 'no request while the server asks to wait');
    });

    test('counts down, then sends again', () async {
      await submit('09121234567');

      countdown.tick(2);
      await settle();
      expect(bloc.state.cooldownSeconds, 2);

      countdown.runOut(2);
      await settle();
      expect(bloc.state.cooldownSeconds, 0);
      expect(bloc.state.canSubmit, isTrue);

      bloc.add(const PhoneSubmitted());
      await settle();
      expect(repository.sentTo, hasLength(2));
      expect(bloc.state.status, PhoneStatus.codeSent);
    });
  });

  test('a failure without a wait (SMS provider down) shows the message and allows another try', () async {
    const message = 'ارسال پیامک ممکن نشد. کمی بعد تلاش کنید';
    repository.sendAnswers = [
      (_) => const Left(AuthFailure(message, code: AuthErrorCodes.smsSendFailed, statusCode: 503)),
    ];

    await submit('09121234567');

    expect(bloc.state.serverError, message);
    expect(bloc.state.cooldownSeconds, 0);
    expect(bloc.state.canSubmit, isTrue);
    expect(countdown.started, isEmpty);
  });
}
