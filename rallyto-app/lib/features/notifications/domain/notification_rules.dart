import 'entities/notification.dart';

/// The server's notification error codes (`error.code`).
class NotificationErrorCodes {
  NotificationErrorCodes._();

  static const String notificationNotFound = 'NOTIFICATION_NOT_FOUND';
  static const String invalidQuietHours = 'INVALID_QUIET_HOURS';

  /// Not the server's word for it, but its rule: quiet hours that start and end at the same time.
  static const String quietHoursSame = 'QUIET_HOURS_SAME';
}

/// Quiet hours as the server takes them (spec notifications › Quiet hours).
class QuietHoursRules {
  QuietHoursRules._();

  static const int step = 30;

  /// Every time a quiet window can start or end: 00:00 to 23:30 in 30-minute steps.
  static final List<int> options = [for (var m = 0; m < 24 * 60; m += step) m];

  /// The code for what is wrong with [preferences]' quiet hours, or null.
  static String? check(NotificationPreferences preferences) {
    final start = preferences.quietStartMinute;
    final end = preferences.quietEndMinute;
    if (!options.contains(start) || !options.contains(end)) return NotificationErrorCodes.invalidQuietHours;
    if (preferences.quietHoursEnabled && start == end) return NotificationErrorCodes.quietHoursSame;
    return null;
  }

  /// Whether [minute] (Tehran's clock) falls in the quiet window, which may run past midnight.
  static bool isQuiet(NotificationPreferences preferences, int minute) {
    if (!preferences.quietHoursEnabled) return false;
    final start = preferences.quietStartMinute;
    final end = preferences.quietEndMinute;
    return start < end ? minute >= start && minute < end : minute >= start || minute < end;
  }
}
