import '../../../core/constants/app_strings.dart';
import '../../../core/utils/jalali_date_text.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/persian_digits.dart';
import '../domain/availability_rules.dart';
import '../domain/entities/availability_window.dart';

/// Persian labels for availability values.
class AvailabilityLabels {
  AvailabilityLabels._();

  /// «شنبه» … «جمعه»: the Iranian week, Saturday first, as the date formatters spell it.
  static String weekday(Weekday day) => JalaliFormatter.weekdayNames[day.index];

  static String kind(AvailabilityKind kind) => switch (kind) {
    AvailabilityKind.recurring => AppStrings.kindRecurring,
    AvailabilityKind.oneOff => AppStrings.kindOneOff,
  };

  static String status(AvailabilityStatus status) => switch (status) {
    AvailabilityStatus.active => AppStrings.statusActive,
    AvailabilityStatus.paused => AppStrings.statusPaused,
    AvailabilityStatus.expired => AppStrings.statusExpired,
  };

  /// When: «شنبه، دوشنبه» for a recurring window, «۸ آبان ۱۴۰۵» for a one-off.
  static String when(AvailabilityWindow window) => switch (window.kind) {
    AvailabilityKind.recurring => window.weekdays.map(weekday).join('، '),
    AvailabilityKind.oneOff => JalaliDateText.display(window.date),
  };

  /// «۱۸:۰۰ تا ۲۰:۰۰».
  static String time(AvailabilityWindow window) =>
      AppStrings.timeRange(TimeOfDayText.displayText(window.startTime), TimeOfDayText.displayText(window.endTime));

  /// When the reminder's windows pause themselves unless confirmed: «بازهٔ زمانی شما ۳۰ آبان ۱۴۰۵ متوقف می‌شود.», for
  /// several the first of their days; the general hint when the server named no day.
  static String pauseNotice(List<AvailabilityWindow> windows) {
    final days = [for (final w in windows) ?JalaliDateText.tryParse(w.pausesOn)]..sort((a, b) => a.compareTo(b));
    if (days.isEmpty) return AppStrings.confirmStillAvailableHint;
    final first = JalaliDateText.long(days.first);
    return windows.length == 1 ? AppStrings.reconfirmPausesOn(first) : AppStrings.reconfirmPausesOnMany(first);
  }

  /// The message for one of the rules mirrored from the server ([AvailabilityErrorCodes]).
  static String rule(String code) => switch (code) {
    AvailabilityErrorCodes.windowTooShort => AppStrings.windowTooShort,
    AvailabilityErrorCodes.windowCrossesMidnight => AppStrings.windowCrossesMidnight,
    AvailabilityErrorCodes.invalidTimeStep => AppStrings.invalidTimeStep,
    AvailabilityErrorCodes.dateTooFar => AppStrings.dateTooFar,
    AvailabilityErrorCodes.windowInPast => AppStrings.windowInPast,
    AvailabilityErrorCodes.formatNotAllowed => AppStrings.formatNotAllowed,
    _ => AppStrings.invalidTime,
  };

  /// [minutes] of the day for a time selector: «۱۸:۳۰», and «۲۴:۰۰» for the end of the day.
  static String minute(int minutes) => PersianDigits.toPersian(TimeOfDayText.toApi(minutes));
}
