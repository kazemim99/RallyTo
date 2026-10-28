import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/notifications/domain/entities/notification.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_inbox_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_preferences_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/pages/notification_inbox_page.dart';
import 'package:rallyto_app/features/notifications/presentation/pages/notification_preferences_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_notifications.dart';
import '../../../../helpers/fake_realtime.dart';
import '../../../../helpers/router_shell.dart';

/// The notification inbox and the preferences screen.
void main() {
  late FakeNotificationRepository notifications;

  setUp(() => notifications = FakeNotificationRepository());

  group('inbox', () {
    Future<NotificationInboxCubit> show(WidgetTester tester) async {
      final cubit = NotificationInboxCubit(notifications, FakeRealtimeClient());
      addTearDown(cubit.close);
      await cubit.load();
      await pumpRouter(tester, [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: NotificationInboxPage(clock: () => DateTime.utc(2026, 10, 23, 8)),
          ),
        ),
        landingRoute(Routes.match),
        landingRoute(Routes.savedSearches),
        landingRoute(Routes.notificationSettings),
      ]);
      return cubit;
    }

    testWidgets('entries newest first with their time; unread ones marked', (tester) async {
      await show(tester);

      expect(find.text('درخواست پیوستن'), findsOneWidget);
      expect(find.text('جستجوی ذخیره‌شده'), findsOneWidget);
      expect(find.text('۱۱:۲۰'), findsOneWidget, reason: '07:50 UTC, today in Tehran');
      expect(find.byKey(NotificationInboxPage.unreadDotKey('n-2')), findsOneWidget);
      expect(find.byKey(NotificationInboxPage.unreadDotKey('n-1')), findsNothing);
      expect(
        tester.getTopLeft(find.text('درخواست پیوستن')).dy,
        lessThan(tester.getTopLeft(find.text('جستجوی ذخیره‌شده')).dy),
      );
    });

    testWidgets('tapping an entry marks it read and opens its screen', (tester) async {
      await show(tester);

      await tester.tap(find.byKey(NotificationInboxPage.itemKey('n-2')));
      await tester.pumpAndSettle();

      expect(notifications.calls, contains('read:n-2'));
      expect(find.text('landed /matches/m-1'), findsOneWidget);
    });

    testWidgets('a saved-search alert opens the saved searches', (tester) async {
      await show(tester);

      await tester.tap(find.byKey(NotificationInboxPage.itemKey('n-1')));
      await tester.pumpAndSettle();

      expect(find.text('landed /search/saved'), findsOneWidget);
    });

    testWidgets('«خواندن همه» is a text action, and only while something is unread', (tester) async {
      await show(tester);

      expect(find.widgetWithText(TextButton, AppStrings.markAllRead), findsOneWidget);
      await tester.tap(find.byKey(NotificationInboxPage.markAllReadKey));
      await tester.pumpAndSettle();

      expect(tester.widget<TextButton>(find.byKey(NotificationInboxPage.markAllReadKey)).onPressed, isNull);
    });

    testWidgets('each entry shows its category icon; unread ones are bold', (tester) async {
      notifications.pages = {
        1: NotificationPage(
          items: [
            testNotification(id: 'n-2', title: 'درخواست پیوستن', minute: 50),
            testNotification(
              id: 'n-1',
              title: 'جستجوی ذخیره‌شده',
              isRead: true,
              category: NotificationCategory.savedSearches,
            ),
          ],
          totalCount: 2,
        ),
      };
      await show(tester);

      final unread = find.byKey(NotificationInboxPage.itemKey('n-2'));
      final read = find.byKey(NotificationInboxPage.itemKey('n-1'));
      expect(find.descendant(of: unread, matching: find.byIcon(Icons.sports_tennis)), findsOneWidget);
      expect(find.descendant(of: read, matching: find.byIcon(Icons.bookmarks_outlined)), findsOneWidget);
      FontWeight? weight(Finder item, String title) =>
          tester.widget<Text>(find.descendant(of: item, matching: find.text(title))).style?.fontWeight;
      expect(weight(unread, 'درخواست پیوستن'), FontWeight.w700);
      expect(weight(read, 'جستجوی ذخیره‌شده'), isNot(FontWeight.w700));
    });

    testWidgets('mark all read clears the unread marks', (tester) async {
      await show(tester);

      await tester.tap(find.byKey(NotificationInboxPage.markAllReadKey));
      await tester.pumpAndSettle();

      expect(find.byKey(NotificationInboxPage.unreadDotKey('n-2')), findsNothing);
      expect(find.text(AppStrings.allMarkedRead), findsOneWidget);
    });

    testWidgets('a live notification appears at the top', (tester) async {
      await show(tester);

      notifications.emit(NotificationCreated(testNotification(id: 'n-9', title: 'بازی قطعی شد', minute: 59), 2));
      await tester.pumpAndSettle();

      expect(find.text('بازی قطعی شد'), findsOneWidget);
    });

    testWidgets('settings opens the preferences', (tester) async {
      await show(tester);

      await tester.tap(find.byKey(NotificationInboxPage.settingsKey));
      await tester.pumpAndSettle();

      expect(find.text('landed /notifications/settings'), findsOneWidget);
    });

    testWidgets('an empty inbox explains itself', (tester) async {
      notifications.pages = {1: const NotificationPage()};
      await show(tester);

      expect(find.text(AppStrings.notificationsEmptyTitle), findsOneWidget);
    });
  });

  group('preferences', () {
    Future<NotificationPreferencesCubit> show(WidgetTester tester) async {
      final cubit = NotificationPreferencesCubit(notifications);
      addTearDown(cubit.close);
      await cubit.load();
      await pumpInShell(tester, BlocProvider.value(value: cubit, child: const NotificationPreferencesPage()));
      return cubit;
    }

    testWidgets('a switch per category; account is on, disabled, and says why', (tester) async {
      await show(tester);

      for (final key in [
        NotificationPreferencesPage.matchesKey,
        NotificationPreferencesPage.chatKey,
        NotificationPreferencesPage.ratingsKey,
        NotificationPreferencesPage.savedSearchesKey,
      ]) {
        final tile = tester.widget<AppSwitchRow>(find.byKey(key));
        expect(tile.value, isTrue);
        expect(tile.onChanged, isNotNull);
      }
      final account = tester.widget<AppSwitchRow>(find.byKey(NotificationPreferencesPage.accountKey));
      expect(account.value, isTrue);
      expect(account.onChanged, isNull);
      expect(find.text(AppStrings.pushAccountHint), findsOneWidget);
    });

    testWidgets('turning a category off saves it', (tester) async {
      await show(tester);

      await tester.tap(find.byKey(NotificationPreferencesPage.savedSearchesKey));
      await tester.pumpAndSettle();

      expect(notifications.saved.single.pushSavedSearches, isFalse);
      expect(find.text(AppStrings.preferencesSaved), findsOneWidget);
    });

    testWidgets('quiet hours show 23:00 to 08:00 by default, and a new start is saved', (tester) async {
      await show(tester);

      expect(find.text('۲۳:۰۰'), findsOneWidget);
      expect(find.text('۰۸:۰۰'), findsOneWidget);

      await tester.ensureVisible(find.byKey(NotificationPreferencesPage.quietStartKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(NotificationPreferencesPage.quietStartKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('۲۲:۳۰').last);
      await tester.pumpAndSettle();

      expect(notifications.saved.single.quietStartMinute, 22 * 60 + 30);
      expect(notifications.saved.single.quietEndMinute, 8 * 60);
    });

    testWidgets('with quiet hours off the times cannot be changed', (tester) async {
      notifications.preferences = const NotificationPreferences(quietHoursEnabled: false);
      await show(tester);

      final start = tester.widget<DropdownButtonFormField<int>>(
        find.descendant(
          of: find.byKey(NotificationPreferencesPage.quietStartKey),
          matching: find.byType(DropdownButtonFormField<int>),
        ),
      );
      expect(start.onChanged, isNull);
    });
  });
}
