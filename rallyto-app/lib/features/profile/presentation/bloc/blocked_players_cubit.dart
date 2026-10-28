import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/profile_repository.dart';
import 'my_profile_cubit.dart';

/// The players this player blocked, each with an unblock action.
@injectable
class BlockedPlayersCubit extends Cubit<BlockedPlayersState> {
  BlockedPlayersCubit(this._profiles) : super(const BlockedPlayersState());

  final ProfileRepository _profiles;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _profiles.getBlockedPlayers();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: ViewStatus.error, errorMessage: failure.message)),
      (players) =>
          emit(state.copyWith(status: players.isEmpty ? ViewStatus.empty : ViewStatus.content, players: players)),
    );
  }

  /// Unblocks [player]: gone from the list once the server agrees.
  Future<void> unblock(BlockedPlayer player) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: () => player.userId));
    final result = await _profiles.unblockPlayer(player.userId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          busyId: () => null,
          feedback: ProfileFeedback(failure.message, isError: true, code: failure.code),
        ),
      ),
      (_) {
        final players = [...state.players.where((p) => p.userId != player.userId)];
        emit(
          state.copyWith(
            busyId: () => null,
            players: players,
            status: players.isEmpty ? ViewStatus.empty : ViewStatus.content,
            feedback: ProfileFeedback(AppStrings.unblocked(player.displayName)),
          ),
        );
      },
    );
  }
}

class BlockedPlayersState extends Equatable {
  const BlockedPlayersState({
    this.status = ViewStatus.loading,
    this.players = const [],
    this.busyId,
    this.errorMessage,
    this.feedback,
  });

  final ViewStatus status;
  final List<BlockedPlayer> players;

  /// The player being unblocked.
  final String? busyId;
  final String? errorMessage;
  final ProfileFeedback? feedback;

  BlockedPlayersState copyWith({
    ViewStatus? status,
    List<BlockedPlayer>? players,
    String? Function()? busyId,
    String? errorMessage,
    ProfileFeedback? feedback,
  }) => BlockedPlayersState(
    status: status ?? this.status,
    players: players ?? this.players,
    busyId: busyId == null ? this.busyId : busyId(),
    errorMessage: errorMessage ?? this.errorMessage,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, players, busyId, errorMessage, feedback];
}
