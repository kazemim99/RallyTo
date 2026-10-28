import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/di/injection.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/account/domain/account_repository.dart';
import 'package:rallyto_app/features/account/presentation/bloc/account_deletion_cubit.dart';
import 'package:rallyto_app/features/account/presentation/pages/account_deletion_page.dart';
import 'package:rallyto_app/features/account/presentation/widgets/account_deletion_sheet.dart';
import 'package:rallyto_app/features/auth/domain/auth_failure.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/my_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/pages/my_profile_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_account.dart';
import '../../../../helpers/fake_auth.dart';
import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// Deleting the account from My Profile: the danger action, the sheet that says what deletion does, the code screen
/// (boxes, resend countdown, Persian errors), and the session ending on sign-out's path once the code is right.
void main() {
  late FakeAccountRepository account;
  late FakeCountdown countdown;
  late TokenStorage tokens;
  late AuthSessionCubit session;
  late List<String> hooks;

  setUp(() {
    account = FakeAccountRepository();
    countdown = FakeCountdown();
    hooks = [];
    getIt.registerFactory<AccountDeletionCubit>(() => AccountDeletionCubit(account, session, countdown));
  });

  tearDown(() => getIt.reset());

  Future<void> showMyProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Made inside the test, with storage that yields with microtasks, so it all runs in the widget test's fake-async
    // zone.
    tokens = memoryTokenStorage(MemorySecureStorage(timers: false));
    session = AuthSessionCubit(tokens);
    addTearDown(session.close);
    session.addBeforeSignOut(() async => hooks.add('unregister push'));
    await session.signIn(testSession(profileCompleted: true));
    final profile = MyProfileCubit(FakeProfileRepository(), FakeCatalogRepository());
    addTearDown(profile.close);
    await profile.load();
    await pumpInShell(
      tester,
      BlocProvider.value(
        value: session,
        child: BlocProvider.value(value: profile, child: const MyProfilePage()),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(MyProfilePage.deleteAccountKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MyProfilePage.deleteAccountKey));
    await tester.pumpAndSettle();
  }

  Future<void> continueToCode(WidgetTester tester) async {
    await openSheet(tester);
    await tester.ensureVisible(find.byKey(AccountDeletionSheet.continueKey));
    await tester.tap(find.byKey(AccountDeletionSheet.continueKey));
    await tester.pumpAndSettle();
  }

  Future<void> typeCode(WidgetTester tester, String code) async {
    await tester.enterText(find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)), code);
    await tester.pumpAndSettle();
  }

  testWidgets('the danger action at the bottom of My Profile opens a sheet that says what deletion does', (
    tester,
  ) async {
    await showMyProfile(tester);

    final signOut = tester.getTopLeft(find.byKey(MyProfilePage.signOutKey)).dy;
    final delete = tester.getTopLeft(find.byKey(MyProfilePage.deleteAccountKey)).dy;
    expect(delete, greaterThan(signOut), reason: 'the last row of the page');
    expect(find.text(AppStrings.deleteAccount), findsOneWidget);

    await openSheet(tester);

    expect(find.text(AppStrings.deleteAccountQuestion), findsOneWidget);
    for (final consequence in [
      AppStrings.deleteAccountAnonymised,
      AppStrings.deleteAccountGames,
      AppStrings.deleteAccountMessages,
      AppStrings.deleteAccountIrreversible,
      AppStrings.deleteAccountCodeHint,
    ]) {
      expect(find.text(consequence), findsOneWidget);
    }
    expect(account.codeRequests, 0, reason: 'no code before the player goes on');
  });

  testWidgets('cancelling the sheet changes nothing', (tester) async {
    await showMyProfile(tester);
    await openSheet(tester);

    await tester.ensureVisible(find.byKey(AccountDeletionSheet.cancelKey));
    await tester.tap(find.byKey(AccountDeletionSheet.cancelKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.deleteAccountQuestion), findsNothing);
    expect(find.byType(AccountDeletionPage), findsNothing);
    expect(account.codeRequests, 0);
    expect(session.state, isA<Authenticated>());
  });

  testWidgets('going on asks for a code and shows the boxes with the resend countdown', (tester) async {
    await showMyProfile(tester);

    await continueToCode(tester);

    expect(find.byType(AccountDeletionPage), findsOneWidget);
    expect(account.codeRequests, 1);
    expect(find.text(AppStrings.deleteAccountCodeHeading), findsOneWidget);
    expect(find.text(AppStrings.deleteAccountCodeSent), findsOneWidget);
    expect(find.byKey(AccountDeletionPage.codeKey), findsOneWidget);
    expect(find.text(AppStrings.resendCodeAfter('۱:۰۰')), findsOneWidget);
    expect(find.byKey(AccountDeletionPage.resendKey), findsNothing);
  });

  testWidgets('a wrong code is refused in Persian, the boxes empty, and the account stays', (tester) async {
    await showMyProfile(tester);
    await continueToCode(tester);

    await typeCode(tester, '1111');

    expect(account.deletions, ['1111'], reason: 'sent as soon as the boxes are full');
    expect(find.text(AppStrings.deletionCodeInvalid), findsOneWidget);
    final field = tester.widget<EditableText>(
      find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)),
    );
    expect(field.controller.text, isEmpty, reason: 'ready for the next try');
    expect(session.state, isA<Authenticated>());
    expect(hooks, isEmpty);
  });

  testWidgets('once the countdown runs out, another code can be asked for, and that is confirmed', (tester) async {
    await showMyProfile(tester);
    await continueToCode(tester);

    countdown.runOut(60);
    await tester.pumpAndSettle();
    expect(find.byKey(AccountDeletionPage.resendCountdownKey), findsNothing);
    await tester.tap(find.byKey(AccountDeletionPage.resendKey));
    await tester.pumpAndSettle();

    expect(account.codeRequests, 2);
    expect(find.text(AppStrings.codeResent), findsOneWidget);
    expect(find.byKey(AccountDeletionPage.resendCountdownKey), findsOneWidget, reason: 'a new wait');
  });

  testWidgets('too soon after the last SMS: the wait is shown and the boxes stay closed until a code goes', (
    tester,
  ) async {
    account.codeAnswers = [
      const Left(AuthFailure('x', code: 'OTP_RESEND_TOO_SOON', statusCode: 429, retryAfterSeconds: 30)),
      const Right(DeletionCode(expiresInSeconds: 120, resendAfterSeconds: 60)),
    ];
    await showMyProfile(tester);
    await continueToCode(tester);

    expect(find.text(AppStrings.deletionTooSoon), findsOneWidget);
    expect(find.text(AppStrings.deleteAccountNotSent), findsOneWidget);
    expect(find.text(AppStrings.resendCodeAfter('۰:۳۰')), findsOneWidget);

    countdown.runOut(30);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.deleteAccountGetCode), findsOneWidget);
    await tester.tap(find.byKey(AccountDeletionPage.resendKey));
    await tester.pumpAndSettle();

    expect(account.codeRequests, 2);
    expect(find.text(AppStrings.deleteAccountCodeSent), findsOneWidget);
  });

  testWidgets('the right code deletes the account and ends the session with the deletion notice', (tester) async {
    await showMyProfile(tester);
    await continueToCode(tester);

    await typeCode(tester, '1111');
    await tester.enterText(
      find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)),
      FakeAccountRepository.sandboxCode,
    );
    // Not pumpAndSettle: the button spins until the router (not here) moves the player to phone entry.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(account.deletions, ['1111', '2222']);
    expect(hooks, ['unregister push'], reason: 'the device token is unregistered on the way out');
    expect(session.state, const Unauthenticated(notice: AppStrings.accountDeletedNotice));
    expect(await tokens.readSession(), isNull);
    final confirm = tester.widget<AppButton>(find.byKey(AccountDeletionPage.confirmKey));
    expect(confirm.loading, isTrue, reason: 'nothing more to press while the app leaves');
  });
}
