import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/api/models/api_response.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/match.dart';
import '../domain/match_repository.dart';
import 'match_api.dart';
import 'models/match_models.dart';

/// [MatchRepository] over [MatchApi]. Nothing is cached.
@LazySingleton(as: MatchRepository)
class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl(this._api);

  final MatchApi _api;

  @override
  Future<Either<Failure, Match>> createPost(MatchDraft draft) =>
      _one(() => _api.createPost(MatchInputModel.fromDraft(draft)));

  @override
  Future<Either<Failure, Match>> createInvitation(InvitationDraft draft) =>
      _one(() => _api.createInvitation(InvitationInputModel.fromDraft(draft)));

  @override
  Future<Either<Failure, List<Match>>> getMine({required bool upcoming}) async {
    final result = await safeApiCall(() => _api.mine(upcoming ? 'upcoming' : 'past'));
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }

  @override
  Future<Either<Failure, Match>> getMatch(String id) => _one(() => _api.get(id));

  @override
  Future<Either<Failure, Match>> getByShareToken(String token) => _one(() => _api.byToken(token));

  @override
  Future<Either<Failure, Match>> join(String id, {String? message}) {
    final text = message?.trim();
    return _one(() => _api.join(id, JoinRequestModel(message: text == null || text.isEmpty ? null : text)));
  }

  @override
  Future<Either<Failure, Match>> withdraw(String id) => _one(() => _api.withdraw(id));

  @override
  Future<Either<Failure, Match>> answerRequest(String id, String playerId, {required bool accept}) =>
      _one(() => accept ? _api.acceptRequest(id, playerId) : _api.declineRequest(id, playerId));

  @override
  Future<Either<Failure, Match>> invite(String id, List<String> playerIds) =>
      _one(() => _api.invite(id, InviteRequestModel(playerIds: playerIds)));

  @override
  Future<Either<Failure, Match>> answerInvitation(String id, {required bool accept}) =>
      _one(() => accept ? _api.acceptInvitation(id) : _api.declineInvitation(id));

  @override
  Future<Either<Failure, Match>> confirmEarly(String id) => _one(() => _api.confirm(id));

  @override
  Future<Either<Failure, Match>> leave(String id) => _one(() => _api.leave(id));

  @override
  Future<Either<Failure, Match>> removeParticipant(String id, String playerId) =>
      _one(() => _api.removeParticipant(id, playerId));

  @override
  Future<Either<Failure, Match>> cancel(String id, {String? reason}) {
    final text = reason?.trim();
    return _one(() => _api.cancel(id, CancelRequestModel(reason: text == null || text.isEmpty ? null : text)));
  }

  @override
  Future<Either<Failure, Match>> regenerateShareToken(String id) => _one(() => _api.regenerateShareToken(id));

  @override
  Future<Either<Failure, Match>> answerAttendance(
    String id,
    AttendanceAnswer answer, {
    List<String> noShowPlayerIds = const [],
  }) => _one(
    () => _api.answerAttendance(id, AttendanceRequestModel(answer: answer.wire, noShowPlayerIds: noShowPlayerIds)),
  );

  Future<Either<Failure, Match>> _one(Future<ApiResponse<MatchViewModel>> Function() request) async {
    final result = await safeApiCall(request);
    return result.map((model) => model.toEntity());
  }
}
