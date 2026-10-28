import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/notification.dart';
import '../../domain/notification_repository.dart';
import '../../domain/notification_rules.dart';
import '../notification_labels.dart';

/// The push switches per category and the quiet hours (spec notifications › Notification preferences, Quiet hours).
/// Each change is saved at once, and undone on screen when the server refuses it.
@injectable
class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit(this._notifications) : super(const NotificationPreferencesState());

  final NotificationRepository _notifications;

  Future<void> load() async {
    emit(const NotificationPreferencesState());
    final result = await _notifications.getPreferences();
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(NotificationPreferencesState(status: ViewStatus.error, errorMessage: NotificationLabels.error(failure))),
      (preferences) => emit(NotificationPreferencesState(status: ViewStatus.content, preferences: preferences)),
    );
  }

  Future<void> setPushMatches(bool on) => _save(state.preferences.copyWith(pushMatches: on));

  Future<void> setPushChat(bool on) => _save(state.preferences.copyWith(pushChat: on));

  Future<void> setPushRatings(bool on) => _save(state.preferences.copyWith(pushRatings: on));

  Future<void> setPushSavedSearches(bool on) => _save(state.preferences.copyWith(pushSavedSearches: on));

  Future<void> setQuietHoursEnabled(bool on) => _save(state.preferences.copyWith(quietHoursEnabled: on));

  /// [minute] on the 30-minute grid; the window may run past midnight.
  Future<void> setQuietStart(int minute) => _save(state.preferences.copyWith(quietStartMinute: minute));

  Future<void> setQuietEnd(int minute) => _save(state.preferences.copyWith(quietEndMinute: minute));

  Future<void> _save(NotificationPreferences next) async {
    if (state.status != ViewStatus.content || state.saving || next == state.preferences) return;
    final code = QuietHoursRules.check(next);
    if (code != null) {
      emit(state.copyWith(feedback: ProfileFeedback(NotificationLabels.rule(code), isError: true, code: code)));
      return;
    }
    final previous = state.preferences;
    emit(state.copyWith(preferences: next, saving: true));
    final result = await _notifications.updatePreferences(next);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          preferences: previous,
          saving: false,
          feedback: ProfileFeedback(NotificationLabels.error(failure), isError: true, code: failure.code),
        ),
      ),
      (saved) => emit(
        state.copyWith(preferences: saved, saving: false, feedback: const ProfileFeedback(AppStrings.preferencesSaved)),
      ),
    );
  }
}

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.status = ViewStatus.loading,
    this.preferences = const NotificationPreferences(),
    this.saving = false,
    this.errorMessage,
    this.feedback,
  });

  final ViewStatus status;
  final NotificationPreferences preferences;

  /// A change is on its way; the next waits for it.
  final bool saving;
  final String? errorMessage;
  final ProfileFeedback? feedback;

  NotificationPreferencesState copyWith({
    NotificationPreferences? preferences,
    bool? saving,
    ProfileFeedback? feedback,
  }) => NotificationPreferencesState(
    status: status,
    preferences: preferences ?? this.preferences,
    saving: saving ?? this.saving,
    errorMessage: errorMessage,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, preferences, saving, errorMessage, feedback];
}
