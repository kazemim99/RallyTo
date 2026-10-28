import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../availability/domain/availability_repository.dart';
import '../../../availability/domain/entities/availability_window.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/match_repository.dart';
import '../../../matches/presentation/match_labels.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';

/// What home shows besides the badges, from the repositories the other screens already use: the player's name, their
/// next game, what waits on them in their games, and their availability (the active-window count and the "still
/// free?" reminder). Each part loads on its own; one failing leaves the others shown.
///
/// Not registered for injection: [HomePage] builds it from the app's repositories ([HomeCubit.fromLocator]) unless a
/// test provides one.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._profiles, this._matches, this._availability, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const HomeState());

  /// Over the app's registered repositories.
  factory HomeCubit.fromLocator() =>
      HomeCubit(getIt<ProfileRepository>(), getIt<MatchRepository>(), getIt<AvailabilityRepository>());

  final ProfileRepository _profiles;
  final MatchRepository _matches;
  final AvailabilityRepository _availability;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  /// Loads every part together. A reload keeps what is shown until the new answers come.
  Future<void> load() async {
    final profile = _profiles.getMyProfile();
    final upcoming = _matches.getMine(upcoming: true);
    final past = _matches.getMine(upcoming: false);
    final windows = _availability.getMine();
    final profileResult = await profile;
    final upcomingResult = await upcoming;
    final pastResult = await past;
    final windowsResult = await windows;
    if (isClosed) return;
    final at = now;
    final upcomingGames = upcomingResult.fold((_) => const <Match>[], (m) => m);
    final pastGames = pastResult.fold((_) => const <Match>[], (m) => m);
    final next = nextGameOf(upcomingGames, at);
    emit(
      HomeState(
        name: profileResult.fold((_) => state.name, (p) => p.displayName.trim().isEmpty ? null : p.displayName.trim()),
        gamesStatus: upcomingResult.isLeft()
            ? ViewStatus.error
            : next == null
            ? ViewStatus.empty
            : ViewStatus.content,
        gamesError: upcomingResult.fold(MatchLabels.error, (_) => null),
        nextGame: next,
        tasks: HomeTask.from(upcoming: upcomingGames, past: pastGames, now: at),
        windows: windowsResult.fold((_) => null, (w) => w),
        reconfirmed: state.reconfirmed,
      ),
    );
  }

  /// «هنوز آزادم»: confirms the windows the server says need it ([HomeState.reconfirmCandidates]) at once, so none
  /// pauses itself. The others are left alone.
  Future<void> reconfirm() async {
    final windows = state.reconfirmCandidates;
    if (windows.isEmpty || state.reconfirming) return;
    emit(state.copyWith(reconfirming: true));
    final results = await Future.wait([for (final w in windows) _availability.confirm(w.id)]);
    if (isClosed) return;
    final failure = results.map((r) => r.fold<Failure?>((f) => f, (_) => null)).whereType<Failure>().firstOrNull;
    final confirmed = {
      for (final r in results)
        if (r case Right(value: final w)) w.id: w,
    };
    emit(
      state.copyWith(
        reconfirming: false,
        reconfirmed: failure == null,
        windows: [for (final w in state.windows ?? const <AvailabilityWindow>[]) confirmed[w.id] ?? w],
        feedback: failure == null
            ? const ProfileFeedback(AppStrings.availabilityConfirmed)
            : ProfileFeedback(failure.message, isError: true, code: failure.code),
      ),
    );
  }

  /// The soonest game still ahead that this player plays in (as host or accepted), or null.
  static Match? nextGameOf(List<Match> upcoming, DateTime now) {
    Match? next;
    for (final match in upcoming) {
      final plays = match.myState?.plays ?? false;
      if (!plays || !match.status.isActive || match.hasStarted(now)) continue;
      if (next == null || match.startsAt.isBefore(next.startsAt)) next = match;
    }
    return next;
  }
}

/// Something in the player's games that waits on them.
enum HomeTaskKind {
  /// An invitation to answer.
  invitation,

  /// Join requests to answer, as the host.
  requests,

  /// "Was the game played?", once it ended.
  attendance,

  /// Players to rate.
  rating,
}

/// One pending action on home: what it is, and the game it opens.
class HomeTask extends Equatable {
  const HomeTask(this.kind, this.match);

  final HomeTaskKind kind;
  final Match match;

  /// The pending actions in [upcoming] and [past] games: invitations and join requests soonest first, then the
  /// attendance questions and ratings of games that ended.
  static List<HomeTask> from({required List<Match> upcoming, required List<Match> past, required DateTime now}) {
    final ahead = [...upcoming]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return [
      for (final m in ahead)
        if (m.canAnswerInvitation(now))
          HomeTask(HomeTaskKind.invitation, m)
        else if (m.canAnswerRequests(now) && m.pendingRequests.isNotEmpty)
          HomeTask(HomeTaskKind.requests, m),
      for (final m in past)
        if (m.canAnswerAttendance)
          HomeTask(HomeTaskKind.attendance, m)
        else if (m.rateablePlayers.isNotEmpty)
          HomeTask(HomeTaskKind.rating, m),
    ];
  }

  @override
  List<Object?> get props => [kind, match];
}

class HomeState extends Equatable {
  const HomeState({
    this.name,
    this.gamesStatus = ViewStatus.loading,
    this.gamesError,
    this.nextGame,
    this.tasks = const [],
    this.windows,
    this.reconfirming = false,
    this.reconfirmed = false,
    this.feedback,
  });

  /// The player's display name; null until the profile answers (or when it cannot be read).
  final String? name;

  /// The next game's part: loading, content (a game), empty (none ahead) or error.
  final ViewStatus gamesStatus;
  final String? gamesError;
  final Match? nextGame;
  final List<HomeTask> tasks;

  /// The player's availability windows; null until they load, or when they could not be read.
  final List<AvailabilityWindow>? windows;
  final bool reconfirming;

  /// The player said they are still free during this visit: the reminder is not shown again.
  final bool reconfirmed;
  final ProfileFeedback? feedback;

  /// How many windows are active; null when unknown.
  int? get activeWindowCount => windows?.where((w) => w.status == AvailabilityStatus.active).length;

  /// The windows the reminder is about and confirms: those the server marks `needsReconfirmation` (active weekly
  /// windows 27 or more days after their last confirmation).
  List<AvailabilityWindow> get reconfirmCandidates => [
    for (final w in windows ?? const <AvailabilityWindow>[])
      if (w.needsReconfirmation && w.status == AvailabilityStatus.active) w,
  ];

  bool get showReconfirm => !reconfirmed && reconfirmCandidates.isNotEmpty;

  HomeState copyWith({
    List<AvailabilityWindow>? windows,
    bool? reconfirming,
    bool? reconfirmed,
    ProfileFeedback? feedback,
  }) => HomeState(
    name: name,
    gamesStatus: gamesStatus,
    gamesError: gamesError,
    nextGame: nextGame,
    tasks: tasks,
    windows: windows ?? this.windows,
    reconfirming: reconfirming ?? this.reconfirming,
    reconfirmed: reconfirmed ?? this.reconfirmed,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [
    name,
    gamesStatus,
    gamesError,
    nextGame,
    tasks,
    windows,
    reconfirming,
    reconfirmed,
    feedback,
  ];
}
