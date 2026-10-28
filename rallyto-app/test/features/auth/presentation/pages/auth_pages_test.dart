import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/core/auth/auth_error_codes.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/otp_sms_retriever.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';
import 'package:rallyto_app/features/auth/presentation/bloc/code_bloc.dart';
import 'package:rallyto_app/features/auth/presentation/bloc/phone_bloc.dart';
import 'package:rallyto_app/features/auth/presentation/pages/code_page.dart';
import 'package:rallyto_app/features/auth/presentation/pages/phone_page.dart';
import 'package:rallyto_app/features/auth/presentation/phone_mask.dart';
import 'package:rallyto_app/features/auth/presentation/widgets/auth_art.dart';
import 'package:rallyto_app/main.dart';

import '../../../../helpers/fake_auth.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// Both sign-in screens on their own: right-to-left with left-to-right numbers, the server's messages shown, and the
/// countdowns on the buttons.
void main() {
  late FakeAuthRepository repository;
  late FakeCountdown countdown;
  late TokenStorage tokens;
  late AuthSessionCubit session;

  setUp(() {
    repository = FakeAuthRepository();
    countdown = FakeCountdown();
    // Storage that yields with microtasks, so it finishes inside the widget test's fake-async zone.
    tokens = memoryTokenStorage(MemorySecureStorage(timers: false));
    session = AuthSessionCubit(tokens);
  });

  tearDown(() => session.close());

  /// [page] inside the app's shell (Persian, right-to-left, the app theme) with [bloc] and a session above it.
  Future<void> show<B extends StateStreamableSource<Object?>>(WidgetTester tester, B bloc, Widget page) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        theme: AppTheme.light,
        builder: buildAppShell,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: session),
            BlocProvider<B>.value(value: bloc),
          ],
          child: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('phone entry', () {
    Future<PhoneBloc> showPhone(WidgetTester tester) async {
      final bloc = PhoneBloc(repository, countdown);
      await show(tester, bloc, const PhonePage());
      return bloc;
    }

    testWidgets('renders right-to-left in Persian, with the number field left-to-right', (tester) async {
      await showPhone(tester);

      expect(Directionality.of(tester.element(find.text(AppStrings.phoneHeading))), TextDirection.rtl);
      expect(find.text(AppStrings.signInTagline), findsOneWidget);
      expect(find.text(AppStrings.phoneExplanation), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(PhonePage.phoneFieldKey));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.keyboardType, TextInputType.phone);
    });

    testWidgets('shows the brand art, read out as the app name, and the terms and 18+ note', (tester) async {
      await showPhone(tester);

      expect(find.byType(AuthArt), findsOneWidget);
      final brand = find.byKey(AuthArt.brandKey);
      final mark = tester.widget<BrandMark>(find.descendant(of: brand, matching: find.byType(BrandMark)));
      expect(mark.style, BrandMarkStyle.color, reason: 'the light-background mark on the white square');
      expect(tester.getSize(brand), const Size.square(76));
      expect(mark.size, closeTo(76 * 0.8, 0.01));
      expect(tester.getSemantics(brand), isSemantics(label: AppStrings.brandName));
      expect(find.text(AppStrings.signInTerms), findsOneWidget);
    });

    testWidgets("the server's sign-out message shows as a notice until dismissed", (tester) async {
      const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';
      await showPhone(tester);
      expect(find.byKey(PhonePage.signOutNoticeKey), findsNothing);

      await tester.runAsync(() async {
        await session.signIn(testSession());
        await tokens.clear(reason: message);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      final notice = find.byKey(PhonePage.signOutNoticeKey);
      expect(find.descendant(of: notice, matching: find.text(AppStrings.accountBlockedTitle)), findsOneWidget);
      expect(find.descendant(of: notice, matching: find.text(message)), findsOneWidget);

      await tester.tap(find.descendant(of: notice, matching: find.byTooltip(AppStrings.dismiss)));
      await tester.pumpAndSettle();
      expect(find.byKey(PhonePage.signOutNoticeKey), findsNothing);
      expect(find.text(message), findsNothing);
    });

    testWidgets('after the player deleted their account, a short notice says so until dismissed', (tester) async {
      await showPhone(tester);

      await tester.runAsync(() async {
        await session.signIn(testSession());
        await session.signOutDeletedAccount(AppStrings.accountDeletedNotice);
      });
      await tester.pumpAndSettle();

      final notice = find.byKey(PhonePage.deletedNoticeKey);
      expect(find.descendant(of: notice, matching: find.text(AppStrings.accountDeletedTitle)), findsOneWidget);
      expect(find.descendant(of: notice, matching: find.text(AppStrings.accountDeletedNotice)), findsOneWidget);
      expect(find.byKey(PhonePage.signOutNoticeKey), findsNothing, reason: 'not the blocked-account notice');
      expect(find.text(AppStrings.accountBlockedTitle), findsNothing);

      await tester.tap(find.descendant(of: notice, matching: find.byTooltip(AppStrings.dismiss)));
      await tester.pumpAndSettle();
      expect(find.byKey(PhonePage.deletedNoticeKey), findsNothing);
    });

    testWidgets('an invalid number is refused under the field', (tester) async {
      await showPhone(tester);

      await tester.enterText(find.byKey(PhonePage.phoneFieldKey), '0912');
      await tester.tap(find.text(AppStrings.sendCode));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.phoneInvalid), findsOneWidget);
      expect(repository.sentTo, isEmpty);
    });

    testWidgets("shows the server's error message", (tester) async {
      const message = 'ارسال پیامک ممکن نشد. کمی بعد تلاش کنید';
      repository.sendAnswers = [
        (_) => const Left(AuthFailure(message, code: AuthErrorCodes.smsSendFailed, statusCode: 503)),
      ];
      await showPhone(tester);

      await tester.enterText(find.byKey(PhonePage.phoneFieldKey), '۰۹۱۲۱۲۳۴۵۶۷');
      await tester.tap(find.text(AppStrings.sendCode));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(PhonePage.serverErrorKey), matching: find.text(message)), findsOneWidget);
      expect(repository.sentTo, ['09121234567']);
    });

    testWidgets('a 429 disables the button with a countdown in Persian digits', (tester) async {
      const message = 'لطفاً کمی بعد دوباره تلاش کنید';
      repository.sendAnswers = [
        (_) => const Left(
          AuthFailure(message, code: AuthErrorCodes.otpResendTooSoon, statusCode: 429, retryAfterSeconds: 75),
        ),
      ];
      await showPhone(tester);

      await tester.enterText(find.byKey(PhonePage.phoneFieldKey), '09121234567');
      await tester.tap(find.text(AppStrings.sendCode));
      await tester.pumpAndSettle();

      final waiting = find.widgetWithText(FilledButton, AppStrings.sendCodeAfter('۱:۱۵'));
      expect(waiting, findsOneWidget);
      expect(tester.widget<FilledButton>(waiting).onPressed, isNull);

      countdown.runOut(75);
      await tester.pumpAndSettle();
      final ready = find.widgetWithText(FilledButton, AppStrings.sendCode);
      expect(tester.widget<FilledButton>(ready).onPressed, isNotNull);
    });
  });

  group('code entry', () {
    const phone = '09121234567';

    Future<CodeBloc> showCode(WidgetTester tester) async {
      final bloc = CodeBloc(repository, session, countdown, challengeFor(phone))..add(const CodeStarted());
      await show(tester, bloc, CodePage(smsRetriever: OtpSmsRetriever(readSms: () async => null)));
      return bloc;
    }

    testWidgets('renders right-to-left, with the 4 code boxes left-to-right and the number masked in Persian digits', (
      tester,
    ) async {
      await showCode(tester);

      expect(Directionality.of(tester.element(find.text(AppStrings.codeHeading))), TextDirection.rtl);
      expect(find.text(AppStrings.codeSentTo(PhoneMask.mask(phone))), findsOneWidget);
      expect(find.textContaining('۰۹۱۲•••۴۵۶۷'), findsOneWidget);
      expect(find.textContaining('۱۲۳'), findsNothing, reason: 'the middle digits are hidden');
      expect(find.byType(AuthArt), findsOneWidget);
      expect(find.byType(OtpBoxes), findsOneWidget);
      final pinput = find.byType(Pinput);
      expect(tester.widget<Pinput>(pinput).length, 4);
      expect(Directionality.of(tester.element(pinput)), TextDirection.ltr);
      expect(find.text(AppStrings.editPhone), findsOneWidget);
    });

    testWidgets('listens for the SMS and offers the one-time-code autofill', (tester) async {
      await showCode(tester);

      final pinput = tester.widget<Pinput>(find.byType(Pinput));
      expect(pinput.smsRetriever, isA<OtpSmsRetriever>());
      expect(pinput.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testWidgets("shows the server's error message inline for a wrong code, and clears the boxes", (tester) async {
      const message = 'کد واردشده اشتباه است';
      repository.verifyAnswers = [const Left(AuthFailure(message, code: AuthErrorCodes.codeInvalid, statusCode: 400))];
      await showCode(tester);

      await tester.enterText(find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)), '1111');
      await tester.pumpAndSettle();

      expect(repository.verified, [(phone, '1111')]);
      expect(find.text(message), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
    });

    testWidgets('a suspended account sees the server message in a dialog', (tester) async {
      const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';
      repository.verifyAnswers = [
        const Left(AuthFailure(message, code: AuthErrorCodes.accountSuspended, statusCode: 403)),
      ];
      await showCode(tester);

      await tester.enterText(find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)), '4821');
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.accountBlockedTitle), findsOneWidget);
      expect(find.widgetWithText(AlertDialog, message), findsOneWidget);
    });

    testWidgets('counts the resend wait down, then offers to resend', (tester) async {
      await showCode(tester);

      expect(find.text(AppStrings.resendCodeAfter('۱:۰۰')), findsOneWidget);
      expect(find.text(AppStrings.resendCode), findsNothing);

      countdown.runOut(60);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.resendCode));
      await tester.pumpAndSettle();

      expect(repository.sentTo, [phone]);
      expect(find.text(AppStrings.codeResent), findsOneWidget);
      expect(find.text(AppStrings.resendCodeAfter('۱:۰۰')), findsOneWidget);
    });
  });
}
