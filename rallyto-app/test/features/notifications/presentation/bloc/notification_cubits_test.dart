import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/notifications/domain/entities/notification.dart';
import 'package:rallyto_app/features/notifications/domain/notification_rules.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_badge_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_inbox_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_preferences_cubit.dart';

import '../../../../helpers/fake_notifications.dart';
import '../../../../helpers/fake_realtime.dart';

/// The inbox (pages, read state, live entries), the home badge (live count), and the preferences (each change saved,
/// refusals undone).
void main() {
  late FakeNotificationRepository notifications;
  late FakeRealtimeClient realtime;

  setUp(() {
    notifications = FakeNotificationRepository();
    realtime = FakeRealtimeClient();
  });

  group('inbox', () {
    Future<NotificationInboxCubit> open() async {
      final cubit = NotificationInboxCubit(notifications, realtime);
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('loads the first page, newest first', () async {
      final cubit = await open();

      expect(cubit.state.status, ViewStatus.content);
      expect(cubit.state.items.map((n) => n.id), ['n-2', 'n-1']);
      expect(cubit.state.hasUnread, isTrue);
      expect(cubit.state.hasMore, isFalse);
    });

    test('nothing yet is empty; a failure is an error to retry', () async {
      notifications.pages = {1: const NotificationPage()};
      expect((await open()).state.status, ViewStatus.empty);

      notifications.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      final failed = await open();
      expect(failed.state.status, ViewStatus.error);
      expect(failed.state.errorMessage, AppStrings.offlineActionError);
    });

    test('more pages on request, without repeats', () async {
      notifications.pages = {
        1: NotificationPage(items: [testNotification(id: 'n-3', minute: 30)], totalCount: 3, pageSize: 1),
        2: NotificationPage(
          items: [
            testNotification(id: 'n-3', minute: 30),
            testNotification(id: 'n-2', minute: 20),
          ],
          page: 2,
          totalCount: 3,
          pageSize: 2,
        ),
      };
      final cubit = await open();
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();

      expect(notifications.calls.last, 'inbox:2');
      expect(cubit.state.items.map((n) => n.id), ['n-3', 'n-2']);
      expect(cubit.state.page, 2);
      expect(cubit.state.hasMore, isFalse);
    });

    test('opening an unread entry marks it read and answers where its link leads', () async {
      final cubit = await open();

      final location = await cubit.open(cubit.state.items.first);

      expect(location, Routes.matchPath('m-1'));
      expect(cubit.state.items.first.isRead, isTrue);
      expect(notifications.calls, contains('read:n-2'));
    });

    test('opening a read entry does not mark it again; a link the app does not know leads nowhere', () async {
      notifications.pages = {
        1: NotificationPage(
          items: [testNotification(id: 'n-1', isRead: true, deepLink: '/unknown')],
          totalCount: 1,
        ),
      };
      final cubit = await open();

      expect(await cubit.open(cubit.state.items.single), isNull);
      expect(notifications.calls.where((c) => c.startsWith('read:')), isEmpty);
    });

    test('marking all read', () async {
      final cubit = await open();

      await cubit.markAllRead();

      expect(notifications.calls.last, 'readAll');
      expect(cubit.state.hasUnread, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.allMarkedRead);
    });

    test('a refused mark-all keeps the entries as they were', () async {
      final cubit = await open();
      notifications.actionFailure = const NetworkFailure(AppStrings.offlineActionError);

      await cubit.markAllRead();

      expect(cubit.state.hasUnread, isTrue);
      expect(cubit.state.feedback?.isError, isTrue);
    });

    test('a new notification over the hub goes to the top, once', () async {
      final cubit = await open();
      final fresh = testNotification(id: 'n-9', title: 'بازی قطعی شد', minute: 59);

      notifications.emit(NotificationCreated(fresh, 2));
      notifications.emit(NotificationCreated(fresh, 2));

      expect(cubit.state.items.map((n) => n.id), ['n-9', 'n-2', 'n-1']);
    });

    test('a new notification fills an empty inbox', () async {
      notifications.pages = {1: const NotificationPage()};
      final cubit = await open();

      notifications.emit(NotificationCreated(testNotification(id: 'n-9'), 1));

      expect(cubit.state.status, ViewStatus.content);
    });

    test('with the hub down the first page is re-read every 60 s', () {
      fakeAsync((async) {
        realtime.setStatus(RealtimeStatus.disconnected);
        final cubit = NotificationInboxCubit(notifications, realtime);
        unawaited(cubit.load());
        async.flushMicrotasks();
        notifications.calls.clear();
        notifications.pages = {
          1: NotificationPage(items: [testNotification(id: 'n-7', minute: 55)], totalCount: 3),
        };

        async.elapse(const Duration(seconds: 60));

        expect(notifications.calls, ['inbox:1']);
        expect(cubit.state.items.first.id, 'n-7');
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });

  group('home badge', () {
    test('starts with the unread count, then follows notification.created live', () async {
      final cubit = NotificationBadgeCubit(notifications, realtime);
      addTearDown(cubit.close);

      await cubit.start();
      expect(cubit.state, 1);

      notifications.emit(NotificationCreated(testNotification(id: 'n-9'), 5));
      expect(cubit.state, 5, reason: 'the count the event carries');
    });

    test('a failed read keeps the last count', () async {
      final cubit = NotificationBadgeCubit(notifications, realtime);
      addTearDown(cubit.close);
      await cubit.start();

      notifications.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      await cubit.refresh();

      expect(cubit.state, 1);
    });

    test('with the hub down it re-reads every 60 s', () {
      fakeAsync((async) {
        realtime.setStatus(RealtimeStatus.disconnected);
        final cubit = NotificationBadgeCubit(notifications, realtime);
        unawaited(cubit.start());
        async.flushMicrotasks();
        notifications.unreadCount = 4;

        async.elapse(const Duration(seconds: 60));

        expect(cubit.state, 4);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });
  });

  group('preferences', () {
    Future<NotificationPreferencesCubit> open() async {
      final cubit = NotificationPreferencesCubit(notifications);
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('loads; a failure is an error to retry', () async {
      final cubit = await open();
      expect(cubit.state.status, ViewStatus.content);
      expect(cubit.state.preferences, const NotificationPreferences());

      notifications.loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      final failed = await open();
      expect(failed.state.status, ViewStatus.error);
    });

    test('each switch is saved at once, with everything else as it was', () async {
      final cubit = await open();

      await cubit.setPushSavedSearches(false);
      await cubit.setPushChat(false);
      await cubit.setPushRatings(false);
      await cubit.setPushMatches(false);

      expect(notifications.saved, hasLength(4));
      expect(notifications.saved.first, const NotificationPreferences(pushSavedSearches: false));
      expect(cubit.state.preferences.pushMatches, isFalse);
      expect(cubit.state.preferences.quietStartMinute, 23 * 60);
      expect(cubit.state.feedback?.message, AppStrings.preferencesSaved);
    });

    test('quiet hours can run past midnight, in 30-minute steps, or be turned off', () async {
      final cubit = await open();

      await cubit.setQuietStart(22 * 60 + 30);
      await cubit.setQuietEnd(6 * 60 + 30);
      expect(cubit.state.preferences.quietStartMinute, 22 * 60 + 30);
      expect(cubit.state.preferences.quietEndMinute, 6 * 60 + 30);
      expect(cubit.state.preferences.spansMidnight, isTrue);

      await cubit.setQuietHoursEnabled(false);
      expect(notifications.saved.last.quietHoursEnabled, isFalse);
    });

    test('the same start and end are refused on the device, before the server', () async {
      final cubit = await open();

      await cubit.setQuietStart(8 * 60);

      expect(notifications.saved, isEmpty);
      expect(cubit.state.preferences.quietStartMinute, 23 * 60);
      expect(cubit.state.feedback?.message, AppStrings.quietHoursSame);
      expect(cubit.state.feedback?.code, NotificationErrorCodes.quietHoursSame);
    });

    test("a change the server refuses is undone, with the server's reason", () async {
      final cubit = await open();
      notifications.actionFailure = const ValidationFailure('x', code: NotificationErrorCodes.invalidQuietHours);

      await cubit.setPushChat(false);

      expect(cubit.state.preferences.pushChat, isTrue);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.quietHoursInvalid);
    });

    test('choosing what is already set saves nothing', () async {
      final cubit = await open();

      await cubit.setPushChat(true);

      expect(notifications.saved, isEmpty);
    });
  });
}
