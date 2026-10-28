import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../core/push/push_service.dart';

/// [PushService] over Firebase Cloud Messaging. Firebase is configured from `android/app/google-services.json`,
/// supplied at build time and never committed; without it (or on a platform FCM does not support) [initialize]
/// answers false and every other member is inert.
@LazySingleton(as: PushService)
class FirebasePushService implements PushService {
  bool _ready = false;
  Future<bool>? _initializing;

  @override
  Future<bool> initialize() => _initializing ??= _initialize();

  Future<bool> _initialize() async {
    if (kIsWeb) return false;
    try {
      await Firebase.initializeApp();
      // Android 13+ and iOS ask the player; a refusal still leaves the token usable for later.
      await FirebaseMessaging.instance.requestPermission();
      _ready = true;
    } catch (_) {
      // Not configured (no google-services.json), no plugin (tests, desktop), or no Play services.
      _ready = false;
    }
    return _ready;
  }

  /// The FCM registration token. firebase_messaging 17 deprecates it for `register()`/`onRegistered`, which yield a
  /// Firebase Installation ID for direct send; the server's gateway (FirebaseAdmin `Message.Token`) sends to
  /// registration tokens, so the token API stays until the server moves.
  @override
  Future<String?> getToken() async {
    if (!_ready) return null;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  @override
  String get platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// See [getToken] for why the deprecated stream is used.
  @override
  Stream<String> get tokenRefreshes {
    if (!_ready) return const Stream.empty();
    // ignore: deprecated_member_use
    return FirebaseMessaging.instance.onTokenRefresh;
  }

  @override
  Stream<Map<String, String>> get openedNotifications =>
      _ready ? FirebaseMessaging.onMessageOpenedApp.map((m) => _data(m.data)) : const Stream.empty();

  @override
  Future<Map<String, String>?> takeInitialNotification() async {
    if (!_ready) return null;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : _data(message.data);
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _data(Map<String, dynamic> data) => {
    for (final entry in data.entries) entry.key: '${entry.value ?? ''}',
  };
}
