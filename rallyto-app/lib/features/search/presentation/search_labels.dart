import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/display_join.dart';
import '../../../core/utils/jalali_date_text.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/persian_digits.dart';
import '../../availability/domain/availability_rules.dart';
import '../../availability/domain/entities/availability_window.dart';
import '../../availability/presentation/availability_labels.dart';
import '../../catalog/domain/entities/sport.dart';
import '../../matches/presentation/match_labels.dart';
import '../domain/entities/search.dart';
import '../domain/search_rules.dart';

/// Persian labels for search filters and results, and the messages for the server's search error codes.
class SearchLabels {
  SearchLabels._();

  /// «همه روزها», «شنبه، دوشنبه» or «شنبه ۲ آبان ۱۴۰۵».
  static String when(SearchFilters filters) {
    final date = filters.date;
    if (date != null) {
      return PersianDigits.toPersian(
        '${JalaliFormatter.weekdayNames[date.weekDay - 1]} ${date.day} '
        '${JalaliFormatter.monthNames[date.month - 1]} ${date.year}',
      );
    }
    if (filters.weekdays.isEmpty) return AppStrings.anyDay;
    return [
      for (final day in Weekday.values)
        if (filters.weekdays.contains(day)) AvailabilityLabels.weekday(day),
    ].join('، ');
  }

  /// «تمام روز» or «۱۸:۰۰ تا ۲۲:۰۰».
  static String time(SearchFilters filters) => filters.isWholeDay
      ? AppStrings.wholeDay
      : AppStrings.timeRange(
          AvailabilityLabels.minute(filters.fromMinute),
          AvailabilityLabels.minute(filters.toMinute),
        );

  /// «متوسط رو به پایین تا پیشرفته».
  static String levels(SearchFilters filters, [Sport? sport]) =>
      MatchLabels.levelRange(filters.minLevel, filters.maxLevel, sport);

  /// The clubs: «همه باشگاه‌ها», their names, or «۲ باشگاه» when a name is missing (a club the server no longer names).
  static String venues(SearchFilters filters) {
    if (filters.venues.isEmpty) return AppStrings.allVenues;
    if (filters.venues.any((v) => v.name.isEmpty)) {
      return AppStrings.cityVenueCount(PersianDigits.fromInt(filters.venues.length));
    }
    return filters.venues.map((v) => v.name).join('، ');
  }

  /// «همپوشانی ۲۰:۰۰ تا ۲۲:۰۰».
  static String overlap(MatchingWindow window) =>
      AppStrings.overlap(TimeOfDayText.displayText(window.overlapStart), TimeOfDayText.displayText(window.overlapEnd));

  /// The window's days and hours: «شنبه، دوشنبه • ۱۸:۰۰ تا ۲۴:۰۰».
  static String window(MatchingWindow window) {
    final days = window.date != null
        ? JalaliDateText.display(window.date)
        : window.weekdays.map(AvailabilityLabels.weekday).join('، ');
    final time = AppStrings.timeRange(
      TimeOfDayText.displayText(window.startTime),
      TimeOfDayText.displayText(window.endTime),
    );
    return days.isEmpty ? time : [days, time].joinDisplay();
  }

  /// The player-facing message for a failed search call: the app's words for a known code, else the server's.
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  /// The message for a rule checked on the device, by the server's code.
  static String rule(String code) => _messages[code] ?? AppStrings.genericError;

  static const Map<String, String> _messages = {
    SearchErrorCodes.tooManyRequests: AppStrings.tooManyRequestsError,
    SearchErrorCodes.dateOutOfRange: AppStrings.searchDateOutOfRange,
    SearchErrorCodes.invalidTimeRange: AppStrings.invalidTimeRange,
    SearchErrorCodes.invalidDate: AppStrings.invalidDate,
    SearchErrorCodes.invalidTime: AppStrings.invalidTime,
    SearchErrorCodes.unknownSport: AppStrings.unknownSport,
    SearchErrorCodes.tooManySavedSearches: AppStrings.tooManySavedSearches,
    SearchErrorCodes.invalidSavedSearchName: AppStrings.invalidSavedSearchName,
    SearchErrorCodes.profileRequired: AppStrings.profileRequired,
  };
}
