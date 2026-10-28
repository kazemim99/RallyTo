import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/server_message.dart';

void main() {
  group('serverMessage', () {
    test('reads the envelope message', () {
      expect(
        serverMessage({
          'success': false,
          'message': 'کد منقضی شده است',
          'error': {'code': 'X'},
        }),
        'کد منقضی شده است',
      );
      expect(
        serverMessage({
          'error': {'message': 'خطا'},
        }),
        'خطا',
      );
    });

    test('prefers the per-field message over the English validation headline', () {
      expect(
        serverMessage({
          'message': 'Validation failed for property Code',
          'error': {
            'message': 'Validation failed for property Code',
            'errors': {
              'Code': ['کد باید ۵ رقم باشد'],
            },
          },
        }),
        'کد باید ۵ رقم باشد',
      );
      expect(
        serverMessage({
          'errors': {
            'Code': ['کد باید ۵ رقم باشد'],
          },
        }),
        'کد باید ۵ رقم باشد',
      );
    });

    test('reads a list of errors', () {
      expect(
        serverMessage({
          'errors': [
            {'code': 'A', 'message': 'اولی'},
          ],
        }),
        'اولی',
      );
      expect(
        serverMessage({
          'errors': ['متن'],
        }),
        'متن',
      );
    });

    test('is null when there are no words', () {
      expect(serverMessage(null), isNull);
      expect(serverMessage('plain text'), isNull);
      expect(serverMessage({'message': '   '}), isNull);
    });
  });

  test('serverErrorCode and serverFieldErrors read the envelope error', () {
    final body = {
      'error': {
        'code': 'VALIDATION_ERROR',
        'errors': {
          'PhoneNumber': ['نامعتبر', ' '],
          'Code': 'کوتاه',
        },
      },
    };

    expect(serverErrorCode(body), 'VALIDATION_ERROR');
    expect(serverFieldErrors(body), {
      'PhoneNumber': ['نامعتبر'],
      'Code': ['کوتاه'],
    });
    expect(serverErrorCode({'message': 'x'}), isNull);
    expect(serverFieldErrors(null), isEmpty);
  });
}
