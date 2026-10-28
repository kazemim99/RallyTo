import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/domain/match_rules.dart';

import '../../../helpers/fake_catalog.dart';
import '../../../helpers/fake_matches.dart';

/// The game rules mirrored from the server (spec play-posts, spec match-lifecycle), and what each player may do in a
/// game depending on its state, their place in it and the time.
void main() {
  group('capacity and spots', () {
    test('capacity comes from the catalog: singles 2, doubles 4', () {
      expect(MatchRules.capacityOf(tennis(), PlayFormat.singles), 2);
      expect(MatchRules.capacityOf(tennis(), PlayFormat.doubles), 4);
      expect(MatchRules.capacityOf(null, PlayFormat.doubles), 4, reason: 'without the catalog, by the format');
    });

    test('open spots are capacity − 1 − players brought; at most capacity − 2 may be brought', () {
      expect(MatchRules.openSpots(2, 0), 1, reason: 'tennis singles');
      expect(MatchRules.openSpots(4, 1), 2, reason: 'padel with a friend');
      expect(MatchRules.openSpots(4, 0), 3, reason: 'badminton doubles, nobody brought');
      expect(MatchRules.maxPlayersBrought(2), 0);
      expect(MatchRules.maxPlayersBrought(4), 2);
    });

    test("the default duration is the sport's session length, 60–240 minutes in 30-minute steps", () {
      expect(MatchRules.defaultDuration(tennis()), 90);
      expect(MatchRules.durationOptions, [60, 90, 120, 150, 180, 210, 240]);
      expect(MatchRules.startOptions.first, 0);
      expect(MatchRules.startOptions.last, 23 * 60 + 30);
    });
  });

  group('start time', () {
    // Friday 1405/08/01, 11:30 in Tehran.
    final now = testNow;

    test('the instant is read on Tehran\'s clock', () {
      expect(MatchRules.startInstant(Jalali(1405, 8, 2), 19 * 60), DateTime.utc(2026, 10, 24, 15, 30));
    });

    test('a start between 30 minutes and 30 days from now', () {
      expect(MatchRules.checkStart(Jalali(1405, 8, 2), 19 * 60, now), isNull);
      expect(MatchRules.checkStart(Jalali(1405, 8, 1), 12 * 60, now), isNull, reason: 'exactly 30 minutes ahead');
      expect(MatchRules.checkStart(Jalali(1405, 8, 1), 11 * 60 + 30, now), MatchErrorCodes.startTooSoon);
      expect(MatchRules.checkStart(Jalali(1405, 7, 30), 19 * 60, now), MatchErrorCodes.startTooSoon);
      expect(MatchRules.checkStart(Jalali(1405, 9, 1), 11 * 60, now), isNull, reason: '30 days ahead, earlier hour');
      expect(MatchRules.checkStart(Jalali(1405, 9, 2), 12 * 60, now), MatchErrorCodes.startTooFar);
    });
  });

  group('late cancellation', () {
    test('only a confirmed game starting within 12 hours', () {
      final soon = testNow.add(const Duration(hours: 5));
      final later = testNow.add(const Duration(days: 2));
      expect(MatchRules.isLateCancellation(testMatch(status: MatchStatus.confirmed, startsAt: soon), testNow), isTrue);
      expect(
        MatchRules.isLateCancellation(testMatch(status: MatchStatus.confirmed, startsAt: later), testNow),
        isFalse,
      );
      expect(MatchRules.isLateCancellation(testMatch(status: MatchStatus.open, startsAt: soon), testNow), isFalse);
    });
  });

  group('share links', () {
    test('the token from a whole link, a path, or the bare token', () {
      expect(ShareLinks.tokenOf('https://rallyto.ir/m/a1b2c3d4e5f6'), 'a1b2c3d4e5f6');
      expect(ShareLinks.tokenOf('  https://rallyto.ir/m/a1b2c3d4e5f6?utm=tg#x '), 'a1b2c3d4e5f6');
      expect(ShareLinks.tokenOf('/m/a1b2c3d4e5f6'), 'a1b2c3d4e5f6');
      expect(ShareLinks.tokenOf('a1b2c3d4e5f6'), 'a1b2c3d4e5f6');
      expect(ShareLinks.tokenOf('سلام'), isNull);
      expect(ShareLinks.tokenOf('https://rallyto.ir/'), isNull);
      expect(testMatch().shareToken, 'abc123def456');
    });
  });

  group('what a player may do', () {
    final now = testNow;

    test('a player who is not involved may ask to join an open public post with a spot', () {
      expect(testMatch().canJoin(now), isTrue);
      expect(testMatch(openSpots: 0).canJoin(now), isFalse, reason: 'full');
      expect(testMatch(status: MatchStatus.confirmed).canJoin(now), isFalse);
      expect(testMatch(visibility: MatchVisibility.private).canJoin(now), isFalse);
      expect(testMatch().canJoin(testStartsAt), isFalse, reason: 'started');
      expect(testMatch(myState: ParticipantState.requested).canJoin(now), isFalse);
      expect(testMatch(myState: ParticipantState.withdrawn).canJoin(now), isTrue, reason: 'may ask again');
    });

    test('a requester withdraws; an invitee answers; an accepted player leaves before the start', () {
      expect(testMatch(myState: ParticipantState.requested).canWithdraw, isTrue);
      expect(testMatch(myState: ParticipantState.invited).canAnswerInvitation(now), isTrue);
      expect(
        testMatch(myState: ParticipantState.invited, status: MatchStatus.confirmed).canAnswerInvitation(now),
        isFalse,
      );
      final accepted = testMatch(myState: ParticipantState.accepted, status: MatchStatus.confirmed);
      expect(accepted.canLeave(now), isTrue);
      expect(accepted.canLeave(testStartsAt), isFalse);
      expect(testMatch(myState: ParticipantState.accepted, status: MatchStatus.cancelled).canLeave(now), isFalse);
    });

    test('the host answers requests, invites, confirms early with 2+ players, removes, cancels and shares', () {
      final hosted = testHostedMatch();
      expect(hosted.isHost, isTrue);
      expect(hosted.pendingRequests.map((p) => p.userId), ['u-3', 'u-4']);
      expect(hosted.players.map((p) => p.userId), ['u-1', 'u-2'], reason: 'host first');
      expect(hosted.canAnswerRequests(now), isTrue);
      expect(hosted.canInvite(now), isTrue);
      expect(hosted.canConfirmEarly(now), isTrue);
      expect(hosted.canCancel(now), isTrue);
      expect(hosted.canShare, isTrue);
      expect(hosted.canRemove(hosted.players.last, now), isTrue);
      expect(hosted.canJoin(now), isFalse, reason: 'the host does not join');

      final alone = testHostedMatch(
        openSpots: 3,
        participants: const [MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host)],
      );
      expect(alone.canConfirmEarly(now), isFalse, reason: 'a game takes at least 2 players');
      expect(testHostedMatch(status: MatchStatus.cancelled).canCancel(now), isFalse);
      expect(testHostedMatch().canCancel(testStartsAt), isFalse, reason: 'started');
      expect(testMatch().canCancel(now), isFalse, reason: 'not the host');
    });

    test('a public post\'s link is passed on by anyone while it takes players, by the host always', () {
      expect(testMatch().canShareLink(now), isTrue);
      expect(testMatch(status: MatchStatus.confirmed, openSpots: 0).canShareLink(now), isFalse, reason: 'full');
      expect(testMatch().canShareLink(testStartsAt), isFalse, reason: 'started');
      expect(testHostedMatch(status: MatchStatus.confirmed).canShareLink(testStartsAt), isTrue);
      expect(testMatch(visibility: MatchVisibility.private).canShareLink(now), isFalse, reason: 'no link');
    });

    test('a public post is reported by another player, not by its host; a private game is not a post', () {
      expect(testMatch().canReportPost, isTrue);
      expect(testHostedMatch().canReportPost, isFalse);
      expect(testMatch(visibility: MatchVisibility.private).canReportPost, isFalse);
    });

    test('the attendance question is answered once, while open', () {
      final closes = testEndedAt.add(const Duration(hours: 72));
      expect(testEndedMatch().canAnswerAttendance, isTrue);
      expect(
        testEndedMatch(
          attendance: MatchAttendance(open: true, closesAt: closes, myAnswer: AttendanceAnswer.played),
        ).canAnswerAttendance,
        isFalse,
        reason: 'answered',
      );
      expect(
        testEndedMatch(attendance: MatchAttendance(open: false, closesAt: closes)).canAnswerAttendance,
        isFalse,
        reason: 'closed',
      );
      expect(testMatch().canAnswerAttendance, isFalse, reason: 'not ended');
    });

    test('outstanding invitations hold no spot, but the host cannot invite past the spots left', () {
      final full = testHostedMatch(
        openSpots: 1,
        participants: const [
          MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
          MatchParticipant(userId: 'u-5', displayName: 'نرگس', state: ParticipantState.invited),
        ],
      );
      expect(full.canInvite(now), isFalse);
    });
  });
}
