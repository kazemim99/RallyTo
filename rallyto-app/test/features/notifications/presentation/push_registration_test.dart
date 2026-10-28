import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/push/push_service.dart';
import 'package:rallyto_app/features/notifications/presentation/push_registration.dart';

import '../../../helpers/fake_notifications.dart';
import '../../../helpers/memory_secure_storage.dart';

/// Device tokens and tapped pushes (spec notifications › Device token registration): registered after sign-in and on
/// rotation, unregistered before sign-out, and a tap opens its deep link. Push that cannot start changes nothing.
void main() {
  late AuthSessionCubit session;
  late FakePushService push;
  late FakeDeviceTokenRepository devices;
  late FakeNotificationRepository notifications;

  setUp(() {
    session = AuthSessionCubit(memoryTokenStorage(MemorySecureStorage(timers: false)));
    push = FakePushService();
    devices = FakeDeviceTokenRepository();
    notifications = FakeNotificationRepository();
  });

  tearDown(() => session.close());

  PushRegistration build([PushService? service]) {
    final registration = PushRegistration(service ?? push, devices, notifications, session);
    addTearDown(registration.dispose);
    return registration;
  }

  test('signed out, nothing is registered; signing in registers the token with its platform', () async {
    await build().start();
    expect(devices.registered, isEmpty);

    await session.signIn(testSession());
    await pumpEventQueue();

    expect(devices.registered, [('fcm-1', 'android')]);
  });

  test('a restored session registers at start, once even as the session is saved again', () async {
    await session.signIn(testSession());
    await build().start();
    await session.signIn(testSession(accessToken: 'access-2'));
    await pumpEventQueue();

    expect(devices.registered, [('fcm-1', 'android')]);
    expect(push.initializations, 1);
  });

  test('a rotated token is registered again', () async {
    await session.signIn(testSession());
    await build().start();

    push.rotate('fcm-2');
    await pumpEventQueue();

    expect(devices.registered.map((r) => r.$1), ['fcm-1', 'fcm-2']);
  });

  test('a failed registration is not remembered: the same token is tried again when FCM next hands it over', () async {
    devices.failure = const NetworkFailure('offline');
    await session.signIn(testSession());
    await build().start();
    devices.failure = null;

    push.rotate('fcm-1');
    await pumpEventQueue();

    expect(devices.registered.map((r) => r.$1), ['fcm-1', 'fcm-1']);
  });

  test('sign-out unregisters the token first, while the session is valid', () async {
    await session.signIn(testSession());
    await build().start();

    await session.signOut();

    expect(devices.unregistered, ['fcm-1']);
  });

  test('a new account on the same phone registers the token for itself', () async {
    await session.signIn(testSession());
    await build().start();
    await session.signOut();

    await session.signIn(testSession(accessToken: 'access-b'));
    await pumpEventQueue();

    expect(devices.registered.map((r) => r.$1), ['fcm-1', 'fcm-1']);
  });

  test('push that cannot start (no Firebase) registers nothing and signs out as usual', () async {
    push.available = false;
    await session.signIn(testSession());
    await build().start();

    await session.signOut();

    expect(devices.registered, isEmpty);
    expect(devices.unregistered, isEmpty);
  });

  test('the no-op push service is inert', () async {
    await session.signIn(testSession());
    final registration = build(const NoopPushService());
    await registration.start();

    expect(devices.registered, isEmpty);
  });

  test('a tapped push opens its deep link and marks its inbox entry read', () async {
    await session.signIn(testSession());
    final registration = build();
    final opened = <String>[];
    registration.deepLinks.listen(opened.add);
    await registration.start();

    push.tap({'notificationId': 'n-1', 'code': 'join-request.received', 'deepLink': '/matches/m-1'});
    push.tap({'notificationId': 'n-2', 'code': 'message.received', 'deepLink': '/chat/c-1'});
    push.tap({'notificationId': 'n-3', 'code': 'something.new', 'deepLink': ''});
    await pumpEventQueue();

    expect(opened, [Routes.matchPath('m-1'), Routes.chatPath('c-1'), Routes.notifications]);
    expect(notifications.calls, ['read:n-1', 'read:n-3'], reason: 'chat pushes have no inbox entry');
  });

  test('the push that launched the app is opened once the app listens', () async {
    push.initial = {'notificationId': 'n-1', 'code': 'saved-search.alert', 'deepLink': '/saved-searches/ss-1'};
    await session.signIn(testSession());
    final registration = build();
    await registration.start();

    final opened = <String>[];
    registration.deepLinks.listen(opened.add);
    await pumpEventQueue();

    expect(opened, [Routes.savedSearches]);
  });
}
