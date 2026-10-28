import 'package:flutter/foundation.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

import '../constants/otp.dart';

/// Fills the sign-in code in from the SMS that carries it. Ported from AsanRezerve's customer app.
///
/// Android's SMS User Consent API: the phone asks «allow Rallyto to read this message?» for the one SMS that
/// arrives, and only that message reaches the app. Unlike the SMS Retriever API it needs no app hash in the text, so
/// the SMS provider's approved template stays as it is. iOS offers the code above the keyboard by itself
/// (`AutofillHints.oneTimeCode`).
class OtpSmsRetriever implements SmsRetriever {
  OtpSmsRetriever({Future<String?> Function()? readSms, Future<void> Function()? stop, this.length = otpLength})
    : _readSms = readSms ?? _userConsentSms,
      _stop = stop ?? _stopUserConsent;

  final Future<String?> Function() _readSms;
  final Future<void> Function() _stop;
  final int length;

  /// The retriever for this platform: Android only; elsewhere the platform's own autofill does it.
  static OtpSmsRetriever? forPlatform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? OtpSmsRetriever() : null;

  static Future<String?> _userConsentSms() async {
    final result = await SmartAuth.instance.getSmsWithUserConsentApi();
    return result.data?.sms;
  }

  static Future<void> _stopUserConsent() async {
    await SmartAuth.instance.removeUserConsentApiListener();
  }

  /// The standalone [length]-digit number in [sms] (in ASCII, Persian or Arabic digits) given back in ASCII; never a
  /// piece of a longer number (a phone number, an opt-out code like «لغو11»). Null when there is none.
  static String? extractCode(String sms, {int length = otpLength}) {
    final ascii = sms.replaceAllMapped(RegExp('[۰-۹٠-٩]'), (m) {
      final unit = m[0]!.codeUnitAt(0);
      return String.fromCharCode(unit >= 0x06F0 ? unit - 0x06F0 + 0x30 : unit - 0x0660 + 0x30);
    });
    return RegExp('(?<![0-9])[0-9]{$length}(?![0-9])').firstMatch(ascii)?[0];
  }

  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    try {
      final sms = await _readSms();
      return sms == null ? null : extractCode(sms, length: length);
    } catch (_) {
      // No Play services, or the player said no: they type the code.
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _stop();
    } catch (_) {
      // Nothing was listening.
    }
  }
}
