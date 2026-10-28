import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/features/auth/presentation/phone_mask.dart';

/// The code screen shows the number it texted with the middle hidden, in Persian digits, kept left to right.
void main() {
  final ltrIsolate = String.fromCharCode(0x2066);
  final popIsolate = String.fromCharCode(0x2069);

  test('hides the middle of a mobile number and keeps its first and last four digits', () {
    expect(PhoneMask.mask('09121234567'), '$ltrIsolate۰۹۱۲•••۴۵۶۷$popIsolate');
  });

  test('isolates the number left to right, so it keeps its order inside a Persian sentence', () {
    final masked = PhoneMask.mask('09121234567');
    expect(masked.startsWith(ltrIsolate), isTrue);
    expect(masked.endsWith(popIsolate), isTrue);
  });

  test('a number too short to hide anything is shown whole', () {
    expect(PhoneMask.mask('0912345'), '$ltrIsolate۰۹۱۲۳۴۵$popIsolate');
  });
}
