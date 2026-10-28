import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/notification_models.dart';

part 'notification_api.g.dart';

/// The notification inbox, preferences and device-token endpoints, on the `apiDio` client.
@RestApi()
abstract class NotificationApi {
  factory NotificationApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _NotificationApi;

  @GET(ApiPaths.notifications)
  Future<ApiResponse<NotificationPageModel>> inbox(@Query('page') int page, @Query('pageSize') int pageSize);

  @GET(ApiPaths.notificationsUnreadCount)
  Future<ApiResponse<UnreadCountModel>> unreadCount();

  /// 204, no body.
  @POST(ApiPaths.notificationRead)
  Future<void> markRead(@Path('id') String id);

  /// 204, no body.
  @POST(ApiPaths.notificationsReadAll)
  Future<void> markAllRead();

  @GET(ApiPaths.notificationPreferences)
  Future<ApiResponse<PreferencesModel>> preferences();

  @PUT(ApiPaths.notificationPreferences)
  Future<ApiResponse<PreferencesModel>> updatePreferences(@Body() PreferencesModel body);

  /// 204, no body.
  @POST(ApiPaths.deviceTokens)
  Future<void> registerDeviceToken(@Body() DeviceTokenRequestModel body);

  /// 204, no body.
  @DELETE(ApiPaths.deviceTokens)
  Future<void> unregisterDeviceToken(@Body() DeviceTokenRemovalModel body);
}

/// Registers [NotificationApi] with get_it.
@module
abstract class NotificationModule {
  @lazySingleton
  NotificationApi notificationApi(@Named(DioNames.api) Dio dio) => NotificationApi(dio);
}
