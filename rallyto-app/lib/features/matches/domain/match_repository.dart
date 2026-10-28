import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/match.dart';

/// Play posts, invitations and the games the player is in. Nothing is cached: every action answers with the whole
/// updated game. Refusals carry the server's code ([MatchErrorCodes]).
abstract class MatchRepository {
  /// A public play post. `TOO_MANY_OPEN_POSTS`, `START_TOO_SOON`, `FORMAT_NOT_ALLOWED`, … when refused.
  Future<Either<Failure, Match>> createPost(MatchDraft draft);

  /// A private game with invitees. `PLAYER_NOT_FOUND` for an invitee who cannot be seen, `INVITEE_DOES_NOT_PLAY`.
  Future<Either<Failure, Match>> createInvitation(InvitationDraft draft);

  /// Upcoming games soonest first, or past games newest first.
  Future<Either<Failure, List<Match>>> getMine({required bool upcoming});

  /// A `NotFoundFailure` (`MATCH_NOT_FOUND`) for a game the player may not see.
  Future<Either<Failure, Match>> getMatch(String id);

  /// The game behind a share token; `MATCH_NOT_AVAILABLE` when it is gone, hidden, or the token was regenerated.
  Future<Either<Failure, Match>> getByShareToken(String token);

  Future<Either<Failure, Match>> join(String id, {String? message});

  Future<Either<Failure, Match>> withdraw(String id);

  Future<Either<Failure, Match>> answerRequest(String id, String playerId, {required bool accept});

  /// Invites players into the host's own game.
  Future<Either<Failure, Match>> invite(String id, List<String> playerIds);

  Future<Either<Failure, Match>> answerInvitation(String id, {required bool accept});

  Future<Either<Failure, Match>> confirmEarly(String id);

  Future<Either<Failure, Match>> leave(String id);

  Future<Either<Failure, Match>> removeParticipant(String id, String playerId);

  Future<Either<Failure, Match>> cancel(String id, {String? reason});

  /// A new share token: the old link stops working.
  Future<Either<Failure, Match>> regenerateShareToken(String id);

  /// This player's answer once the game ended, with the other players they flag as no-shows (only with
  /// [AttendanceAnswer.played]). `ATTENDANCE_NOT_OPEN`, `ATTENDANCE_CLOSED`, `ALREADY_ANSWERED`, `INVALID_NO_SHOW`.
  Future<Either<Failure, Match>> answerAttendance(
    String id,
    AttendanceAnswer answer, {
    List<String> noShowPlayerIds = const [],
  });
}
