import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/date_formatter.dart';
import 'package:rallyto_app/core/utils/jalali_formatter.dart';

/// The long-form formats. AsanRezerve's copy keyed its weekday table by Dart's weekday (1 = Monday) but looked it up
/// with shamsi_date's (1 = Saturday), so a Friday read «یکشنبه»; this port must name every day correctly.
void main() {
  final today = DateTime(2026, 10, 23, 18, 30);

  test('2026-10-23 is «جمعه، ۱ آبان ۱۴۰۵»', () {
    expect(DateFormatter.formatFull(today), 'جمعه، ۱ آبان ۱۴۰۵');
    expect(DateFormatter.formatShort(today), '۱ آبان');
    expect(DateFormatter.formatNumeric(today), '۱۴۰۵/۰۸/۰۱');
    expect(DateFormatter.formatTime(today), '۱۸:۳۰');
    expect(DateFormatter.formatDateTime(today), 'جمعه، ۱ آبان ۱۴۰۵ - ۱۸:۳۰');
    expect(DateFormatter.getMonthName(today), 'آبان');
  });

  test('every weekday is named as JalaliFormatter names it', () {
    for (var i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      expect(DateFormatter.getWeekdayName(day), JalaliFormatter.weekday(day), reason: '$day');
    }
    expect(DateFormatter.getWeekdayName(today), 'جمعه');
  });

  test('the DateTime extensions read the same', () {
    expect(today.formatPersianFull(), DateFormatter.formatFull(today));
    expect(today.formatPersianShort(), '۱ آبان');
    expect(today.formatPersianNumeric(), '۱۴۰۵/۰۸/۰۱');
    expect(today.formatPersianTime(), '۱۸:۳۰');
    expect(today.formatPersianDateTime(), DateFormatter.formatDateTime(today));
    expect(today.getPersianWeekday(), 'جمعه');
    expect(today.getPersianMonth(), 'آبان');
    expect(today.toJalali().month, 8);
  });
}
