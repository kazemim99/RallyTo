import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/auth/auth_session.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/di/injection.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';
import 'package:rallyto_app/features/auth/presentation/pages/code_page.dart';
import 'package:rallyto_app/features/auth/presentation/pages/phone_page.dart';
import 'package:rallyto_app/features/availability/domain/availability_repository.dart';
import 'package:rallyto_app/features/catalog/domain/catalog_repository.dart';
import 'package:rallyto_app/features/chat/domain/chat_repository.dart';
import 'package:rallyto_app/features/home/presentation/pages/home_page.dart';
import 'package:rallyto_app/features/matches/domain/match_repository.dart';
import 'package:rallyto_app/features/notifications/domain/notification_repository.dart';
import 'package:rallyto_app/features/notifications/presentation/pages/notification_inbox_page.dart';
import 'package:rallyto_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:rallyto_app/features/profile/domain/profile_repository.dart';
import 'package:rallyto_app/features/profile/presentation/pages/my_profile_page.dart';
import 'package:rallyto_app/main.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_catalog.dart';
import 'helpers/fake_chat.dart';
import 'helpers/fake_matches.dart';
import 'helpers/fake_notifications.dart';
import 'helpers/fake_profile.dart';
import 'helpers/fake_realtime.dart';
import 'helpers/memory_secure_storage.dart';

/// The app shell (Persian, right-to-left, Material 3) and the sign-in journey through the router: the screen always
/// follows the stored session, whoever changes it.
void main() {
  /// Starts the app as `main()` does: register dependencies, restore the stored session, then show the first screen.
  /// The API and secure storage are fakes; everything is created inside the test, in its fake-async zone.
  Future<(AuthSessionCubit, TokenStorage, FakeAuthApi)> startApp(
    WidgetTester tester, {
    AuthSession? stored,
    Stream<String>? deepLinks,
  }) async {
    // A phone-sized window, as the app is used: the test default (800×600) is a tablet, which the viewport frame
    // would draw as a narrower column.
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The code field's cursor blinks forever otherwise, and nothing would ever settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await configureDependencies();
    addTearDown(getIt.reset);

    final storage = MemorySecureStorage(timers: false);
    if (stored != null) storage.values[TokenStorage.sessionKey] = stored.encode();
    final tokens = TokenStorage(SecureStorageService(storage));
    final api = FakeAuthApi();
    final session = AuthSessionCubit(tokens, api: api);
    addTearDown(session.close);
    getIt
      ..unregister<AuthApi>()
      ..registerSingleton<AuthApi>(api)
      ..unregister<TokenStorage>()
      ..registerSingleton<TokenStorage>(tokens)
      ..unregister<AuthSessionCubit>()
      ..registerSingleton<AuthSessionCubit>(session)
      // Onboarding loads the sports as it opens; no request may leave the test.
      ..unregister<CatalogRepository>()
      ..registerSingleton<CatalogRepository>(FakeCatalogRepository())
      // Home's badges read the chat and notification counts, and listen to the realtime hub.
      ..unregister<ChatRepository>()
      ..registerSingleton<ChatRepository>(FakeChatRepository())
      ..unregister<NotificationRepository>()
      ..registerSingleton<NotificationRepository>(FakeNotificationRepository())
      ..unregister<RealtimeClient>()
      ..registerSingleton<RealtimeClient>(FakeRealtimeClient())
      // Home and the profile tab load these; fakes keep the app off the network.
      ..unregister<ProfileRepository>()
      ..registerSingleton<ProfileRepository>(FakeProfileRepository())
      ..unregister<MatchRepository>()
      ..registerSingleton<MatchRepository>(FakeMatchRepository())
      ..unregister<AvailabilityRepository>()
      ..registerSingleton<AvailabilityRepository>(FakeAvailabilityRepository());

    await session.restore();
    await tester.pumpWidget(RallytoApp(session: session, deepLinks: deepLinks));
    await tester.pumpAndSettle();
    return (session, tokens, api);
  }

  Future<void> requestCode(WidgetTester tester, String phone) async {
    await tester.enterText(find.byKey(PhonePage.phoneFieldKey), phone);
    await tester.tap(find.text(AppStrings.sendCode));
    await tester.pumpAndSettle();
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)), code);
    await tester.pumpAndSettle();
  }

  testWidgets('the app is Persian, right-to-left, Material 3, and titled رالیتو', (tester) async {
    await startApp(tester);

    final context = tester.element(find.byType(PhonePage));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context), const Locale('fa', 'IR'));
    expect(Theme.of(context).useMaterial3, isTrue);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, AppStrings.appName);
    expect(app.supportedLocales, [const Locale('fa', 'IR')]);
  });

  testWidgets('the app is always light, whatever the device theme: the approved design has no dark version', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await startApp(tester);

    final context = tester.element(find.byType(PhonePage));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.light);
  });

  testWidgets('signed out, the app opens on phone entry', (tester) async {
    await startApp(tester);

    expect(find.byType(PhonePage), findsOneWidget);
  });

  testWidgets('a restored, onboarded session opens on home', (tester) async {
    await startApp(tester, stored: testSession(profileCompleted: true));

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets("a tapped push's location opens over home", (tester) async {
    final links = StreamController<String>();
    addTearDown(links.close);
    await startApp(tester, stored: testSession(profileCompleted: true), deepLinks: links.stream);

    links.add('/notifications');
    await tester.pumpAndSettle();

    expect(find.byType(NotificationInboxPage), findsOneWidget);
  });

  testWidgets('signing in without a profile holds the player on onboarding; completing it goes home', (tester) async {
    final (session, _, _) = await startApp(tester);

    await session.signIn(testSession(profileCompleted: false));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    await session.signIn(testSession(profileCompleted: true));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  group('phone sign-in', () {
    testWidgets('a new player: Persian-digit number → code → onboarding, with the tokens stored', (tester) async {
      final (_, tokens, api) = await startApp(tester);

      await requestCode(tester, '۰۹۱۲ ۱۲۳ ۴۵۶۷');
      expect(api.sentTo, ['09121234567'], reason: 'normalised to the canonical form before sending');
      expect(find.byType(CodePage), findsOneWidget);

      await enterCode(tester, '۴۸۲۱');

      expect(api.verified.single.phoneNumber, '09121234567');
      expect(api.verified.single.code, '4821', reason: 'sent in ASCII digits');
      expect(find.byType(OnboardingPage), findsOneWidget);
      final stored = await tokens.readSession();
      expect(stored?.accessToken, 'access-new');
      expect(stored?.refreshToken, 'refresh-new');
      expect(stored?.profileCompleted, isFalse);
    });

    testWidgets('a player with a completed profile lands on home', (tester) async {
      final (_, _, api) = await startApp(tester);
      api.profileCompleted = true;

      await requestCode(tester, '9121234567');
      await enterCode(tester, '4821');

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('"edit number" returns to phone entry with the number kept', (tester) async {
      await startApp(tester);

      await requestCode(tester, '09121234567');
      await tester.tap(find.text(AppStrings.editPhone));
      await tester.pumpAndSettle();

      expect(find.byType(PhonePage), findsOneWidget);
      expect(find.text('09121234567'), findsOneWidget);
    });

    testWidgets('a suspended account is told why in a dialog and stays on code entry', (tester) async {
      final (_, tokens, api) = await startApp(tester);
      const message = 'حساب شما تا ۱۴۰۵/۰۸/۱۰ تعلیق شده است';
      api.verifyError = apiError(403, 'ACCOUNT_SUSPENDED', message);

      await requestCode(tester, '09121234567');
      await enterCode(tester, '4821');

      expect(find.widgetWithText(AlertDialog, message), findsOneWidget);
      await tester.tap(find.text(AppStrings.understood));
      await tester.pumpAndSettle();
      expect(find.byType(CodePage), findsOneWidget);
      expect(await tokens.readSession(), isNull);
    });
  });

  group('signing out', () {
    testWidgets('from the profile tab returns to phone entry, and revokes the refresh token on the server', (
      tester,
    ) async {
      final (_, tokens, api) = await startApp(tester, stored: testSession(profileCompleted: true));

      await tester.tap(find.text(AppStrings.navProfile));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(MyProfilePage.signOutKey), 200);
      await tester.tap(find.byKey(MyProfilePage.signOutKey));
      await tester.pumpAndSettle();

      expect(find.byType(PhonePage), findsOneWidget);
      expect(await tokens.readSession(), isNull);
      expect(api.signedOut, [('refresh-1', 'Bearer access-1')]);
    });

    testWidgets('a session cleared elsewhere (a refused refresh) returns to phone entry', (tester) async {
      final (_, tokens, _) = await startApp(tester, stored: testSession(profileCompleted: true));

      await tokens.clear();
      await tester.pumpAndSettle();

      expect(find.byType(PhonePage), findsOneWidget);
    });

    testWidgets('an account the server ended returns to phone entry showing its message, until dismissed', (
      tester,
    ) async {
      final (_, tokens, _) = await startApp(tester, stored: testSession(profileCompleted: true));
      const message = 'حساب کاربری شما مسدود شده است';

      await tokens.clear(reason: message);
      await tester.pumpAndSettle();

      expect(find.byType(PhonePage), findsOneWidget);
      expect(find.text(message), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.dismiss));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });
  });
}
