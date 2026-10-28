import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/countdown.dart';

void main() {
  test('counts down one value per second, ending at 0, then stops', () async {
    final ticks = await const Countdown(period: Duration(milliseconds: 5)).start(3).toList();

    expect(ticks, [2, 1, 0]);
  });

  test('a wait of 0 or less is over at once', () async {
    expect(await const Countdown().start(0).toList(), isEmpty);
    expect(await const Countdown().start(-5).toList(), isEmpty);
  });

  test('labels as m:ss in Persian digits', () {
    expect(Countdown.label(75), '۱:۱۵');
    expect(Countdown.label(60), '۱:۰۰');
    expect(Countdown.label(9), '۰:۰۹');
    expect(Countdown.label(0), '۰:۰۰');
    expect(Countdown.label(-1), '۰:۰۰');
  });
}
