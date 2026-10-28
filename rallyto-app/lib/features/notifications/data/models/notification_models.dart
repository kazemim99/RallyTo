import 'package:json_annotation/json_annotation.dart';

import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/utils/server_time.dart';
import '../../../availability/domain/availability_rules.dart';
import '../../domain/entities/notification.dart';

part 'notification_models.g.dart';

/// `NotificationView`. The category arrives as a string.
@JsonSerializable(createToJson: false)
class NotificationViewModel {
  const NotificationViewModel({
    required this.id,
    required this.createdAt,
    this.code = '',
    this.category,
    this.title = '',
    this.body = '',
    this.deepLink,
    this.isRead = false,
  });

  factory NotificationViewModel.fromJson(Map<String, dynamic> json) => _$NotificationViewModelFromJson(json);

  final String id;
  final String code;
  final String? category;
  final String title;
  final String body;
  final String? deepLink;
  final String createdAt;
  final bool isRead;

  AppNotification toEntity() => AppNotification(
    id: id,
    code: code,
    category: NotificationCategory.tryParse(category) ?? NotificationCategory.account,
    title: title,
    body: body,
    deepLink: deepLink == null || deepLink!.trim().isEmpty ? null : deepLink,
    createdAt: parseServerInstant(createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    isRead: isRead,
  );
}

/// `PagedResult<NotificationView>`.
@JsonSerializable(createToJson: false)
class NotificationPageModel {
  const NotificationPageModel({this.items = const [], this.page = 1, this.pageSize = 20, this.totalCount = 0});

  factory NotificationPageModel.fromJson(Map<String, dynamic> json) => _$NotificationPageModelFromJson(json);

  final List<NotificationViewModel> items;
  final int page;
  final int pageSize;
  final int totalCount;

  NotificationPage toEntity() => NotificationPage(
    items: [for (final n in items) n.toEntity()],
    page: page,
    pageSize: pageSize,
    totalCount: totalCount,
  );
}

/// `UnreadCountView`.
@JsonSerializable(createToJson: false)
class UnreadCountModel {
  const UnreadCountModel({this.count = 0});

  factory UnreadCountModel.fromJson(Map<String, dynamic> json) => _$UnreadCountModelFromJson(json);

  final int count;
}

/// `PreferencesView`, and the `PUT` body: quiet hours as «HH:mm», Tehran time.
@JsonSerializable()
class PreferencesModel {
  const PreferencesModel({
    this.pushMatches = true,
    this.pushChat = true,
    this.pushRatings = true,
    this.pushSavedSearches = true,
    this.quietHoursEnabled = true,
    this.quietStart = '23:00',
    this.quietEnd = '08:00',
  });

  factory PreferencesModel.fromJson(Map<String, dynamic> json) => _$PreferencesModelFromJson(json);

  factory PreferencesModel.fromEntity(NotificationPreferences p) => PreferencesModel(
    pushMatches: p.pushMatches,
    pushChat: p.pushChat,
    pushRatings: p.pushRatings,
    pushSavedSearches: p.pushSavedSearches,
    quietHoursEnabled: p.quietHoursEnabled,
    quietStart: TimeOfDayText.toApi(p.quietStartMinute),
    quietEnd: TimeOfDayText.toApi(p.quietEndMinute),
  );

  final bool pushMatches;
  final bool pushChat;
  final bool pushRatings;
  final bool pushSavedSearches;
  final bool quietHoursEnabled;
  final String quietStart;
  final String quietEnd;

  Map<String, dynamic> toJson() => _$PreferencesModelToJson(this);

  NotificationPreferences toEntity() => NotificationPreferences(
    pushMatches: pushMatches,
    pushChat: pushChat,
    pushRatings: pushRatings,
    pushSavedSearches: pushSavedSearches,
    quietHoursEnabled: quietHoursEnabled,
    quietStartMinute: TimeOfDayText.tryParse(quietStart) ?? NotificationPreferences.defaultQuietStart,
    quietEndMinute: TimeOfDayText.tryParse(quietEnd) ?? NotificationPreferences.defaultQuietEnd,
  );
}

/// `DeviceTokenRequest`.
@JsonSerializable(createFactory: false)
class DeviceTokenRequestModel {
  const DeviceTokenRequestModel({required this.token, required this.platform});

  final String token;
  final String platform;

  Map<String, dynamic> toJson() => _$DeviceTokenRequestModelToJson(this);
}

/// `DeviceTokenRemoval`.
@JsonSerializable(createFactory: false)
class DeviceTokenRemovalModel {
  const DeviceTokenRemovalModel({required this.token});

  final String token;

  Map<String, dynamic> toJson() => _$DeviceTokenRemovalModelToJson(this);
}

/// The `notification.created` event in a realtime event, or null for any other event or a payload that cannot be
/// read.
NotificationCreated? notificationCreatedOf(RealtimeEvent event) {
  if (event.name != RealtimeEvents.notificationCreated) return null;
  try {
    final notification = event.payload['notification'];
    final unread = event.payload['unreadCount'];
    if (notification is! Map<String, dynamic>) return null;
    return NotificationCreated(
      NotificationViewModel.fromJson(notification).toEntity(),
      unread is num ? unread.toInt() : 0,
    );
  } catch (_) {
    return null;
  }
}
