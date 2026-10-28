import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/report.dart';
import '../domain/report_rules.dart';

/// Persian labels for reports, and the messages for the server's report error codes.
class ReportLabels {
  ReportLabels._();

  static String reason(ReportReason reason) => switch (reason) {
    ReportReason.harassment => AppStrings.reasonHarassment,
    ReportReason.inappropriateContent => AppStrings.reasonInappropriateContent,
    ReportReason.fakeProfile => AppStrings.reasonFakeProfile,
    ReportReason.spam => AppStrings.reasonSpam,
    ReportReason.unsafeBehaviour => AppStrings.reasonUnsafeBehaviour,
    ReportReason.underage => AppStrings.reasonUnderage,
    ReportReason.other => AppStrings.reasonOther,
  };

  /// What was reported, in a list: «بازیکن», «پیام», …
  static String targetType(ReportTargetType type) => switch (type) {
    ReportTargetType.player => AppStrings.reportTargetPlayer,
    ReportTargetType.message => AppStrings.reportTargetMessage,
    ReportTargetType.post => AppStrings.reportTargetPost,
    ReportTargetType.photo => AppStrings.reportTargetPhoto,
  };

  /// The form's title.
  static String formTitle(ReportTargetType type) => switch (type) {
    ReportTargetType.player => AppStrings.reportPlayerTitle,
    ReportTargetType.message => AppStrings.reportMessageTitle,
    ReportTargetType.post => AppStrings.reportPostTitle,
    ReportTargetType.photo => AppStrings.reportPhotoTitle,
  };

  static String status(ReportStatus status) => switch (status) {
    ReportStatus.open => AppStrings.reportStatusOpen,
    ReportStatus.resolved => AppStrings.reportStatusResolved,
  };

  /// The player-facing message for a refused report: the app's words for a known code, else the server's.
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  /// The message for a rule checked on the device, by its code.
  static String rule(String code) => _messages[code] ?? AppStrings.genericError;

  static const Map<String, String> _messages = {
    ReportErrorCodes.alreadyReported: AppStrings.alreadyReported,
    ReportErrorCodes.messageNotFound: AppStrings.reportMessageNotFound,
    ReportErrorCodes.photoNotFound: AppStrings.reportPhotoNotFound,
    ReportErrorCodes.playerNotFound: AppStrings.playerNotFound,
    ReportErrorCodes.matchNotFound: AppStrings.reportPostNotFound,
    ReportErrorCodes.cannotReportSelf: AppStrings.cannotReportSelf,
    ReportErrorCodes.detailsTooLong: AppStrings.reportDetailsTooLong,
    ReportErrorCodes.tooManyRequests: AppStrings.reportTooManyRequests,
    ReportErrorCodes.reasonRequired: AppStrings.reportReasonRequired,
  };
}
