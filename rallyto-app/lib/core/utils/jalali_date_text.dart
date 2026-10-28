import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import 'jalali_formatter.dart';
import 'persian_digits.dart';
import 'tehran_time.dart';

/// Jalali calendar dates as the API writes them: «1375/05/10», ASCII digits, zero-padded. The API takes Persian
/// digits too, but the app always sends ASCII.
class JalaliDateText {
  JalaliDateText._();

  static final RegExp _pattern = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$');

  /// [date] as the API takes it: «1375/05/10».
  static String toApi(Jalali date) => '${date.year.toString().padLeft(4, '0')}/${_two(date.month)}/${_two(date.day)}';

  /// The date in [text] («1375/05/10», in any digits), or null when it is not a real Jalali date.
  static Jalali? tryParse(String? text) {
    final match = _pattern.firstMatch(PersianDigits.normalize(text?.trim() ?? ''));
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1) return null;
    try {
      final date = Jalali(year, month, day);
      return date.day == day ? date : null;
    } catch (_) {
      return null;
    }
  }

  /// For reading: «۱۰ مرداد ۱۳۷۵».
  static String long(Jalali date) =>
      PersianDigits.toPersian('${date.day} ${JalaliFormatter.monthNames[date.month - 1]} ${date.year}');

  /// [text] from the API, for reading («۱۰ مرداد ۱۳۷۵»), or as it came (in Persian digits) when it cannot be read.
  static String display(String? text) {
    final date = tryParse(text);
    if (date != null) return long(date);
    return PersianDigits.toPersian(text ?? '');
  }

  /// A year and month from the API («1405/08»), for reading: «آبان ۱۴۰۵».
  static String yearMonth(String? text) {
    final match = RegExp(r'^(\d{4})/(\d{1,2})$').firstMatch(PersianDigits.normalize(text?.trim() ?? ''));
    final month = match == null ? 0 : int.parse(match.group(2)!);
    if (match == null || month < 1 || month > 12) return PersianDigits.toPersian(text ?? '');
    return PersianDigits.toPersian('${JalaliFormatter.monthNames[month - 1]} ${match.group(1)}');
  }

  /// Today on Tehran's calendar, the day the API means by «today». [now] defaults to the current time.
  static Jalali today({DateTime? now}) => Jalali.fromDateTime(tehranDate(now ?? DateTime.now()));

  /// Whole years from [birth] to [on]: the age a player born on [birth] is on [on].
  static int ageOn(Jalali birth, Jalali on) {
    var age = on.year - birth.year;
    if (on.month < birth.month || (on.month == birth.month && on.day < birth.day)) age--;
    return age;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
