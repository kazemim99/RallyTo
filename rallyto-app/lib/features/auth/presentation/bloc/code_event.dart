part of 'code_bloc.dart';

sealed class CodeEvent extends Equatable {
  const CodeEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen opened: the resend wait starts.
final class CodeStarted extends CodeEvent {
  const CodeStarted();
}

/// The player edited the code.
final class CodeChanged extends CodeEvent {
  const CodeChanged();
}

/// A complete code, typed or filled in from the SMS, in any digits.
final class CodeSubmitted extends CodeEvent {
  const CodeSubmitted(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// The player asked for a new code.
final class CodeResendRequested extends CodeEvent {
  const CodeResendRequested();
}

/// The player closed the suspended/banned dialog.
final class CodeBlockedDismissed extends CodeEvent {
  const CodeBlockedDismissed();
}

/// A second of the resend wait passed.
final class _CodeResendTicked extends CodeEvent {
  const _CodeResendTicked(this.secondsLeft);

  final int secondsLeft;

  @override
  List<Object?> get props => [secondsLeft];
}
