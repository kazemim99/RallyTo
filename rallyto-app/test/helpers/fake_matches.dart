import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/domain/match_repository.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_detail_cubit.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';

import 'fake_catalog.dart';
import 'fake_chat.dart';
import 'fake_share.dart';

/// A [MatchRepository] answering from what the test set, recording what it was asked.
class FakeMatchRepository implements MatchRepository {
  Match match = testMatch();
  List<Match> upcoming = [testMatch(id: 'm-1'), testMatch(id: 'm-2', status: MatchStatus.confirmed)];
  List<Match> past = [testMatch(id: 'm-9', status: MatchStatus.completed)];

  /// When set, the next call answers with it instead of succeeding.
  Failure? failure;

  /// When set, only reads (getMatch, getByShareToken, getMine) fail with it.
  Failure? loadFailure;

  /// What the next successful action answers with; [match] when null.
  Match? next;

  final List<MatchDraft> posts = [];
  final List<InvitationDraft> invitations = [];
  final List<String> calls = [];

  @override
  Future<Either<Failure, Match>> createPost(MatchDraft draft) async {
    posts.add(draft);
    return _answer('createPost');
  }

  @override
  Future<Either<Failure, Match>> createInvitation(InvitationDraft draft) async {
    invitations.add(draft);
    return _answer('createInvitation');
  }

  @override
  Future<Either<Failure, List<Match>>> getMine({required bool upcoming}) async {
    calls.add('getMine:${upcoming ? 'upcoming' : 'past'}');
    final failure = loadFailure;
    if (failure != null) return Left(failure);
    return Right(upcoming ? this.upcoming : past);
  }

  @override
  Future<Either<Failure, Match>> getMatch(String id) async {
    calls.add('getMatch:$id');
    final failure = loadFailure;
    return failure == null ? Right(match) : Left(failure);
  }

  @override
  Future<Either<Failure, Match>> getByShareToken(String token) async {
    calls.add('getByShareToken:$token');
    final failure = loadFailure;
    return failure == null ? Right(match) : Left(failure);
  }

  @override
  Future<Either<Failure, Match>> join(String id, {String? message}) => _answer('join:$id:${message ?? ''}');

  @override
  Future<Either<Failure, Match>> withdraw(String id) => _answer('withdraw:$id');

  @override
  Future<Either<Failure, Match>> answerRequest(String id, String playerId, {required bool accept}) =>
      _answer('${accept ? 'acceptRequest' : 'declineRequest'}:$id:$playerId');

  @override
  Future<Either<Failure, Match>> invite(String id, List<String> playerIds) =>
      _answer('invite:$id:${playerIds.join(',')}');

  @override
  Future<Either<Failure, Match>> answerInvitation(String id, {required bool accept}) =>
      _answer('${accept ? 'acceptInvitation' : 'declineInvitation'}:$id');

  @override
  Future<Either<Failure, Match>> confirmEarly(String id) => _answer('confirm:$id');

  @override
  Future<Either<Failure, Match>> leave(String id) => _answer('leave:$id');

  @override
  Future<Either<Failure, Match>> removeParticipant(String id, String playerId) => _answer('remove:$id:$playerId');

  @override
  Future<Either<Failure, Match>> cancel(String id, {String? reason}) => _answer('cancel:$id:${reason ?? ''}');

  @override
  Future<Either<Failure, Match>> regenerateShareToken(String id) => _answer('shareToken:$id');

  @override
  Future<Either<Failure, Match>> answerAttendance(
    String id,
    AttendanceAnswer answer, {
    List<String> noShowPlayerIds = const [],
  }) => _answer('attendance:$id:${answer.wire}:${noShowPlayerIds.join(',')}');

  Future<Either<Failure, Match>> _answer(String call) async {
    calls.add(call);
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return Right(next ?? match);
  }
}

/// Saturday 1405/08/02, 19:00 in Tehran (15:30 UTC): the day after the tests' "now" (Friday 1405/08/01, 11:30).
final DateTime testStartsAt = DateTime.utc(2026, 10, 24, 15, 30);

/// Friday 1405/08/01, 11:30 in Tehran.
final DateTime testNow = DateTime.utc(2026, 10, 23, 8);

/// A public tennis singles post at باشگاه انقلاب, hosted by «سارا». [participants] null: a player who is not involved.
Match testMatch({
  String id = 'm-1',
  MatchStatus status = MatchStatus.open,
  MatchVisibility visibility = MatchVisibility.public,
  int capacity = 2,
  int openSpots = 1,
  DateTime? startsAt,
  ParticipantState? myState,
  List<MatchParticipant>? participants,
  int playersBrought = 0,
  String? shareUrl = 'https://rallyto.ir/m/abc123def456',
  PlayFormat format = PlayFormat.singles,
  String? cancelReason,
  MatchAttendance? attendance,
}) => Match(
  id: id,
  visibility: visibility,
  status: status,
  sport: const SportRef(id: 's-tennis', code: 'tennis', name: 'تنیس'),
  format: format,
  capacity: capacity,
  openSpots: openSpots,
  venue: const NamedRef(id: 'v-1', name: 'باشگاه انقلاب'),
  date: '1405/08/02',
  startTime: '19:00',
  endTime: '20:30',
  durationMinutes: 90,
  startsAt: startsAt ?? testStartsAt,
  host: const HostRef(userId: 'u-1', displayName: 'سارا', level: LevelTier.intermediate),
  minLevel: LevelTier.lowerIntermediate,
  maxLevel: LevelTier.advanced,
  partnerGender: PartnerGender.any,
  courtBooked: true,
  costNote: 'نصف نصف',
  description: 'بازی دوستانه',
  playersBrought: playersBrought,
  shareUrl: visibility == MatchVisibility.public ? shareUrl : null,
  participants: participants,
  myState: myState,
  cancelReason: cancelReason,
  attendance: attendance,
);

/// The host's view: the host, one accepted player, and two join requests (one out of range).
Match testHostedMatch({
  MatchStatus status = MatchStatus.open,
  int capacity = 4,
  int openSpots = 2,
  DateTime? startsAt,
  List<MatchParticipant>? participants,
}) => testMatch(
  status: status,
  capacity: capacity,
  openSpots: openSpots,
  startsAt: startsAt,
  format: PlayFormat.doubles,
  myState: ParticipantState.host,
  participants:
      participants ??
      const [
        MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
        MatchParticipant(userId: 'u-2', displayName: 'علی', state: ParticipantState.accepted),
        MatchParticipant(
          userId: 'u-3',
          displayName: 'رضا',
          state: ParticipantState.requested,
          message: 'سلام، پایه‌ام',
        ),
        MatchParticipant(userId: 'u-4', displayName: 'مینا', state: ParticipantState.requested, outOfRange: true),
      ],
);

/// A [MatchDetailCubit] over [matches], the fake catalog, [chat] (no group conversations unless given), this player
/// «u-me» and [share], at the tests' "now".
MatchDetailCubit matchDetailCubit(
  FakeMatchRepository matches, {
  MatchRef ref = const MatchRef.id('m-1'),
  DateTime? now,
  FakeChatRepository? chat,
  FakeShareService? share,
  String? me = 'u-me',
}) => MatchDetailCubit(
  matches,
  FakeCatalogRepository(),
  chat ?? (FakeChatRepository()..matchGroups = {}),
  FakeCurrentUser(me),
  share ?? FakeShareService(),
  ref,
  clock: () => now ?? testNow,
);

/// The end of the ended game below: Thursday 1405/07/30, 20:30 in Tehran.
final DateTime testEndedAt = DateTime.utc(2026, 10, 22, 17);

/// A padel doubles game that ended yesterday, hosted by «سارا», with this player («u-me») and two others playing.
/// [attendance] defaults to the open question, not yet answered.
Match testEndedMatch({
  MatchStatus status = MatchStatus.confirmed,
  MatchAttendance? attendance,
  List<MatchParticipant>? participants,
}) => testMatch(
  status: status,
  capacity: 4,
  openSpots: 0,
  format: PlayFormat.doubles,
  startsAt: DateTime.utc(2026, 10, 22, 15, 30),
  myState: ParticipantState.accepted,
  participants:
      participants ??
      const [
        MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
        MatchParticipant(userId: 'u-me', displayName: 'من', state: ParticipantState.accepted),
        MatchParticipant(userId: 'u-3', displayName: 'رضا', state: ParticipantState.accepted),
        MatchParticipant(userId: 'u-4', displayName: 'مینا', state: ParticipantState.accepted),
      ],
  attendance: attendance ?? MatchAttendance(open: true, closesAt: testEndedAt.add(const Duration(hours: 72))),
);
