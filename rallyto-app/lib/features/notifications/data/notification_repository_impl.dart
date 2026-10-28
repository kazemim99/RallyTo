import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/errors/failures.dart';
import '../../../core/realtime/realtime_client.dart';
import '../domain/entities/notification.dart';
import '../domain/notification_repository.dart';
import 'models/notification_models.dart';
import 'notification_api.dart';

/// [NotificationRepository] over [NotificationApi], with live entries from the shared [RealtimeClient].
@LazySingleton(as: NotificationRepository)
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._api, this._realtime);

  final NotificationApi _api;
  final RealtimeClient _realtime;

  @override
  Future<Either<Failure, NotificationPage>> getInbox({int page = 1, int pageSize = 20}) async {
    final result = await safeApiCall(() => _api.inbox(page, pageSize));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    final result = await safeApiCall(_api.unreadCount);
    return result.map((model) => model.count);
  }

  @override
  Future<Either<Failure, Unit>> markRead(String id) => safeNoContentCall(() => _api.markRead(id));

  @override
  Future<Either<Failure, Unit>> markAllRead() => safeNoContentCall(_api.markAllRead);

  @override
  Future<Either<Failure, NotificationPreferences>> getPreferences() async {
    final result = await safeApiCall(_api.preferences);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, NotificationPreferences>> updatePreferences(NotificationPreferences preferences) async {
    final result = await safeApiCall(() => _api.updatePreferences(PreferencesModel.fromEntity(preferences)));
    return result.map((model) => model.toEntity());
  }

  @override
  Stream<NotificationCreated> get created =>
      _realtime.events.map(notificationCreatedOf).where((e) => e != null).cast<NotificationCreated>();
}

/// [DeviceTokenRepository] over [NotificationApi].
@LazySingleton(as: DeviceTokenRepository)
class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  DeviceTokenRepositoryImpl(this._api);

  final NotificationApi _api;

  @override
  Future<Either<Failure, Unit>> register(String token, {required String platform}) =>
      safeNoContentCall(() => _api.registerDeviceToken(DeviceTokenRequestModel(token: token, platform: platform)));

  @override
  Future<Either<Failure, Unit>> unregister(String token) =>
      safeNoContentCall(() => _api.unregisterDeviceToken(DeviceTokenRemovalModel(token: token)));
}
