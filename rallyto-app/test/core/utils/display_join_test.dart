import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/utils/display_join.dart';

void main() {
  test('words are separated by the bullet', () {
    expect(['تنیس', 'انفرادی'].joinDisplay(), 'تنیس${DisplayJoin.bullet}انفرادی');
  });

  test('a part that starts with a digit gets the Persian comma, so the dot is never read as a zero', () {
    expect(['متوسط', '۱ تا ۳ سال'].joinDisplay(), 'متوسط${DisplayJoin.comma}۱ تا ۳ سال');
    expect(['شنبه ۲ آبان', '19:00'].joinDisplay(), 'شنبه ۲ آبان${DisplayJoin.comma}19:00');
  });

  test('a part that ends with a digit gets the Persian comma too', () {
    expect(['۱۰:۴۲', 'خوانده شد'].joinDisplay(), '۱۰:۴۲${DisplayJoin.comma}خوانده شد');
  });

  test('empty parts are dropped and parts are trimmed', () {
    expect([' تهران ', '', '  ', 'استقلال'].joinDisplay(), 'تهران${DisplayJoin.bullet}استقلال');
    expect(<String>[].joinDisplay(), '');
    expect(['تنها'].joinDisplay(), 'تنها');
  });
}
