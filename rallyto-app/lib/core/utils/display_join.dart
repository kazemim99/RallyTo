/// Joining short display parts into one line: «تنیس • انفرادی», «شنبه ۲ آبان، ۱۹:۰۰».
///
/// The design separates parts with a dot, but in Persian a dot beside a digit reads as a zero: «بازیکن‌ها · ۱»
/// looks like «۱۰». So the bullet is used only between words. Where a neighbouring part starts or ends with a digit
/// the Persian comma takes its place, as the design itself writes dates («شنبه ۱۴۰۵/۰۸/۰۲، ۱۹:۰۰»). The right-to-left
/// marks keep the bullet in place between right-to-left parts, whatever the bidi algorithm does with the neutrals.
class DisplayJoin {
  DisplayJoin._();

  static const String bullet = ' ‏•‏ ';
  static const String comma = '، ';

  static final RegExp _digit = RegExp(r'[0-9۰-۹٠-٩]');

  /// [parts] without empty ones, each pair separated by [bullet], or by [comma] when a digit touches the separator.
  static String join(Iterable<String> parts) {
    final kept = parts.where((part) => part.trim().isNotEmpty).map((part) => part.trim()).toList();
    final buffer = StringBuffer();
    for (var i = 0; i < kept.length; i++) {
      if (i > 0) buffer.write(_touchesDigit(kept[i - 1], kept[i]) ? comma : bullet);
      buffer.write(kept[i]);
    }
    return buffer.toString();
  }

  static bool _touchesDigit(String before, String after) =>
      _digit.hasMatch(before[before.length - 1]) || _digit.hasMatch(after[0]);
}

extension DisplayJoinParts on Iterable<String> {
  /// See [DisplayJoin.join].
  String joinDisplay() => DisplayJoin.join(this);
}
