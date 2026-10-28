import 'package:equatable/equatable.dart';

/// What a notification is about; the push switches follow it. [account] is always delivered.
enum NotificationCategory {
  matches('Matches'),
  chat('Chat'),
  ratings('Ratings'),
  savedSearches('SavedSearches'),
  account('Account');

  const NotificationCategory(this.wire);

  final String wire;

  static NotificationCategory? tryParse(String? value) {
    for (final category in values) {
      if (category.wire.toLowerCase() == value?.toLowerCase()) return category;
    }
    return null;
  }
}

/// One inbox entry (`NotificationView`).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.code,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.deepLink,
    this.isRead = false,
  });

  final String id;

  /// The catalog code, e.g. `join-request.received`.
  final String code;
  final NotificationCategory category;
  final String title;
  final String body;

  /// The app path it opens, e.g. `/matches/{id}`; null when it opens nothing.
  final String? deepLink;
  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    code: code,
    category: category,
    title: title,
    body: body,
    createdAt: createdAt,
    deepLink: deepLink,
    isRead: isRead ?? this.isRead,
  );

  @override
  List<Object?> get props => [id, code, category, title, body, deepLink, createdAt, isRead];
}

/// One page of the inbox, newest first.
class NotificationPage extends Equatable {
  const NotificationPage({this.items = const [], this.page = 1, this.pageSize = 20, this.totalCount = 0});

  final List<AppNotification> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => page * pageSize < totalCount;

  @override
  List<Object?> get props => [items, page, pageSize, totalCount];
}

/// The realtime `notification.created` event: the new entry and the new unread count.
class NotificationCreated extends Equatable {
  const NotificationCreated(this.notification, this.unreadCount);

  final AppNotification notification;
  final int unreadCount;

  @override
  List<Object?> get props => [notification, unreadCount];
}

/// The push switches and quiet hours. Minutes are from midnight on Tehran's clock, in 30-minute steps.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.pushMatches = true,
    this.pushChat = true,
    this.pushRatings = true,
    this.pushSavedSearches = true,
    this.quietHoursEnabled = true,
    this.quietStartMinute = defaultQuietStart,
    this.quietEndMinute = defaultQuietEnd,
  });

  /// 23:00–08:00.
  static const int defaultQuietStart = 23 * 60;
  static const int defaultQuietEnd = 8 * 60;

  final bool pushMatches;
  final bool pushChat;
  final bool pushRatings;
  final bool pushSavedSearches;
  final bool quietHoursEnabled;
  final int quietStartMinute;
  final int quietEndMinute;

  /// The quiet window runs past midnight (23:00–08:00).
  bool get spansMidnight => quietStartMinute > quietEndMinute;

  NotificationPreferences copyWith({
    bool? pushMatches,
    bool? pushChat,
    bool? pushRatings,
    bool? pushSavedSearches,
    bool? quietHoursEnabled,
    int? quietStartMinute,
    int? quietEndMinute,
  }) => NotificationPreferences(
    pushMatches: pushMatches ?? this.pushMatches,
    pushChat: pushChat ?? this.pushChat,
    pushRatings: pushRatings ?? this.pushRatings,
    pushSavedSearches: pushSavedSearches ?? this.pushSavedSearches,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartMinute: quietStartMinute ?? this.quietStartMinute,
    quietEndMinute: quietEndMinute ?? this.quietEndMinute,
  );

  @override
  List<Object?> get props => [
    pushMatches,
    pushChat,
    pushRatings,
    pushSavedSearches,
    quietHoursEnabled,
    quietStartMinute,
    quietEndMinute,
  ];
}
