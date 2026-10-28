import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/data/match_api.dart';
import 'package:rallyto_app/features/matches/data/match_repository_impl.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';

import '../../../helpers/fake_server.dart';

/// The match calls over the real client stack, against the backend's contract (MatchesController, MatchInput,
/// InvitationInput, MatchView): string enums, Jalali dates in ASCII digits, «HH:mm» times, the envelope.
void main() {
  late FakeServer server;
  late MatchRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = MatchRepositoryImpl(MatchApi(server.dio()));
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  test('reads a match: enums, venue, host, participants, my state, share token and the start instant', () async {
    server.routes['GET /api/v1/matches/m-1'] = (_) => okBody(_matchJson);

    final match = valueOf(await repository.getMatch('m-1'));

    expect(match.visibility, MatchVisibility.public);
    expect(match.status, MatchStatus.open);
    expect(match.sport, const SportRef(id: 's-tennis', code: 'tennis', name: 'تنیس'));
    expect(match.format, PlayFormat.doubles);
    expect(match.capacity, 4);
    expect(match.openSpots, 2);
    expect(match.venue.name, 'باشگاه انقلاب');
    expect(match.date, '1405/08/02');
    expect(match.startTime, '19:00');
    expect(match.endTime, '20:30');
    expect(match.startsAt, DateTime.utc(2026, 10, 24, 15, 30));
    expect(match.host, const HostRef(userId: 'u-1', displayName: 'سارا', level: LevelTier.intermediate));
    expect(match.minLevel, LevelTier.intermediate);
    expect(match.maxLevel, LevelTier.advanced);
    expect(match.partnerGender, PartnerGender.female);
    expect(match.courtBooked, isTrue);
    expect(match.costNote, isNull, reason: 'a blank note is no note');
    expect(match.shareToken, 'a1b2c3d4e5f6a1b2c3d4e5f6');
    expect(match.myState, ParticipantState.host);
    expect(match.participants, const [
      MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
      MatchParticipant(
        userId: 'u-3',
        displayName: 'رضا',
        state: ParticipantState.requested,
        outOfRange: true,
        message: 'سلام، پایه‌ام',
      ),
    ], reason: 'a participant in a state this app does not know is dropped');
  });

  test('a player who is not involved gets no participants and no state', () async {
    server.routes['GET /api/v1/matches/m-1'] = (_) =>
        okBody({..._matchJson, 'participants': null, 'myState': null, 'shareUrl': null});

    final match = valueOf(await repository.getMatch('m-1'));

    expect(match.participants, isNull);
    expect(match.myState, isNull);
    expect(match.shareToken, isNull);
  });

  test('a post sends MatchInput: Jalali date, HH:mm start, string enums, and no blank text', () async {
    server.routes['POST /api/v1/matches/posts'] = (_) => okBody(_matchJson, status: 201);

    final match = valueOf(
      await repository.createPost(
        MatchDraft(
          sportId: 's-tennis',
          venueId: 'v-1',
          format: PlayFormat.singles,
          date: Jalali(1405, 8, 2),
          startMinute: 19 * 60,
          durationMinutes: 90,
          playersBrought: 0,
          minLevel: LevelTier.intermediate,
          maxLevel: LevelTier.advanced,
          partnerGender: PartnerGender.any,
          courtBooked: true,
          costNote: '  ',
          description: ' بازی دوستانه ',
        ),
      ),
    );

    expect(server.lastJson, {
      'sportId': 's-tennis',
      'venueId': 'v-1',
      'format': 'Singles',
      'date': '1405/08/02',
      'startTime': '19:00',
      'durationMinutes': 90,
      'playersBrought': 0,
      'minLevel': 'Intermediate',
      'maxLevel': 'Advanced',
      'partnerGender': 'Any',
      'courtBooked': true,
      'description': 'بازی دوستانه',
    });
    expect(match.id, 'm-1');
  });

  test('an invitation sends InvitationInput with the invitees and the message', () async {
    server.routes['POST /api/v1/matches/invitations'] = (_) => okBody(_matchJson, status: 201);

    await repository.createInvitation(
      InvitationDraft(
        sportId: 's-padel',
        venueId: 'v-2',
        format: PlayFormat.doubles,
        date: Jalali(1405, 8, 9),
        startMinute: 8 * 60 + 30,
        durationMinutes: 120,
        playersBrought: 1,
        invitees: const ['u-2'],
        message: 'بیا بازی',
      ),
    );

    expect(server.lastJson, {
      'sportId': 's-padel',
      'venueId': 'v-2',
      'format': 'Doubles',
      'date': '1405/08/09',
      'startTime': '08:30',
      'durationMinutes': 120,
      'playersBrought': 1,
      'invitees': ['u-2'],
      'message': 'بیا بازی',
    });
  });

  test('my matches ask for their scope', () async {
    server.routes['GET /api/v1/matches/mine'] = (_) => okBody([_matchJson]);

    expect(valueOf(await repository.getMine(upcoming: true)), hasLength(1));
    await repository.getMine(upcoming: false);

    expect(server.requests[0].queryParameters, {'scope': 'upcoming'});
    expect(server.requests[1].queryParameters, {'scope': 'past'});
  });

  test('a share token opens its game; a regenerated or hidden one is MATCH_NOT_AVAILABLE', () async {
    server.routes['GET /api/v1/matches/by-token/a1b2'] = (_) => okBody(_matchJson);
    server.routes['GET /api/v1/matches/by-token/old'] = (_) =>
        errorBody(404, 'MATCH_NOT_AVAILABLE', 'این بازی در دسترس نیست.');

    expect(valueOf(await repository.getByShareToken('a1b2')).id, 'm-1');
    final failure = failureOf(await repository.getByShareToken('old'));

    expect(failure, isA<NotFoundFailure>());
    expect(failure.code, 'MATCH_NOT_AVAILABLE');
  });

  test('join always sends a body, with the message only when there is one', () async {
    server.routes['POST /api/v1/matches/m-1/join'] = (_) => okBody(_matchJson);

    await repository.join('m-1', message: ' سلام ');
    expect(server.lastJson, {'message': 'سلام'});
    await repository.join('m-1');
    expect(server.lastJson, <String, dynamic>{});
  });

  test('cancel sends the reason; invite sends the player ids', () async {
    server.routes['POST /api/v1/matches/m-1/cancel'] = (_) => okBody({..._matchJson, 'status': 'Cancelled'});
    server.routes['POST /api/v1/matches/m-1/invite'] = (_) => okBody(_matchJson);

    expect(valueOf(await repository.cancel('m-1', reason: 'باران')).status, MatchStatus.cancelled);
    expect(server.lastJson, {'reason': 'باران'});
    server.routes['POST /api/v1/matches/m-1/cancel'] = (_) =>
        okBody({..._matchJson, 'status': 'Cancelled', 'cancelReason': 'باران'});
    expect(
      valueOf(await repository.cancel('m-1', reason: 'باران')).cancelReason,
      'باران',
      reason: 'MatchView.cancelReason',
    );
    await repository.cancel('m-1', reason: '  ');
    expect(server.lastJson, <String, dynamic>{});
    await repository.invite('m-1', ['u-2', 'u-3']);
    expect(server.lastJson, {
      'playerIds': ['u-2', 'u-3'],
    });
  });

  test('every other action goes to its own path', () async {
    for (final path in [
      'withdraw',
      'requests/u-3/accept',
      'requests/u-3/decline',
      'invitation/accept',
      'invitation/decline',
      'confirm',
      'leave',
      'participants/u-2/remove',
      'share-token',
    ]) {
      server.routes['POST /api/v1/matches/m-1/$path'] = (_) => okBody(_matchJson);
    }

    await repository.withdraw('m-1');
    await repository.answerRequest('m-1', 'u-3', accept: true);
    await repository.answerRequest('m-1', 'u-3', accept: false);
    await repository.answerInvitation('m-1', accept: true);
    await repository.answerInvitation('m-1', accept: false);
    await repository.confirmEarly('m-1');
    await repository.leave('m-1');
    await repository.removeParticipant('m-1', 'u-2');
    await repository.regenerateShareToken('m-1');

    expect(server.calls, [
      'POST /api/v1/matches/m-1/withdraw',
      'POST /api/v1/matches/m-1/requests/u-3/accept',
      'POST /api/v1/matches/m-1/requests/u-3/decline',
      'POST /api/v1/matches/m-1/invitation/accept',
      'POST /api/v1/matches/m-1/invitation/decline',
      'POST /api/v1/matches/m-1/confirm',
      'POST /api/v1/matches/m-1/leave',
      'POST /api/v1/matches/m-1/participants/u-2/remove',
      'POST /api/v1/matches/m-1/share-token',
    ]);
  });

  test('attendance: posts the answer and the no-shows, and reads the attendance view and outcomes', () async {
    server.routes['POST /api/v1/matches/m-1/attendance'] = (_) => okBody({
      ..._matchJson,
      'status': 'Completed',
      'participants': [
        {'userId': 'u-1', 'displayName': 'سارا', 'state': 'Host', 'outOfRange': false, 'outcome': 'Played'},
        {'userId': 'u-3', 'displayName': 'رضا', 'state': 'Accepted', 'outOfRange': false, 'outcome': 'NoShow'},
        {'userId': 'u-4', 'displayName': 'مینا', 'state': 'Accepted', 'outOfRange': false, 'outcome': 'Contested'},
      ],
      'attendance': {
        'open': false,
        'closesAt': '2026-10-25T17:00:00Z',
        'myAnswer': 'Played',
        'myOutcome': 'Played',
        'resolvedAt': '2026-10-23T08:00:00Z',
        'canRate': ['u-4'],
      },
    });

    final match = valueOf(await repository.answerAttendance('m-1', AttendanceAnswer.played, noShowPlayerIds: ['u-3']));

    expect(server.calls.last, 'POST /api/v1/matches/m-1/attendance');
    expect(server.lastJson, {
      'answer': 'Played',
      'noShowPlayerIds': ['u-3'],
    });
    expect(match.status, MatchStatus.completed);
    expect(
      match.attendance,
      MatchAttendance(
        open: false,
        closesAt: DateTime.utc(2026, 10, 25, 17),
        myAnswer: AttendanceAnswer.played,
        myOutcome: AttendanceOutcome.played,
        resolvedAt: DateTime.utc(2026, 10, 23, 8),
        canRate: const ['u-4'],
      ),
    );
    expect(match.participants!.map((p) => p.outcome), [
      AttendanceOutcome.played,
      AttendanceOutcome.noShow,
      AttendanceOutcome.contested,
    ]);
    expect(match.rateablePlayers.map((p) => p.userId), ['u-4']);
  });

  test('"did not happen" goes with an empty no-show list; a game not ended has no attendance', () async {
    server.routes['POST /api/v1/matches/m-1/attendance'] = (_) => okBody(_matchJson);

    final match = valueOf(await repository.answerAttendance('m-1', AttendanceAnswer.didNotHappen));

    expect(server.lastJson, {'answer': 'DidNotHappen', 'noShowPlayerIds': <String>[]});
    expect(match.attendance, isNull);
    expect(match.participants!.first.outcome, isNull);
  });

  test('attendance refusals keep their codes', () async {
    for (final (status, code) in [
      (409, 'ATTENDANCE_NOT_OPEN'),
      (409, 'ATTENDANCE_CLOSED'),
      (409, 'ALREADY_ANSWERED'),
      (422, 'INVALID_NO_SHOW'),
    ]) {
      server.routes['POST /api/v1/matches/m-1/attendance'] = (_) => errorBody(status, code, 'x');
      expect(failureOf(await repository.answerAttendance('m-1', AttendanceAnswer.played)).code, code);
    }
  });

  test("a refusal keeps the server's code: 409 SCHEDULE_CONFLICT, 400 START_TOO_SOON", () async {
    server.routes['POST /api/v1/matches/m-1/join'] = (_) =>
        errorBody(409, 'SCHEDULE_CONFLICT', 'در این زمان بازی دیگری دارید.');
    server.routes['POST /api/v1/matches/posts'] = (_) =>
        errorBody(400, 'START_TOO_SOON', 'زمان شروع باید دست‌کم ۳۰ دقیقه بعد باشد.');

    final conflict = failureOf(await repository.join('m-1'));
    expect(conflict.code, 'SCHEDULE_CONFLICT');
    expect((conflict as ServerFailure).statusCode, 409);

    final tooSoon = failureOf(
      await repository.createPost(
        MatchDraft(
          sportId: 's-tennis',
          venueId: 'v-1',
          format: PlayFormat.singles,
          date: Jalali(1405, 8, 1),
          startMinute: 12 * 60,
          durationMinutes: 90,
          playersBrought: 0,
          partnerGender: PartnerGender.any,
        ),
      ),
    );
    expect(tooSoon, isA<ValidationFailure>());
    expect(tooSoon.code, 'START_TOO_SOON');
  });
}

const Map<String, Object?> _matchJson = {
  'id': 'm-1',
  'visibility': 'Public',
  'status': 'Open',
  'sport': {'id': 's-tennis', 'code': 'tennis', 'name': 'تنیس'},
  'format': 'Doubles',
  'capacity': 4,
  'openSpots': 2,
  'venue': {'id': 'v-1', 'name': 'باشگاه انقلاب'},
  'date': '1405/08/02',
  'startTime': '19:00',
  'endTime': '20:30',
  'durationMinutes': 90,
  'startsAt': '2026-10-24T15:30:00Z',
  'host': {'userId': 'u-1', 'displayName': 'سارا', 'level': 'Intermediate'},
  'minLevel': 'Intermediate',
  'maxLevel': 'Advanced',
  'partnerGender': 'Female',
  'courtBooked': true,
  'costNote': ' ',
  'description': 'بازی دوستانه',
  'playersBrought': 1,
  'shareUrl': 'https://rallyto.ir/m/a1b2c3d4e5f6a1b2c3d4e5f6',
  'participants': [
    {'userId': 'u-1', 'displayName': 'سارا', 'state': 'Host', 'outOfRange': false, 'message': null},
    {'userId': 'u-3', 'displayName': 'رضا', 'state': 'Requested', 'outOfRange': true, 'message': 'سلام، پایه‌ام'},
    {'userId': 'u-5', 'displayName': 'ناشناس', 'state': 'SomethingNew', 'outOfRange': false, 'message': null},
  ],
  'myState': 'Host',
};
