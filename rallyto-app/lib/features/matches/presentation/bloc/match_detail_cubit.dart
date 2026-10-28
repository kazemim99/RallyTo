import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/auth/current_user.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/share/share_service.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../chat/domain/chat_repository.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/match.dart';
import '../../domain/match_repository.dart';
import '../../domain/match_rules.dart';
import '../match_labels.dart';

/// Which game a detail screen shows: by id, or by the token of a share link.
class MatchRef extends Equatable {
  const MatchRef.id(String this.id) : token = null;

  const MatchRef.token(String this.token) : id = null;

  final String? id;
  final String? token;

  @override
  List<Object?> get props => [id, token];
}

/// One game and everything the player can do in it: join with a message, withdraw, answer an invitation, leave; and
/// for the host, answer requests, confirm early, remove a participant, cancel with a reason and regenerate the share
/// link. Once the game ended, its players answer whether it was played (flagging no-shows). A public post's link goes
/// to the share sheet. Every action answers with the whole updated game, which replaces the one shown, and ends in
/// feedback. For a player in the game, the server is asked whether it has a group conversation.
@injectable
class MatchDetailCubit extends Cubit<MatchDetailState> {
  MatchDetailCubit(
    this._matches,
    this._catalog,
    this._chat,
    this._currentUser,
    this._share,
    @factoryParam MatchRef ref, {
    @ignoreParam DateTime Function()? clock,
  }) : _ref = ref,
       _clock = clock ?? DateTime.now,
       super(const MatchDetailState());

  final MatchRepository _matches;
  final CatalogRepository _catalog;
  final ChatRepository _chat;
  final CurrentUser _currentUser;
  final ShareService _share;
  final MatchRef _ref;
  final DateTime Function() _clock;

  /// The current instant: what the actions offered depend on (a started game takes none).
  DateTime get now => _clock().toUtc();

  Future<void> load() async {
    emit(const MatchDetailState());
    final sports = _catalog.getSports();
    final token = _ref.token;
    final result = token != null ? await _matches.getByShareToken(token) : await _matches.getMatch(_ref.id ?? '');
    final catalog = (await sports).fold((_) => const <Sport>[], (s) => s);
    final me = await _currentUser.id();
    if (isClosed) return;
    final match = result.fold((_) => null, (m) => m);
    if (match == null) {
      final failure = result.fold((f) => f, (_) => null)!;
      emit(
        MatchDetailState(
          status: ViewStatus.error,
          notFound: failure is NotFoundFailure,
          errorMessage: MatchLabels.error(failure),
        ),
      );
      return;
    }
    emit(MatchDetailState(status: ViewStatus.content, match: match, sports: catalog, myId: me));
    await _findGroupChat(match);
  }

  /// Asks the server for the game's group conversation, for a player in the game who does not have it yet. Only
  /// adds to the screen: without an answer there is no group chat button.
  Future<void> _findGroupChat(Match match) async {
    if (match.participants == null || state.groupChatId != null) return;
    final result = await _chat.getMatchConversation(match.id);
    if (isClosed) return;
    final id = result.fold((_) => null, (c) => c.id);
    if (id != null) emit(state.copyWith(groupChatId: id));
  }

  /// This player's answer once the game ended. [noShows] are other players who did not come: only with
  /// [AttendanceAnswer.played].
  Future<void> answerAttendance(AttendanceAnswer answer, {Set<String> noShows = const {}}) async {
    if (noShows.isNotEmpty && (answer != AttendanceAnswer.played || noShows.contains(state.myId))) {
      _say(MatchLabels.rule(MatchErrorCodes.invalidNoShow), isError: true, code: MatchErrorCodes.invalidNoShow);
      return;
    }
    await _act(
      (id) => _matches.answerAttendance(id, answer, noShowPlayerIds: noShows.toList()),
      AppStrings.attendanceSaved,
    );
  }

  /// Opens the share sheet with the post's link and a short Persian line about the game.
  Future<void> share() async {
    final match = state.match;
    if (match?.shareUrl == null) return;
    try {
      await _share.shareText(MatchLabels.shareText(match!), subject: AppStrings.shareSubject);
    } catch (_) {
      _say(AppStrings.shareFailed, isError: true);
    }
  }

  /// A join request; [message] is optional, at most 200 characters.
  Future<void> join({String? message}) async {
    if ((message?.trim().length ?? 0) > MatchRules.maxMessageLength) {
      _say(MatchLabels.rule(MatchErrorCodes.messageTooLong), isError: true, code: MatchErrorCodes.messageTooLong);
      return;
    }
    await _act((id) => _matches.join(id, message: message), AppStrings.joinRequested);
  }

  Future<void> withdraw() => _act(_matches.withdraw, AppStrings.requestWithdrawn);

  Future<void> acceptRequest(String playerId) =>
      _act((id) => _matches.answerRequest(id, playerId, accept: true), AppStrings.requestAccepted);

  Future<void> declineRequest(String playerId) =>
      _act((id) => _matches.answerRequest(id, playerId, accept: false), AppStrings.requestDeclined);

  Future<void> acceptInvitation() =>
      _act((id) => _matches.answerInvitation(id, accept: true), AppStrings.invitationAccepted);

  Future<void> declineInvitation() =>
      _act((id) => _matches.answerInvitation(id, accept: false), AppStrings.invitationDeclined);

  Future<void> confirmEarly() => _act(_matches.confirmEarly, AppStrings.matchConfirmed);

  Future<void> leave() => _act(_matches.leave, AppStrings.matchLeft);

  Future<void> removeParticipant(String playerId) =>
      _act((id) => _matches.removeParticipant(id, playerId), AppStrings.participantRemovedDone);

  Future<void> cancel({String? reason}) => _act((id) => _matches.cancel(id, reason: reason), AppStrings.matchCancelled);

  Future<void> regenerateShareToken() => _act(_matches.regenerateShareToken, AppStrings.linkRegenerated);

  /// The share link was copied to the clipboard.
  void linkCopied() => _say(AppStrings.linkCopied);

  /// Whether leaving or cancelling now counts as a late cancellation, so the player is warned first.
  bool get isLateCancellation {
    final match = state.match;
    return match != null && MatchRules.isLateCancellation(match, now);
  }

  Future<void> _act(Future<Either<Failure, Match>> Function(String id) action, String done) async {
    final match = state.match;
    if (match == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final result = await action(match.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          busy: false,
          feedback: ProfileFeedback(MatchLabels.error(failure), isError: true, code: failure.code),
        ),
      ),
      (updated) => emit(state.copyWith(busy: false, match: updated, feedback: ProfileFeedback(done))),
    );
    // An accepted request can complete the group: look again.
    final updated = state.match;
    if (result.isRight() && updated != null) await _findGroupChat(updated);
  }

  void _say(String message, {bool isError = false, String? code}) => emit(
    state.copyWith(
      feedback: ProfileFeedback(message, isError: isError, code: code),
    ),
  );
}

class MatchDetailState extends Equatable {
  const MatchDetailState({
    this.status = ViewStatus.loading,
    this.match,
    this.sports = const [],
    this.notFound = false,
    this.busy = false,
    this.errorMessage,
    this.feedback,
    this.myId,
    this.groupChatId,
  });

  final ViewStatus status;
  final Match? match;

  /// The catalog's sports, for level names.
  final List<Sport> sports;

  /// Not found, private, hidden, or a regenerated share link (the server answers all alike): retrying will not help.
  final bool notFound;

  /// An action is on its way; another is not started until it answers.
  final bool busy;
  final String? errorMessage;

  /// The latest action's outcome.
  final ProfileFeedback? feedback;

  /// This player's user id: who they are among the participants.
  final String? myId;

  /// The game's group conversation, once the server said there is one for this player.
  final String? groupChatId;

  /// The game's sport from the catalog, or null when it is not loaded.
  Sport? get sport {
    final id = match?.sport.id;
    for (final sport in sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  MatchDetailState copyWith({Match? match, bool? busy, ProfileFeedback? feedback, String? groupChatId}) =>
      MatchDetailState(
        status: status,
        match: match ?? this.match,
        sports: sports,
        notFound: notFound,
        busy: busy ?? this.busy,
        errorMessage: errorMessage,
        feedback: feedback ?? this.feedback,
        myId: myId,
        groupChatId: groupChatId ?? this.groupChatId,
      );

  @override
  List<Object?> get props => [status, match, sports, notFound, busy, errorMessage, feedback, myId, groupChatId];
}
