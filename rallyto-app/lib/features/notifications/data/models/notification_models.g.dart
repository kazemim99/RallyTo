// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationViewModel _$NotificationViewModelFromJson(Map<String, dynamic> json) => NotificationViewModel(
  id: json['id'] as String,
  createdAt: json['createdAt'] as String,
  code: json['code'] as String? ?? '',
  category: json['category'] as String?,
  title: json['title'] as String? ?? '',
  body: json['body'] as String? ?? '',
  deepLink: json['deepLink'] as String?,
  isRead: json['isRead'] as bool? ?? false,
);

NotificationPageModel _$NotificationPageModelFromJson(Map<String, dynamic> json) => NotificationPageModel(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => NotificationViewModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
  totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
);

UnreadCountModel _$UnreadCountModelFromJson(Map<String, dynamic> json) =>
    UnreadCountModel(count: (json['count'] as num?)?.toInt() ?? 0);

PreferencesModel _$PreferencesModelFromJson(Map<String, dynamic> json) => PreferencesModel(
  pushMatches: json['pushMatches'] as bool? ?? true,
  pushChat: json['pushChat'] as bool? ?? true,
  pushRatings: json['pushRatings'] as bool? ?? true,
  pushSavedSearches: json['pushSavedSearches'] as bool? ?? true,
  quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? true,
  quietStart: json['quietStart'] as String? ?? '23:00',
  quietEnd: json['quietEnd'] as String? ?? '08:00',
);

Map<String, dynamic> _$PreferencesModelToJson(PreferencesModel instance) => <String, dynamic>{
  'pushMatches': instance.pushMatches,
  'pushChat': instance.pushChat,
  'pushRatings': instance.pushRatings,
  'pushSavedSearches': instance.pushSavedSearches,
  'quietHoursEnabled': instance.quietHoursEnabled,
  'quietStart': instance.quietStart,
  'quietEnd': instance.quietEnd,
};

Map<String, dynamic> _$DeviceTokenRequestModelToJson(DeviceTokenRequestModel instance) => <String, dynamic>{
  'token': instance.token,
  'platform': instance.platform,
};

Map<String, dynamic> _$DeviceTokenRemovalModelToJson(DeviceTokenRemovalModel instance) => <String, dynamic>{
  'token': instance.token,
};
