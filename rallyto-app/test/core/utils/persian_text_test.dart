import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/persian_text.dart';

/// Search text typed on an Arabic keyboard, with half-spaces or with Persian digits still matches the data.
void main() {
  test('Arabic yeh and kaf become Persian yeh and kaf', () {
    expect(PersianText.normalize('كرج'), 'کرج');
    expect(PersianText.normalize('شهريار'), 'شهریار');
    expect(PersianText.normalize('موسى'), 'موسی');
  });

  test('half-spaces, repeated spaces and digits are evened out', () {
    expect(PersianText.normalize('  رباط\u200Cکریم  '), 'رباط کریم');
    expect(PersianText.normalize('منطقه   ۲۲'), 'منطقه 22');
  });

  test('matches compares normalised text, and an empty query matches everything', () {
    expect(PersianText.matches('کرج', 'كر'), isTrue);
    expect(PersianText.matches('رباط‌کریم', 'رباط كريم'), isTrue);
    expect(PersianText.matches('Tehran', 'tEh'), isTrue);
    expect(PersianText.matches('تهران', 'اصف'), isFalse);
    expect(PersianText.matches('تهران', '  '), isTrue);
  });
}
