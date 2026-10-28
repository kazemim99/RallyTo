import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/notification.dart';

/// The notification inbox and push preferences. Nothing is cached; new entries arrive live on [created].
abstract class NotificationRepository {
  /// One page of the inbox, newest first; [page] starts at 1.
  Future<Either<Failure, NotificationPage>> getInbox({int page = 1, int pageSize = 20});

  Future<Either<Failure, int>> getUnreadCount();

  /// `NOTIFICATION_NOT_FOUND` for one that is gone (older than 90 days) or not this player's.
  Future<Either<Failure, Unit>> markRead(String id);

  Future<Either<Failure, Unit>> markAllRead();

  Future<Either<Failure, NotificationPreferences>> getPreferences();

  /// `INVALID_QUIET_HOURS` for times off the 30-minute grid, or the same start and end.
  Future<Either<Failure, NotificationPreferences>> updatePreferences(NotificationPreferences preferences);

  /// `notification.created` events from the realtime hub, while it is connected.
  Stream<NotificationCreated> get created;
}

/// This device's push token on the server.
abstract class DeviceTokenRepository {
  /// After sign-in and whenever FCM rotates the token. Registering it for another account moves it.
  Future<Either<Failure, Unit>> register(String token, {required String platform});

  /// Before sign-out, so this device stops receiving the account's pushes.
  Future<Either<Failure, Unit>> unregister(String token);
}
