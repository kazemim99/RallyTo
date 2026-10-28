import 'package:flutter/services.dart';

/// Conversion between Western (0-9), Persian (۰-۹) and Arabic-Indic (٠-٩) digits, and Iranian mobile numbers.
///
/// Display uses Persian digits ([toPersian]); anything sent to the API uses Western digits ([normalize]). A player
/// may type with a Persian or an Arabic keyboard, so input is always normalised before it is validated or sent.
class PersianDigits {
  PersianDigits._();

  static const _persian = '۰۱۲۳۴۵۶۷۸۹';
  static const _arabic = '٠١٢٣٤٥٦٧٨٩';

  /// Western digits in [input] as Persian digits; everything else is kept. «1405/08/01» → «۱۴۰۵/۰۸/۰۱».
  static String toPersian(String input) {
    final buffer = StringBuffer();
    for (final unit in input.codeUnits) {
      buffer.write(unit >= 0x30 && unit <= 0x39 ? _persian[unit - 0x30] : String.fromCharCode(unit));
    }
    return buffer.toString();
  }

  /// [number] written with Persian digits. 42 → «۴۲».
  static String fromInt(int number) => toPersian(number.toString());

  /// Persian and Arabic-Indic digits in [input] as Western digits; everything else is kept.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final persian = _persian.indexOf(char);
      final arabic = _arabic.indexOf(char);
      if (persian >= 0) {
        buffer.write(persian);
      } else if (arabic >= 0) {
        buffer.write(arabic);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Only the digits of [input], normalised to Western digits.
  static String digitsOnly(String input) => normalize(input).replaceAll(RegExp(r'[^0-9]'), '');

  /// The canonical 11-digit form the API takes («09121234567»), from any common way of writing a mobile number:
  /// «۰۹۱۲ ۱۲۳ ۴۵۶۷», «9121234567», «+98 912 123 4567», «00989121234567». Anything that is not an Iranian mobile
  /// number comes back as its digits, and fails [isValidIranianMobile].
  static String canonicalMobile(String input) {
    var digits = digitsOnly(input);
    if (digits.length == 14 && digits.startsWith('0098')) {
      digits = digits.substring(4);
    } else if (digits.length == 12 && digits.startsWith('98')) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 && digits.startsWith('9')) digits = '0$digits';
    return digits;
  }

  /// Whether [input] is an Iranian mobile number in any of the forms [canonicalMobile] accepts.
  static bool isValidIranianMobile(String input) => RegExp(r'^09[0-9]{9}$').hasMatch(canonicalMobile(input));
}

/// Normalises Persian and Arabic-Indic digits to Western digits as they are typed.
class PersianDigitsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final normalized = PersianDigits.normalize(newValue.text);
    if (normalized == newValue.text) return newValue;
    // Every digit is one UTF-16 unit in all three scripts, so the selection keeps its offsets.
    return newValue.copyWith(text: normalized);
  }
}
