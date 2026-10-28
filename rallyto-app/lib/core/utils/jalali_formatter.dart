import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import 'persian_digits.dart';

/// Jalali (Shamsi) dates and times with Persian digits, for display.
///
/// A [DateTime] is read as the device's wall clock (`toLocal()`): a UTC instant is shown in the phone's zone, and a
/// zone-less value (such as one from `tehranWallClock`) is shown as it is. To show an instant on Tehran's clock
/// whatever zone the phone is in, pass it through `tehranWallClock` first.
class JalaliFormatter {
  JalaliFormatter._();

  /// Weekday names, Saturday (shamsi_date's `weekDay` 1, the first day of the Iranian week) to Friday (7), each a
  /// single word. shamsi_date's own names spell some as two words («یک شنبه», «چهار شنبه»). «سه‌شنبه» carries a
  /// zero-width non-joiner (U+200C).
  static const List<String> weekdayNames = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

  /// Month names, Farvardin (1) to Esfand (12).
  static const List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// The Jalali date of [dateTime] on the device's wall clock.
  static Jalali toJalali(DateTime dateTime) => Jalali.fromDateTime(dateTime.toLocal());

  /// e.g. «جمعه ۱ آبان»
  static String formatDate(DateTime dateTime) {
    final j = toJalali(dateTime);
    return PersianDigits.toPersian('${weekdayNames[j.weekDay - 1]} ${j.day} ${monthNames[j.month - 1]}');
  }

  /// With the year, e.g. «جمعه ۱ آبان ۱۴۰۵»
  static String formatDateWithYear(DateTime dateTime) {
    final j = toJalali(dateTime);
    return PersianDigits.toPersian('${weekdayNames[j.weekDay - 1]} ${j.day} ${monthNames[j.month - 1]} ${j.year}');
  }

  /// Numeric, zero-padded, e.g. «۱۴۰۵/۰۸/۰۱»
  static String formatNumeric(DateTime dateTime) {
    final j = toJalali(dateTime);
    String two(int v) => v.toString().padLeft(2, '0');
    return PersianDigits.toPersian('${j.year.toString().padLeft(4, '0')}/${two(j.month)}/${two(j.day)}');
  }

  /// 24-hour time, e.g. «۱۴:۳۰»
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return PersianDigits.toPersian('$h:$m');
  }

  /// e.g. «جمعه ۱ آبان، ۱۴:۳۰»
  static String formatDateTime(DateTime dateTime) => '${formatDate(dateTime)}، ${formatTime(dateTime)}';

  /// Short day label for pickers, e.g. «۱ آبان»
  static String formatShortDate(DateTime dateTime) {
    final j = toJalali(dateTime);
    return PersianDigits.toPersian('${j.day} ${monthNames[j.month - 1]}');
  }

  /// Weekday name, e.g. «جمعه» — always a single word.
  static String weekday(DateTime dateTime) => weekdayNames[toJalali(dateTime).weekDay - 1];

  /// Month name, e.g. «آبان».
  static String monthName(DateTime dateTime) => monthNames[toJalali(dateTime).month - 1];
}
