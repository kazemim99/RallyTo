import '../../../core/utils/persian_digits.dart';

/// Sign-in phone numbers as the code screen shows them.
class PhoneMask {
  PhoneMask._();

  static const String _hidden = '•••';

  /// Unicode left-to-right isolate and its closing mark: the number keeps its order inside a right-to-left sentence.
  static final String _ltrIsolate = String.fromCharCode(0x2066);
  static final String _popIsolate = String.fromCharCode(0x2069);

  /// [phone] (as the server has it, «09121234567») with its middle hidden and Persian digits: «۰۹۱۲•••۴۵۶۷», isolated
  /// left to right. A number too short to hide anything is shown whole.
  static String mask(String phone) {
    final digits = phone.trim();
    final shown = digits.length < 9
        ? digits
        : '${digits.substring(0, 4)}$_hidden${digits.substring(digits.length - 4)}';
    return '$_ltrIsolate${PersianDigits.toPersian(shown)}$_popIsolate';
  }
}
