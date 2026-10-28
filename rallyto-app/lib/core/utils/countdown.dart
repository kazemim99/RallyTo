import 'package:injectable/injectable.dart';

import 'persian_digits.dart';

/// A one-second countdown, for "send again in …" timers. Injected, so tests drive the ticks themselves.
@injectable
class Countdown {
  const Countdown({@ignoreParam this.period = const Duration(seconds: 1)});

  /// The length of one "second": shorter only in tests.
  final Duration period;

  /// Seconds left after each second that passes: `seconds - 1`, …, `0`, then done. Empty when [seconds] is not
  /// positive.
  Stream<int> start(int seconds) {
    if (seconds <= 0) return const Stream<int>.empty();
    return Stream<int>.periodic(period, (elapsed) => seconds - elapsed - 1).take(seconds);
  }

  /// [seconds] as «m:ss» in Persian digits: 75 → «۱:۱۵», 9 → «۰:۰۹».
  static String label(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final rest = (safe % 60).toString().padLeft(2, '0');
    return PersianDigits.toPersian('$minutes:$rest');
  }
}
