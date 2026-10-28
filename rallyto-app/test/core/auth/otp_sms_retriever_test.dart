import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/otp_sms_retriever.dart';

/// The sign-in code fills itself in from the SMS on Android (SMS User Consent API: no app hash in the text). Ported
/// from AsanRezerve's customer app, with the code length at 4.
void main() {
  group('the code in an SMS', () {
    test('is the standalone 4-digit number, whatever surrounds it', () {
      expect(OtpSmsRetriever.extractCode('کد ورود رالیتو: 4821\nلغو11'), '4821');
      expect(OtpSmsRetriever.extractCode('4821 کد ورود شما است'), '4821');
      expect(OtpSmsRetriever.extractCode('Your code is 0457.'), '0457');
    });

    test('in Persian or Arabic digits too, given back in ASCII', () {
      expect(OtpSmsRetriever.extractCode('کد شما ۴۸۲۱ است'), '4821');
      expect(OtpSmsRetriever.extractCode('رمز ٤٨٢١'), '4821');
    });

    test('never a piece of a longer number, and nothing when there is none', () {
      expect(OtpSmsRetriever.extractCode('شماره 09121234567 لغو11'), isNull);
      expect(OtpSmsRetriever.extractCode('سلام'), isNull);
      expect(OtpSmsRetriever.extractCode(''), isNull);
    });
  });

  group('the retriever', () {
    test('reads one SMS and hands pinput its code', () async {
      final retriever = OtpSmsRetriever(readSms: () async => 'کد ورود رالیتو: 7310');
      expect(await retriever.getSmsCode(), '7310');
      expect(retriever.listenForMultipleSms, isFalse);
    });

    test('hands nothing when the player declines, no SMS comes, or Play services are missing', () async {
      expect(await OtpSmsRetriever(readSms: () async => null).getSmsCode(), isNull);
      expect(await OtpSmsRetriever(readSms: () async => throw Exception('no play services')).getSmsCode(), isNull);
    });

    test('stops listening when the screen goes, quietly when nothing listened', () async {
      var stopped = false;
      await OtpSmsRetriever(readSms: () async => null, stop: () async => stopped = true).dispose();
      expect(stopped, isTrue);
      await OtpSmsRetriever(readSms: () async => null, stop: () async => throw Exception('not listening')).dispose();
    });
  });
}
