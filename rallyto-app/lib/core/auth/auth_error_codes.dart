import 'package:dio/dio.dart';

import '../constants/app_strings.dart';
import '../errors/server_message.dart';

/// The machine-readable `error.code` values the sign-in and account endpoints answer with. Their `error.message`
/// is already Persian and meant for the player, so the app shows it as it is.
class AuthErrorCodes {
  AuthErrorCodes._();

  // POST /auth/otp/send
  static const String invalidPhoneNumber = 'INVALID_PHONE_NUMBER';
  static const String otpResendTooSoon = 'OTP_RESEND_TOO_SOON';
  static const String otpSendLimit = 'OTP_SEND_LIMIT';
  static const String smsSendFailed = 'SMS_SEND_FAILED';

  // POST /auth/otp/send and /auth/otp/verify
  static const String verificationBlocked = 'VERIFICATION_BLOCKED';

  // POST /auth/otp/verify
  static const String codeInvalid = 'CODE_INVALID';
  static const String codeExpired = 'CODE_EXPIRED';

  // POST /auth/otp/verify (403), and any authenticated request (401)
  static const String accountSuspended = 'ACCOUNT_SUSPENDED';
  static const String accountBanned = 'ACCOUNT_BANNED';

  // Any authenticated request (401)
  static const String accountInactive = 'ACCOUNT_INACTIVE';

  // POST /auth/refresh (401)
  static const String refreshTokenInvalid = 'REFRESH_TOKEN_INVALID';
  static const String refreshTokenReused = 'REFRESH_TOKEN_REUSED';

  /// A 401 with one of these means the account itself can no longer be used: renewing the token would not help, so
  /// the app signs out on this device and shows the server's message.
  static const Set<String> accountEnded = {accountSuspended, accountBanned, accountInactive};

  /// The verify answers that keep a player out however many times they retry (suspended, or banned).
  static const Set<String> accountBlocked = {accountSuspended, accountBanned};
}

/// The message to sign out with when [response] is a 401 that ended the account (suspended, banned, inactive), or
/// null when it is any other answer. The server's own words when it sent any.
String? accountEndedMessage(Response<dynamic>? response) {
  if (response?.statusCode != 401) return null;
  final data = response?.data;
  if (!AuthErrorCodes.accountEnded.contains(serverErrorCode(data))) return null;
  return serverMessage(data) ?? AppStrings.accountEndedError;
}
