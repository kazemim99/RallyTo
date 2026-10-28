part of 'code_bloc.dart';

enum CodeStatus { idle, verifying, resending, verified }

class CodeState extends Equatable {
  const CodeState({
    required this.phoneNumber,
    this.status = CodeStatus.idle,
    this.error,
    this.blockedMessage,
    this.resendSecondsLeft = 0,
    this.resentCount = 0,
    this.errorCount = 0,
  });

  /// Canonical «09xxxxxxxxx».
  final String phoneNumber;
  final CodeStatus status;

  /// Shown under the code: wrong, expired, too many tries, or a failed resend.
  final String? error;

  /// The server's message for a suspended or banned account, shown in a dialog.
  final String? blockedMessage;

  /// Seconds before a new code may be asked for.
  final int resendSecondsLeft;

  /// Codes re-sent from this screen; each one is confirmed to the player.
  final int resentCount;

  /// Refused codes; each one clears the field for the next try.
  final int errorCount;

  bool get isBusy => status == CodeStatus.verifying || status == CodeStatus.resending;
  bool get canResend => !isBusy && status != CodeStatus.verified && resendSecondsLeft == 0;

  /// Nullable members take a function, so they can be set back to null.
  CodeState copyWith({
    CodeStatus? status,
    String? Function()? error,
    String? Function()? blockedMessage,
    int? resendSecondsLeft,
    int? resentCount,
    int? errorCount,
  }) => CodeState(
    phoneNumber: phoneNumber,
    status: status ?? this.status,
    error: error == null ? this.error : error(),
    blockedMessage: blockedMessage == null ? this.blockedMessage : blockedMessage(),
    resendSecondsLeft: resendSecondsLeft ?? this.resendSecondsLeft,
    resentCount: resentCount ?? this.resentCount,
    errorCount: errorCount ?? this.errorCount,
  );

  @override
  List<Object?> get props => [phoneNumber, status, error, blockedMessage, resendSecondsLeft, resentCount, errorCount];
}
