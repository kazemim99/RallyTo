import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/auth/auth_error_codes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/otp_challenge.dart';

part 'phone_event.dart';
part 'phone_state.dart';

/// Phone entry: validates an Iranian mobile number typed in any digits, sends the sign-in code to its canonical form
/// («09xxxxxxxxx»), and holds the send button for as long as the server asks (`Retry-After` on a 429).
@injectable
class PhoneBloc extends Bloc<PhoneEvent, PhoneState> {
  PhoneBloc(this._repository, this._countdown) : super(const PhoneState()) {
    on<PhoneChanged>(_onChanged);
    on<PhoneSubmitted>(_onSubmitted);
    on<_PhoneCooldownTicked>(_onCooldownTicked);
  }

  final AuthRepository _repository;
  final Countdown _countdown;
  StreamSubscription<int>? _cooldown;

  /// The inline message for [input], or null when it is a valid Iranian mobile number.
  static String? validate(String input) {
    if (PersianDigits.digitsOnly(input).isEmpty) return AppStrings.phoneRequired;
    return PersianDigits.isValidIranianMobile(input) ? null : AppStrings.phoneInvalid;
  }

  void _onChanged(PhoneChanged event, Emitter<PhoneState> emit) {
    // Once a message is showing, it follows the typing, so it goes away as soon as the number is right.
    final fieldError = state.fieldError == null ? null : validate(event.phone);
    emit(state.copyWith(phone: event.phone, fieldError: () => fieldError, serverError: () => null));
  }

  Future<void> _onSubmitted(PhoneSubmitted event, Emitter<PhoneState> emit) async {
    if (!state.canSubmit) return;
    final fieldError = validate(state.phone);
    if (fieldError != null) {
      emit(state.copyWith(fieldError: () => fieldError, serverError: () => null));
      return;
    }

    final phoneNumber = PersianDigits.canonicalMobile(state.phone);
    emit(state.copyWith(status: PhoneStatus.sending, fieldError: () => null, serverError: () => null));
    final result = await _repository.sendCode(phoneNumber);
    result.fold(
      (failure) => _failed(failure, emit),
      (challenge) => emit(state.copyWith(status: PhoneStatus.codeSent, challenge: () => challenge)),
    );
  }

  void _failed(AuthFailure failure, Emitter<PhoneState> emit) {
    // The server's verdict on the number belongs under the field; anything else above the button.
    final aboutNumber = failure.code == AuthErrorCodes.invalidPhoneNumber;
    emit(
      state.copyWith(
        status: PhoneStatus.editing,
        fieldError: () => aboutNumber ? failure.message : null,
        serverError: () => aboutNumber ? null : failure.message,
      ),
    );
    final wait = failure.retryAfterSeconds;
    if (wait != null) _startCooldown(wait, emit);
  }

  void _startCooldown(int seconds, Emitter<PhoneState> emit) {
    unawaited(_cooldown?.cancel());
    emit(state.copyWith(cooldownSeconds: seconds));
    _cooldown = _countdown.start(seconds).listen((left) => add(_PhoneCooldownTicked(left)));
  }

  void _onCooldownTicked(_PhoneCooldownTicked event, Emitter<PhoneState> emit) {
    emit(state.copyWith(cooldownSeconds: event.secondsLeft));
  }

  @override
  Future<void> close() async {
    await _cooldown?.cancel();
    return super.close();
  }
}
