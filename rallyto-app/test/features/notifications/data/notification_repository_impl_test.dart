import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/features/notifications/data/notification_api.dart';
import 'package:rallyto_app/features/notifications/data/notification_repository_impl.dart';
import 'package:rallyto_app/features/notifications/domain/entities/notification.dart';

import '../../../helpers/fake_realtime.dart';
import '../../../helpers/fake_server.dart';

/// Notifications over the real client stack, against the backend's contract (NotificationsController,
/// DeviceTokensController, NotificationView, PagedResult, PreferencesView; NotificationsTests).
void main() {
  late FakeServer server;
  late FakeRealtimeClient realtime;
  late NotificationRepositoryImpl repository;
  late DeviceTokenRepositoryImpl devices;

  setUp(() {
    server = FakeServer();
    realtime = FakeRealtimeClient();
    final api = NotificationApi(server.dio());
    repository = NotificationRepositoryImpl(api, realtime);
    devices = DeviceTokenRepositoryImpl(api);
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  test('the inbox is paged with page= and pageSize=; categories arrive as strings', () async {
    server.routes['GET /api/v1/notifications'] = (_) => okBody({
      'items': [_notificationJson],
      'page': 2,
      'pageSize': 20,
      'totalCount': 41,
      'totalPages': 3,
    });

    final page = valueOf(await repository.getInbox(page: 2));

    expect(server.requests.single.queryParameters, {'page': 2, 'pageSize': 20});
    expect(page.page, 2);
    expect(page.totalCount, 41);
    expect(page.hasMore, isTrue);
    final item = page.items.single;
    expect(item.id, 'n-1');
    expect(item.category, NotificationCategory.matches);
    expect(item.title, 'درخواست پیوستن');
    expect(item.deepLink, '/matches/m-1');
    expect(item.createdAt, DateTime.utc(2026, 10, 23, 7, 50));
    expect(item.isRead, isFalse);
  });

  test('the unread count; marking one or all read are 204s', () async {
    server.routes['GET /api/v1/notifications/unread-count'] = (_) => okBody({'count': 3});
    server.routes['POST /api/v1/notifications/n-1/read'] = (_) => noContentBody();
    server.routes['POST /api/v1/notifications/read-all'] = (_) => noContentBody();

    expect(valueOf(await repository.getUnreadCount()), 3);
    expect(valueOf(await repository.markRead('n-1')), unit);
    expect(valueOf(await repository.markAllRead()), unit);
  });

  test('a notification that is gone is NOTIFICATION_NOT_FOUND', () async {
    server.routes['POST /api/v1/notifications/n-9/read'] = (_) =>
        errorBody(404, 'NOTIFICATION_NOT_FOUND', 'اعلان پیدا نشد.');

    expect(failureOf(await repository.markRead('n-9')).code, 'NOTIFICATION_NOT_FOUND');
  });

  test('preferences read and write quiet hours as «HH:mm»', () async {
    server.routes['GET /api/v1/notifications/preferences'] = (_) => okBody(_preferencesJson);
    server.routes['PUT /api/v1/notifications/preferences'] = (options) => okBody(options.data);

    final read = valueOf(await repository.getPreferences());
    expect(read, const NotificationPreferences());
    expect(read.quietStartMinute, 23 * 60);
    expect(read.quietEndMinute, 8 * 60);
    expect(read.spansMidnight, isTrue);

    final saved = valueOf(
      await repository.updatePreferences(
        read.copyWith(pushSavedSearches: false, quietStartMinute: 22 * 60 + 30, quietEndMinute: 7 * 60),
      ),
    );

    expect(server.lastJson, {
      'pushMatches': true,
      'pushChat': true,
      'pushRatings': true,
      'pushSavedSearches': false,
      'quietHoursEnabled': true,
      'quietStart': '22:30',
      'quietEnd': '07:00',
    });
    expect(saved.quietStartMinute, 22 * 60 + 30);
  });

  test('quiet hours off the grid are INVALID_QUIET_HOURS', () async {
    server.routes['PUT /api/v1/notifications/preferences'] = (_) =>
        errorBody(400, 'INVALID_QUIET_HOURS', 'ساعت سکوت باید مضرب ۳۰ دقیقه باشد.');

    final failure = failureOf(await repository.updatePreferences(const NotificationPreferences()));

    expect(failure.code, 'INVALID_QUIET_HOURS');
  });

  test('device tokens: POST {token, platform} after sign-in, DELETE {token} before sign-out', () async {
    server.routes['POST /api/v1/device-tokens'] = (_) => noContentBody();
    server.routes['DELETE /api/v1/device-tokens'] = (_) => noContentBody();

    expect(valueOf(await devices.register('fcm-1', platform: 'android')), unit);
    expect(server.lastJson, {'token': 'fcm-1', 'platform': 'android'});
    expect(valueOf(await devices.unregister('fcm-1')), unit);
    expect(server.lastJson, {'token': 'fcm-1'});
    expect(server.calls, ['POST /api/v1/device-tokens', 'DELETE /api/v1/device-tokens']);
  });

  test("the hub's notification.created carries the entry and the new unread count", () async {
    final events = <NotificationCreated>[];
    final subscription = repository.created.listen(events.add);
    addTearDown(subscription.cancel);

    realtime
      ..emit(RealtimeEvents.notificationCreated, {'notification': _notificationJson, 'unreadCount': 4})
      ..emit(RealtimeEvents.messageDeleted, {'conversationId': 'c-1', 'messageId': 'm-1'})
      ..emit(RealtimeEvents.notificationCreated, {'unreadCount': 5});
    await pumpEventQueue();

    expect(events, hasLength(1));
    expect(events.single.notification.id, 'n-1');
    expect(events.single.unreadCount, 4);
  });
}

const Map<String, Object?> _notificationJson = {
  'id': 'n-1',
  'code': 'join-request.received',
  'category': 'Matches',
  'title': 'درخواست پیوستن',
  'body': 'رضا می‌خواهد به بازی شما بپیوندد.',
  'deepLink': '/matches/m-1',
  'createdAt': '2026-10-23T07:50:00Z',
  'isRead': false,
};

const Map<String, Object?> _preferencesJson = {
  'pushMatches': true,
  'pushChat': true,
  'pushRatings': true,
  'pushSavedSearches': true,
  'quietHoursEnabled': true,
  'quietStart': '23:00',
  'quietEnd': '08:00',
};
