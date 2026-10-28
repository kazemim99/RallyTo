/// The device's push channel (FCM), behind an interface so tests and builds without Firebase use [NoopPushService].
///
/// Nothing here throws: a device or build where push is unavailable answers false, null or an empty stream.
abstract class PushService {
  /// Sets push up (Firebase, the notification permission). False when push is unavailable on this build or device;
  /// the app then runs without it.
  Future<bool> initialize();

  /// The device's push token, or null when push is unavailable.
  Future<String?> getToken();

  /// The `platform` sent with the token: `android` or `ios`.
  String get platform;

  /// Every new token, when FCM rotates it.
  Stream<String> get tokenRefreshes;

  /// The data of every push the player taps while the app runs (`{notificationId, code, deepLink}`).
  Stream<Map<String, String>> get openedNotifications;

  /// The data of the push the player tapped to launch the app, once; null when it was not launched from one.
  Future<Map<String, String>?> takeInitialNotification();
}

/// Push turned off: for tests and for builds without `google-services.json`.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  String get platform => 'android';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<Map<String, String>> get openedNotifications => const Stream.empty();

  @override
  Future<Map<String, String>?> takeInitialNotification() async => null;
}
