import 'entities/report.dart';

/// The server's `error.code`s for reports.
class ReportErrorCodes {
  ReportErrorCodes._();

  static const String alreadyReported = 'ALREADY_REPORTED';
  static const String messageNotFound = 'MESSAGE_NOT_FOUND';
  static const String photoNotFound = 'PHOTO_NOT_FOUND';
  static const String playerNotFound = 'PLAYER_NOT_FOUND';
  static const String matchNotFound = 'MATCH_NOT_FOUND';
  static const String cannotReportSelf = 'CANNOT_REPORT_SELF';
  static const String detailsTooLong = 'DETAILS_TOO_LONG';
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';

  /// Not the server's: no reason picked, checked on the device.
  static const String reasonRequired = 'REASON_REQUIRED';
}

/// The report rules the app checks before sending.
class ReportRules {
  ReportRules._();

  static const int maxDetailsLength = 1000;

  /// The code for what is wrong with a report of [reason] with [details], or null when it can be sent.
  static String? check(ReportReason? reason, String? details) {
    if (reason == null) return ReportErrorCodes.reasonRequired;
    if ((details?.trim().length ?? 0) > maxDetailsLength) return ReportErrorCodes.detailsTooLong;
    return null;
  }
}
