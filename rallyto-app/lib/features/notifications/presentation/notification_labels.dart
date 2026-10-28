import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/tehran_time.dart';
import '../../availability/domain/availability_rules.dart';
import '../domain/notification_rules.dart';

/// Persian labels for notifications, and the messages for the server's notification error codes.
class NotificationLabels {
  NotificationLabels._();

  /// When a notification came: the time today, else the day and time, on Tehran's clock.
  static String when(DateTime instant, {required DateTime now}) {
    final wall = tehranWallClock(instant);
    final time = JalaliFormatter.formatTime(wall);
    return tehranDate(instant) == tehranDate(now) ? time : '${JalaliFormatter.formatShortDate(wall)}، $time';
  }

  /// A quiet-hours boundary: «۲۳:۰۰».
  static String minute(int minute) => TimeOfDayText.display(minute);

  /// The player-facing message for a failed call: the app's words for a known code, else the server's.
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  /// The message for a rule checked on the device, by its code.
  static String rule(String code) => _messages[code] ?? AppStrings.genericError;

  static const Map<String, String> _messages = {
    NotificationErrorCodes.notificationNotFound: AppStrings.notificationNotFound,
    NotificationErrorCodes.invalidQuietHours: AppStrings.quietHoursInvalid,
    NotificationErrorCodes.quietHoursSame: AppStrings.quietHoursSame,
  };
}
