part of 'phone_bloc.dart';

enum PhoneStatus {
  /// Typing, or back after an error.
  editing,

  /// Waiting on the server to send the code.
  sending,

  /// The code is on its way; [PhoneState.challenge] says where. The screen moves on to code entry.
  codeSent,
}

class PhoneState extends Equatable {
  const PhoneState({
    this.phone = '',
    this.status = PhoneStatus.editing,
    this.fieldError,
    this.serverError,
    this.cooldownSeconds = 0,
    this.challenge,
  });

  /// The number as typed.
  final String phone;
  final PhoneStatus status;

  /// Shown under the field: the number is missing or not an Iranian mobile.
  final String? fieldError;

  /// The server's message for any other failure, shown above the button.
  final String? serverError;

  /// Seconds before the server takes another request (its `Retry-After`); the button is disabled until 0.
  final int cooldownSeconds;

  /// The last code sent.
  final OtpChallenge? challenge;

  bool get canSubmit => status != PhoneStatus.sending && cooldownSeconds == 0;

  /// Nullable members take a function, so they can be set back to null.
  PhoneState copyWith({
    String? phone,
    PhoneStatus? status,
    String? Function()? fieldError,
    String? Function()? serverError,
    int? cooldownSeconds,
    OtpChallenge? Function()? challenge,
  }) => PhoneState(
    phone: phone ?? this.phone,
    status: status ?? this.status,
    fieldError: fieldError == null ? this.fieldError : fieldError(),
    serverError: serverError == null ? this.serverError : serverError(),
    cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    challenge: challenge == null ? this.challenge : challenge(),
  );

  @override
  List<Object?> get props => [phone, status, fieldError, serverError, cooldownSeconds, challenge];
}
