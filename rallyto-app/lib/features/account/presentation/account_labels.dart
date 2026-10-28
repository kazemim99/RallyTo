import '../../../core/auth/auth_error_codes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';

/// Persian messages for the account deletion flow.
class AccountLabels {
  AccountLabels._();

  /// The player-facing message for a refused deletion step: the app's words for a known code, else the server's
  /// (already Persian), else the failure's own (offline, …).
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  static const Map<String, String> _messages = {
    AuthErrorCodes.codeInvalid: AppStrings.deletionCodeInvalid,
    AuthErrorCodes.codeExpired: AppStrings.deletionCodeExpired,
    AuthErrorCodes.otpResendTooSoon: AppStrings.deletionTooSoon,
    'TOO_MANY_REQUESTS': AppStrings.deletionTooMany,
  };
}
