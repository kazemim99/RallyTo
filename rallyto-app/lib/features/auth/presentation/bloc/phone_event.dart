part of 'phone_bloc.dart';

sealed class PhoneEvent extends Equatable {
  const PhoneEvent();

  @override
  List<Object?> get props => const [];
}

/// The player edited the number. [phone] is as typed: Persian, Arabic or ASCII digits, spaces, a leading +98.
final class PhoneChanged extends PhoneEvent {
  const PhoneChanged(this.phone);

  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// The player asked for the code.
final class PhoneSubmitted extends PhoneEvent {
  const PhoneSubmitted();
}

/// A second of the server's wait passed.
final class _PhoneCooldownTicked extends PhoneEvent {
  const _PhoneCooldownTicked(this.secondsLeft);

  final int secondsLeft;

  @override
  List<Object?> get props => [secondsLeft];
}
