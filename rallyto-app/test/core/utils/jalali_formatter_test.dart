import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/jalali_formatter.dart';

/// Today, 2026-10-23, is Jalali 1405/08/01 (۱ آبان ۱۴۰۵), a Friday (جمعه).
void main() {
  final today = DateTime(2026, 10, 23, 9, 5);

  group('2026-10-23', () {
    test('is 1405/08/01, a Friday', () {
      final j = JalaliFormatter.toJalali(today);
      expect([j.year, j.month, j.day], [1405, 8, 1]);
      expect(j.weekDay, 7, reason: 'shamsi_date counts Saturday as 1, so Friday is 7');
    });

    test('formats in Persian digits', () {
      expect(JalaliFormatter.formatNumeric(today), '۱۴۰۵/۰۸/۰۱');
      expect(JalaliFormatter.formatDate(today), 'جمعه ۱ آبان');
      expect(JalaliFormatter.formatDateWithYear(today), 'جمعه ۱ آبان ۱۴۰۵');
      expect(JalaliFormatter.formatShortDate(today), '۱ آبان');
      expect(JalaliFormatter.formatTime(today), '۰۹:۰۵');
      expect(JalaliFormatter.formatDateTime(today), 'جمعه ۱ آبان، ۰۹:۰۵');
      expect(JalaliFormatter.weekday(today), 'جمعه');
      expect(JalaliFormatter.monthName(today), 'آبان');
    });
  });

  test('the week runs Saturday to Friday, each name a single word', () {
    final saturday = DateTime(2026, 10, 24);
    final names = [for (var i = 0; i < 7; i++) JalaliFormatter.weekday(saturday.add(Duration(days: i)))];

    expect(names, ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه']);
    expect(names.where((n) => n.contains(' ')), isEmpty);
  });

  test('the year turns at Nowruz: 2026-03-21 is 1405/01/01, the day before is 1404/12/29', () {
    expect(JalaliFormatter.formatNumeric(DateTime(2026, 3, 21)), '۱۴۰۵/۰۱/۰۱');
    expect(JalaliFormatter.formatNumeric(DateTime(2026, 3, 20)), '۱۴۰۴/۱۲/۲۹');
    expect(JalaliFormatter.formatDateWithYear(DateTime(2026, 3, 21)), 'شنبه ۱ فروردین ۱۴۰۵');
  });

  test('every month has its name', () {
    final firsts = [
      DateTime(2026, 3, 21), DateTime(2026, 4, 21), DateTime(2026, 5, 22), DateTime(2026, 6, 22), //
      DateTime(2026, 7, 23), DateTime(2026, 8, 23), DateTime(2026, 9, 23), DateTime(2026, 10, 23),
      DateTime(2026, 11, 22), DateTime(2026, 12, 22), DateTime(2027, 1, 21), DateTime(2027, 2, 20),
    ];
    expect(firsts.map(JalaliFormatter.monthName), JalaliFormatter.monthNames);
    expect(firsts.map((d) => JalaliFormatter.toJalali(d).day), everyElement(1));
  });
}
