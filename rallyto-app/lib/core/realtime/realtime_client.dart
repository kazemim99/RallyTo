import 'package:equatable/equatable.dart';

/// Whether the realtime hub is live. Anything but [connected] means events may be missed, so screens poll instead.
enum RealtimeStatus { disconnected, connecting, connected }

/// One server event from the hub: its name and its camelCase JSON payload (enums as strings).
class RealtimeEvent extends Equatable {
  const RealtimeEvent(this.name, this.payload);

  final String name;
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [name, payload];
}

/// The event names on `/hubs/realtime` (design D8). Clients only listen; every write goes through the REST API.
class RealtimeEvents {
  RealtimeEvents._();

  /// A `MessageView`, to the sender's other devices and to every current member.
  static const String messageReceived = 'message.received';

  /// `{conversationId, messageId}`.
  static const String messageDeleted = 'message.deleted';

  /// `{conversationId, userId, upToMessageId}`, to the other members.
  static const String conversationRead = 'conversation.read';

  /// `{notification: NotificationView, unreadCount}`.
  static const String notificationCreated = 'notification.created';

  static const List<String> all = [messageReceived, messageDeleted, conversationRead, notificationCreated];
}

/// The app's one connection to the realtime hub, shared by chat and notifications. Started while the player is signed
/// in and the app is in the foreground ([start]), torn down otherwise ([stop]). It reconnects on its own with backoff;
/// screens that need fresh data poll while [status] is not [RealtimeStatus.connected].
abstract class RealtimeClient {
  RealtimeStatus get status;

  /// Every change of [status].
  Stream<RealtimeStatus> get statusChanges;

  /// Server events, as they arrive.
  Stream<RealtimeEvent> get events;

  /// Connects, and keeps reconnecting until [stop]. Calling it while started does nothing.
  Future<void> start();

  /// Disconnects and stops reconnecting.
  Future<void> stop();
}

/// How long to wait before reconnect attempt [attempt] (0 for the first): 0, 2, 5, 10, 30 seconds, then every minute.
class RealtimeBackoff {
  RealtimeBackoff._();

  static const List<Duration> _delays = [
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  static const Duration max = Duration(minutes: 1);

  static Duration delayFor(int attempt) => attempt < 0
      ? Duration.zero
      : attempt < _delays.length
      ? _delays[attempt]
      : max;
}
