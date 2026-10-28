import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/auth/auth_session_cubit.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/otp.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../domain/account_repository.dart';
import '../account_labels.dart';

/// Where the deletion flow is.
enum AccountDeletionStatus {
  /// A code is being asked for (the first one, on [AccountDeletionCubit.start]).
  requesting,

  /// Waiting on the player: a code was sent, or asking for one failed.
  idle,

  /// The code is being checked and the account deleted.
  verifying,

  /// Another code is being asked for.
  resending,

  /// The account is gone and the session ended; the router moves the player to phone entry.
  deleted,
}

/// Deleting the player's own account after a fresh SMS code (spec identity-access › Account deletion): asks for the
/// code, offers another once the server's wait is over, then deletes. A deleted account ends the session through
/// [AuthSessionCubit.signOutDeletedAccount] (the before-sign-out hooks run, the device token is unregistered), and
/// phone entry says the account was deleted. A wrong or expired code leaves the account as it is.
@injectable
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this._repository, this._session, this._countdown) : super(const AccountDeletionState());

  final AccountRepository _repository;
  final AuthSessionCubit _session;
  final Countdown _countdown;
  StreamSubscription<int>? _resendTimer;

  /// Asks for the first code, once.
  Future<void> start() async {
    if (state.started) return;
    await _request(resend: false);
  }

  /// Asks for another code, once the wait is over.
  Future<void> resend() async {
    if (!state.canResend) return;
    await _request(resend: true);
  }

  /// The player typed: the last error goes.
  void codeChanged() {
    if (state.error != null) emit(state.copyWith(error: () => null));
  }

  /// Deletes the account with [code]. True once deleted.
  Future<bool> submit(String code) async {
    if (!state.canSubmit) return false;
    final digits = PersianDigits.digitsOnly(code);
    if (digits.length != otpLength) {
      emit(state.copyWith(error: () => AppStrings.codeIncomplete));
      return false;
    }
    emit(state.copyWith(status: AccountDeletionStatus.verifying, error: () => null));
    final result = await _repository.deleteAccount(digits);
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: AccountDeletionStatus.idle,
            error: () => AccountLabels.error(failure),
            errorCount: state.errorCount + 1,
          ),
        );
      }
      return false;
    }
    if (!isClosed) emit(state.copyWith(status: AccountDeletionStatus.deleted));
    unawaited(_resendTimer?.cancel());
    // The account is gone on the server: the session ends here whatever this screen does meanwhile.
    await _session.signOutDeletedAccount(AppStrings.accountDeletedNotice);
    return true;
  }

  Future<void> _request({required bool resend}) async {
    emit(
      state.copyWith(
        status: resend ? AccountDeletionStatus.resending : AccountDeletionStatus.requesting,
        started: true,
        error: () => null,
      ),
    );
    final result = await _repository.requestDeletionCode();
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(state.copyWith(status: AccountDeletionStatus.idle, error: () => AccountLabels.error(failure)));
        _startResendTimer(failure.retryAfterSeconds ?? 0);
      },
      (code) {
        emit(
          state.copyWith(
            status: AccountDeletionStatus.idle,
            codeSent: true,
            resentCount: resend ? state.resentCount + 1 : state.resentCount,
          ),
        );
        _startResendTimer(code.resendAfterSeconds);
      },
    );
  }

  void _startResendTimer(int seconds) {
    unawaited(_resendTimer?.cancel());
    emit(state.copyWith(resendSecondsLeft: seconds < 0 ? 0 : seconds));
    _resendTimer = _countdown.start(seconds).listen((left) {
      if (!isClosed) emit(state.copyWith(resendSecondsLeft: left));
    });
  }

  @override
  Future<void> close() async {
    await _resendTimer?.cancel();
    return super.close();
  }
}

class AccountDeletionState extends Equatable {
  const AccountDeletionState({
    this.status = AccountDeletionStatus.requesting,
    this.started = false,
    this.codeSent = false,
    this.error,
    this.resendSecondsLeft = 0,
    this.resentCount = 0,
    this.errorCount = 0,
  });

  final AccountDeletionStatus status;

  /// The first code was asked for.
  final bool started;

  /// A code reached the server's SMS sender at least once: the boxes can be filled.
  final bool codeSent;

  /// Shown under the code: wrong, expired, too many tries, or a failed request.
  final String? error;

  /// Seconds before a new code may be asked for.
  final int resendSecondsLeft;

  /// Codes re-sent; each one is confirmed to the player.
  final int resentCount;

  /// Refused codes; each one clears the boxes for the next try.
  final int errorCount;

  bool get isBusy =>
      status == AccountDeletionStatus.requesting ||
      status == AccountDeletionStatus.verifying ||
      status == AccountDeletionStatus.resending;

  bool get canResend => !isBusy && status != AccountDeletionStatus.deleted && resendSecondsLeft == 0;

  bool get canSubmit => codeSent && !isBusy && status != AccountDeletionStatus.deleted;

  /// Nullable members take a function, so they can be set back to null.
  AccountDeletionState copyWith({
    AccountDeletionStatus? status,
    bool? started,
    bool? codeSent,
    String? Function()? error,
    int? resendSecondsLeft,
    int? resentCount,
    int? errorCount,
  }) => AccountDeletionState(
    status: status ?? this.status,
    started: started ?? this.started,
    codeSent: codeSent ?? this.codeSent,
    error: error == null ? this.error : error(),
    resendSecondsLeft: resendSecondsLeft ?? this.resendSecondsLeft,
    resentCount: resentCount ?? this.resentCount,
    errorCount: errorCount ?? this.errorCount,
  );

  @override
  List<Object?> get props => [status, started, codeSent, error, resendSecondsLeft, resentCount, errorCount];
}
