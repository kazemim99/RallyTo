import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import 'jalali_formatter.dart';
import 'persian_digits.dart';

/// Long-form Jalali formats (comma after the weekday, year included) and `DateTime` extensions over them. The names
/// come from [JalaliFormatter], so both formatters always spell a day or a month the same way.
///
/// Ported from AsanRezerve with one fix: its weekday table was keyed by Dart's `DateTime.weekday` (1 = Monday)
/// while it was looked up with shamsi_date's `weekDay` (1 = Saturday), so every weekday came out two days off.
class DateFormatter {
  DateFormatter._();

  /// The Jalali date of [dateTime] on the device's wall clock.
  static Jalali toJalali(DateTime dateTime) => JalaliFormatter.toJalali(dateTime);

  /// e.g. «جمعه، ۱ آبان ۱۴۰۵»
  static String formatFull(DateTime dateTime) {
    final j = toJalali(dateTime);
    return PersianDigits.toPersian(
      '${JalaliFormatter.weekdayNames[j.weekDay - 1]}، ${j.day} ${JalaliFormatter.monthNames[j.month - 1]} ${j.year}',
    );
  }

  /// e.g. «۱ آبان»
  static String formatShort(DateTime dateTime) => JalaliFormatter.formatShortDate(dateTime);

  /// e.g. «۱۴۰۵/۰۸/۰۱»
  static String formatNumeric(DateTime dateTime) => JalaliFormatter.formatNumeric(dateTime);

  /// e.g. «۱۴:۳۰»
  static String formatTime(DateTime dateTime) => JalaliFormatter.formatTime(dateTime);

  /// e.g. «جمعه، ۱ آبان ۱۴۰۵ - ۱۴:۳۰»
  static String formatDateTime(DateTime dateTime) => '${formatFull(dateTime)} - ${formatTime(dateTime)}';

  /// e.g. «جمعه»
  static String getWeekdayName(DateTime dateTime) => JalaliFormatter.weekday(dateTime);

  /// e.g. «آبان»
  static String getMonthName(DateTime dateTime) => JalaliFormatter.monthName(dateTime);
}

/// Jalali formatting straight from a [DateTime].
extension PersianDateTimeExtension on DateTime {
  Jalali toJalali() => DateFormatter.toJalali(this);

  String formatPersianFull() => DateFormatter.formatFull(this);

  String formatPersianShort() => DateFormatter.formatShort(this);

  String formatPersianNumeric() => DateFormatter.formatNumeric(this);

  String formatPersianTime() => DateFormatter.formatTime(this);

  String formatPersianDateTime() => DateFormatter.formatDateTime(this);

  String getPersianWeekday() => DateFormatter.getWeekdayName(this);

  String getPersianMonth() => DateFormatter.getMonthName(this);
}
