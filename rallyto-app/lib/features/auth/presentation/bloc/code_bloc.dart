import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/auth/auth_session_cubit.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/otp.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../domain/auth_repository.dart';
import '../../domain/otp_challenge.dart';

part 'code_event.dart';
part 'code_state.dart';

/// Code entry: trades the SMS code for a session, and offers a new code once the server's resend wait is over.
///
/// A verified code signs in through [AuthSessionCubit] (which stores the tokens); the router then moves the player
/// to `/onboarding` or `/home` on its own. A suspended or banned account is reported in [CodeState.blockedMessage]
/// and the player stays here.
@injectable
class CodeBloc extends Bloc<CodeEvent, CodeState> {
  CodeBloc(this._repository, this._session, this._countdown, @factoryParam OtpChallenge challenge)
    : super(CodeState(phoneNumber: challenge.phoneNumber, resendSecondsLeft: challenge.resendAfterSeconds)) {
    on<CodeStarted>(_onStarted);
    on<CodeChanged>(_onChanged);
    on<CodeSubmitted>(_onSubmitted);
    on<CodeResendRequested>(_onResendRequested);
    on<CodeBlockedDismissed>(_onBlockedDismissed);
    on<_CodeResendTicked>(_onResendTicked);
  }

  final AuthRepository _repository;
  final AuthSessionCubit _session;
  final Countdown _countdown;
  StreamSubscription<int>? _resendTimer;

  void _onStarted(CodeStarted event, Emitter<CodeState> emit) => _startResendTimer(state.resendSecondsLeft, emit);

  void _onChanged(CodeChanged event, Emitter<CodeState> emit) {
    if (state.error != null) emit(state.copyWith(error: () => null));
  }

  Future<void> _onSubmitted(CodeSubmitted event, Emitter<CodeState> emit) async {
    if (state.isBusy || state.status == CodeStatus.verified) return;
    final code = PersianDigits.digitsOnly(event.code);
    if (code.length != otpLength) {
      emit(state.copyWith(error: () => AppStrings.codeIncomplete));
      return;
    }

    emit(state.copyWith(status: CodeStatus.verifying, error: () => null));
    final result = await _repository.verifyCode(phoneNumber: state.phoneNumber, code: code);
    await result.fold<Future<void>>(
      (failure) async {
        emit(
          state.copyWith(
            status: CodeStatus.idle,
            error: () => failure.isAccountBlocked ? null : failure.message,
            blockedMessage: () => failure.isAccountBlocked ? failure.message : null,
            errorCount: state.errorCount + 1,
          ),
        );
      },
      (session) async {
        try {
          await _session.signIn(session);
        } catch (_) {
          // The tokens could not be stored: the player can try again.
          emit(state.copyWith(status: CodeStatus.idle, error: () => AppStrings.genericError));
          return;
        }
        // The router may already have replaced this screen.
        if (!isClosed) emit(state.copyWith(status: CodeStatus.verified));
      },
    );
  }

  Future<void> _onResendRequested(CodeResendRequested event, Emitter<CodeState> emit) async {
    if (!state.canResend) return;
    emit(state.copyWith(status: CodeStatus.resending, error: () => null));
    final result = await _repository.sendCode(state.phoneNumber);
    result.fold(
      (failure) {
        emit(state.copyWith(status: CodeStatus.idle, error: () => failure.message));
        final wait = failure.retryAfterSeconds;
        if (wait != null) _startResendTimer(wait, emit);
      },
      (challenge) {
        emit(state.copyWith(status: CodeStatus.idle, resentCount: state.resentCount + 1));
        _startResendTimer(challenge.resendAfterSeconds, emit);
      },
    );
  }

  void _onBlockedDismissed(CodeBlockedDismissed event, Emitter<CodeState> emit) {
    emit(state.copyWith(blockedMessage: () => null));
  }

  void _onResendTicked(_CodeResendTicked event, Emitter<CodeState> emit) {
    emit(state.copyWith(resendSecondsLeft: event.secondsLeft));
  }

  void _startResendTimer(int seconds, Emitter<CodeState> emit) {
    unawaited(_resendTimer?.cancel());
    emit(state.copyWith(resendSecondsLeft: seconds < 0 ? 0 : seconds));
    _resendTimer = _countdown.start(seconds).listen((left) => add(_CodeResendTicked(left)));
  }

  @override
  Future<void> close() async {
    await _resendTimer?.cancel();
    return super.close();
  }
}
