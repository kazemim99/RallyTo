import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/persian_digits.dart';

/// Display is in Persian digits; what goes to the API is in Western digits. A player may type with a Persian or an
/// Arabic keyboard, and write a mobile number in any common form.
void main() {
  group('toPersian / fromInt', () {
    test('turns Western digits into Persian ones and keeps everything else', () {
      expect(PersianDigits.toPersian('1405/08/01'), '۱۴۰۵/۰۸/۰۱');
      expect(PersianDigits.toPersian('ساعت 14:30'), 'ساعت ۱۴:۳۰');
      expect(PersianDigits.toPersian('بدون عدد'), 'بدون عدد');
      expect(PersianDigits.fromInt(42), '۴۲');
      expect(PersianDigits.fromInt(0), '۰');
    });
  });

  group('normalize / digitsOnly', () {
    test('turns Persian and Arabic-Indic digits into Western ones', () {
      expect(PersianDigits.normalize('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(PersianDigits.normalize('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(PersianDigits.normalize('کد ۱۲a٣'), 'کد 12a3');
    });

    test('round-trips with toPersian', () {
      const western = '09121234567 14:30 1405/08/01';
      expect(PersianDigits.normalize(PersianDigits.toPersian(western)), western);
    });

    test('digitsOnly drops separators and keeps normalised digits', () {
      expect(PersianDigits.digitsOnly('۰۹۱۲ ۱۲۳-۴۵۶۷'), '09121234567');
      expect(PersianDigits.digitsOnly('+98 (912) 123 4567'), '989121234567');
    });
  });

  group('Iranian mobile numbers', () {
    const forms = [
      '09121234567',
      '9121234567',
      '+989121234567',
      '00989121234567',
      '+98 912 123 4567',
      '0912-123-4567',
      '۰۹۱۲۱۲۳۴۵۶۷',
      '٠٩١٢١٢٣٤٥٦٧',
      '۹۸۹۱۲۱۲۳۴۵۶۷',
    ];

    test('every common form becomes the canonical 09xxxxxxxxx', () {
      for (final input in forms) {
        expect(PersianDigits.canonicalMobile(input), '09121234567', reason: input);
        expect(PersianDigits.isValidIranianMobile(input), isTrue, reason: input);
      }
    });

    test('anything else is not a mobile number', () {
      for (final input in ['', 'abc', '0912123456', '091212345678', '08121234567', '02188776655', '+1 555 123 4567']) {
        expect(PersianDigits.isValidIranianMobile(input), isFalse, reason: input);
      }
    });
  });

  test('the input formatter normalises digits as they are typed and keeps the cursor', () {
    final formatter = PersianDigitsInputFormatter();
    const typed = TextEditingValue(text: '۰۹۱۲', selection: TextSelection.collapsed(offset: 4));

    final result = formatter.formatEditUpdate(TextEditingValue.empty, typed);

    expect(result.text, '0912');
    expect(result.selection, const TextSelection.collapsed(offset: 4));
    const plain = TextEditingValue(text: '0912');
    expect(identical(formatter.formatEditUpdate(TextEditingValue.empty, plain), plain), isTrue);
  });
}
