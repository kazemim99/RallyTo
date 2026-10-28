import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../availability/domain/availability_repository.dart';
import '../../../availability/domain/entities/availability_window.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/profile_repository.dart';

/// Another player's page: their profile, their active availability windows, and blocking them.
@injectable
class PlayerProfileCubit extends Cubit<PlayerProfileState> {
  PlayerProfileCubit(this._profiles, this._availability, this._catalog, @factoryParam String userId)
    : _userId = userId,
      super(const PlayerProfileState());

  final ProfileRepository _profiles;
  final AvailabilityRepository _availability;
  final CatalogRepository _catalog;
  final String _userId;

  Future<void> load() async {
    emit(const PlayerProfileState());
    final sports = _catalog.getSports();
    final windows = _availability.getForPlayer(_userId);
    final result = await _profiles.getPlayer(_userId);
    // The windows and sport names only add to the page: without them it still shows the profile.
    final available = (await windows).fold((_) => const <AvailabilityWindow>[], (w) => w);
    final names = (await sports).fold((_) => const <String, String>{}, (s) => {for (final x in s) x.code: x.nameFa});
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        PlayerProfileState(
          status: ViewStatus.error,
          notFound: failure is NotFoundFailure,
          errorMessage: failure.message,
        ),
      ),
      (player) =>
          emit(PlayerProfileState(status: ViewStatus.content, player: player, windows: available, sportNames: names)),
    );
  }

  /// The player was blocked together with a report: the screen leaves as after [block].
  void blockedByReport() {
    if (!state.blocked) emit(state.copyWith(blocked: true));
  }

  /// Blocks the player. Once blocked their profile is no longer visible, so the screen leaves.
  Future<void> block() async {
    if (state.blocking || state.blocked) return;
    emit(state.copyWith(blocking: true, errorMessage: () => null));
    final result = await _profiles.blockPlayer(_userId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(blocking: false, errorMessage: () => failure.message)),
      (_) => emit(state.copyWith(blocking: false, blocked: true)),
    );
  }
}

class PlayerProfileState extends Equatable {
  const PlayerProfileState({
    this.status = ViewStatus.loading,
    this.player,
    this.windows = const [],
    this.sportNames = const {},
    this.notFound = false,
    this.blocking = false,
    this.blocked = false,
    this.errorMessage,
  });

  final ViewStatus status;
  final PlayerProfile? player;

  /// Active only.
  final List<AvailabilityWindow> windows;
  final Map<String, String> sportNames;

  /// Blocked, hidden or gone (the server answers all three alike): retrying will not help.
  final bool notFound;
  final bool blocking;
  final bool blocked;

  /// Why loading or blocking failed.
  final String? errorMessage;

  PlayerProfileState copyWith({bool? blocking, bool? blocked, String? Function()? errorMessage}) => PlayerProfileState(
    status: status,
    player: player,
    windows: windows,
    sportNames: sportNames,
    notFound: notFound,
    blocking: blocking ?? this.blocking,
    blocked: blocked ?? this.blocked,
    errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
  );

  @override
  List<Object?> get props => [status, player, windows, sportNames, notFound, blocking, blocked, errorMessage];
}
