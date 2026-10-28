import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/jalali_formatter.dart';
import 'package:rallyto_app/core/utils/tehran_time.dart';

/// Tehran is UTC+03:30 all year: Iran has kept no daylight saving since 2022. An instant is shown on Tehran's clock
/// whatever zone the phone is set to.
void main() {
  test('the offset is +03:30', () {
    expect(tehranOffset, const Duration(hours: 3, minutes: 30));
  });

  test('midnight in Tehran on 2026-10-23 is 20:30 UTC the day before, and reads 1405/08/01, a Friday', () {
    final wall = tehranWallClock(DateTime.utc(2026, 10, 22, 20, 30));

    expect([wall.year, wall.month, wall.day, wall.hour, wall.minute], [2026, 10, 23, 0, 0]);
    expect(wall.isUtc, isFalse, reason: 'a wall-clock value, formatted as it is');
    expect(JalaliFormatter.formatDateWithYear(wall), 'جمعه ۱ آبان ۱۴۰۵');
    expect(JalaliFormatter.formatTime(wall), '۰۰:۰۰');
  });

  test('no summer time: July is still +03:30', () {
    final wall = tehranWallClock(DateTime.utc(2026, 7, 15, 6, 15));
    expect([wall.hour, wall.minute], [9, 45]);
  });

  test('the same instant given in local time lands on the same Tehran clock', () {
    final instant = DateTime.utc(2026, 10, 23, 6, 15);
    expect(tehranWallClock(instant.toLocal()), tehranWallClock(instant));
  });

  test('fromTehranWallClock is the inverse: Tehran digits back to a UTC instant', () {
    final instant = fromTehranWallClock(DateTime(2026, 10, 23, 0, 0));

    expect(instant, DateTime.utc(2026, 10, 22, 20, 30));
    expect(instant.isUtc, isTrue);
    final roundTrip = DateTime.utc(2026, 10, 23, 14, 45, 30);
    expect(fromTehranWallClock(tehranWallClock(roundTrip)), roundTrip);
  });

  test("tehranDate is Tehran's calendar day: it turns at 20:30 UTC", () {
    expect(tehranDate(DateTime.utc(2026, 10, 22, 20, 29)), DateTime(2026, 10, 22));
    expect(tehranDate(DateTime.utc(2026, 10, 22, 20, 30)), DateTime(2026, 10, 23));
  });

  test('tehranNow reads the given instant on Tehran\'s clock', () {
    expect(tehranNow(now: DateTime.utc(2026, 10, 23, 8, 0)), DateTime(2026, 10, 23, 11, 30));
  });
}
