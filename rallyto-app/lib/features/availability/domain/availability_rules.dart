import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../core/utils/persian_digits.dart';

/// The server's `error.code`s for availability.
class AvailabilityErrorCodes {
  AvailabilityErrorCodes._();

  static const String windowTooShort = 'WINDOW_TOO_SHORT';
  static const String windowCrossesMidnight = 'WINDOW_CROSSES_MIDNIGHT';
  static const String invalidTimeStep = 'INVALID_TIME_STEP';
  static const String invalidTime = 'INVALID_TIME';
  static const String venuesInDifferentCities = 'VENUES_IN_DIFFERENT_CITIES';
  static const String venueDoesNotOfferSport = 'VENUE_DOES_NOT_OFFER_SPORT';
  static const String formatNotAllowed = 'FORMAT_NOT_ALLOWED';
  static const String dateTooFar = 'DATE_TOO_FAR';
  static const String windowInPast = 'WINDOW_IN_PAST';
  static const String noSportProfile = 'NO_SPORT_PROFILE';
  static const String tooManyWindows = 'TOO_MANY_WINDOWS';
  static const String overlappingWindow = 'OVERLAPPING_WINDOW';
}

/// The server's rules for a window, mirrored so the player hears about them before sending. Each check answers with
/// the server's error code, or null when the rule holds.
class AvailabilityRules {
  AvailabilityRules._();

  /// Times are on a 30-minute grid.
  static const int step = 30;

  /// A window is at least an hour.
  static const int minimumLength = 60;

  /// «24:00»: allowed as an end, never as a start.
  static const int endOfDay = 24 * 60;

  /// A one-off date is today to this many days ahead.
  static const int maxDaysAhead = 60;

  static const int maxVenues = 3;
  static const int maxNoteLength = 200;

  /// At most this many active windows (409 TOO_MANY_WINDOWS beyond it).
  static const int maxActiveWindows = 10;

  /// The checks in the server's order: a real time, not crossing midnight, on the 30-minute grid, at least 60 minutes.
  static String? checkTime(int startMinute, int endMinute) {
    if (startMinute < 0 || startMinute >= endOfDay || endMinute <= 0 || endMinute > endOfDay) {
      return AvailabilityErrorCodes.invalidTime;
    }
    if (endMinute <= startMinute) return AvailabilityErrorCodes.windowCrossesMidnight;
    if (startMinute % step != 0 || endMinute % step != 0) return AvailabilityErrorCodes.invalidTimeStep;
    if (endMinute - startMinute < minimumLength) return AvailabilityErrorCodes.windowTooShort;
    return null;
  }

  /// A one-off window's date: from [today] to [maxDaysAhead] days on, and not already over when it is today
  /// ([nowMinute] is the minute of the day on Tehran's clock).
  static String? checkDate(Jalali date, int endMinute, {required Jalali today, required int nowMinute}) {
    if (date.compareTo(today) < 0) return AvailabilityErrorCodes.windowInPast;
    if (date.compareTo(today.addDays(maxDaysAhead)) > 0) return AvailabilityErrorCodes.dateTooFar;
    if (date.compareTo(today) == 0 && endMinute <= nowMinute) return AvailabilityErrorCodes.windowInPast;
    return null;
  }

  /// The start times offered: 00:00 to 23:30.
  static List<int> get startOptions => [for (var m = 0; m < endOfDay; m += step) m];

  /// The end times offered: 00:30 to 24:00.
  static List<int> get endOptions => [for (var m = step; m <= endOfDay; m += step) m];
}

/// «HH:mm» on Tehran's clock, as minutes from midnight.
class TimeOfDayText {
  TimeOfDayText._();

  /// «HH:mm» as the API takes it; 1440 is «24:00».
  static String toApi(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  /// Minutes from midnight, or null when [text] is not «H:mm» up to «24:00».
  static int? tryParse(String? text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(PersianDigits.normalize(text?.trim() ?? ''));
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    if (hours > 24 || minutes > 59 || (hours == 24 && minutes != 0)) return null;
    return hours * 60 + minutes;
  }

  /// For reading, in Persian digits: «۱۸:۳۰».
  static String display(int minute) => PersianDigits.toPersian(toApi(minute));

  /// [text] from the API in Persian digits.
  static String displayText(String text) => PersianDigits.toPersian(text);
}
