import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/domain/match_rules.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_detail_cubit.dart';

import '../../../../helpers/fake_matches.dart';

/// One game: loaded by id or share token, and every action answering with the whole updated game and feedback; a
/// refusal is said in the app's words for the server's code.
void main() {
  late FakeMatchRepository matches;

  setUp(() => matches = FakeMatchRepository());

  Future<MatchDetailCubit> open({MatchRef ref = const MatchRef.id('m-1'), DateTime? now}) async {
    final cubit = matchDetailCubit(matches, ref: ref, now: now);
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  group('loading', () {
    test('by id: the game, with the sport from the catalog for its level names', () async {
      final cubit = await open();

      expect(cubit.state.status, ViewStatus.content);
      expect(cubit.state.match, matches.match);
      expect(cubit.state.sport?.code, 'tennis');
      expect(matches.calls, ['getMatch:m-1']);
    });

    test('by share token', () async {
      await open(ref: const MatchRef.token('abc123def456'));

      expect(matches.calls, ['getByShareToken:abc123def456']);
    });

    test('a private, hidden or regenerated game is "not available", with no retry', () async {
      matches.loadFailure = const NotFoundFailure('بازی پیدا نشد.', code: MatchErrorCodes.matchNotFound);

      final cubit = await open();

      expect(cubit.state.status, ViewStatus.error);
      expect(cubit.state.notFound, isTrue);
      expect(cubit.state.errorMessage, AppStrings.matchNotAvailable);
    });

    test('offline: an error that can be retried', () async {
      matches.loadFailure = const NetworkFailure(AppStrings.offlineActionError);

      final cubit = await open();

      expect(cubit.state.notFound, isFalse);
      expect(cubit.state.errorMessage, AppStrings.offlineActionError);
    });
  });

  group('actions', () {
    final confirmed = testMatch(status: MatchStatus.confirmed, openSpots: 0, myState: ParticipantState.accepted);

    Future<void> expectAction(
      Future<void> Function(MatchDetailCubit cubit) action,
      String call,
      String feedback, {
      Match? start,
    }) async {
      if (start != null) matches.match = start;
      final cubit = await open();
      matches.next = confirmed;

      await action(cubit);

      expect(matches.calls.last, call);
      expect(cubit.state.match, confirmed, reason: 'the updated game replaces the one shown');
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.feedback?.message, feedback);
      expect(cubit.state.feedback?.isError, isFalse);
    }

    test(
      'join with a message',
      () => expectAction((c) => c.join(message: 'سلام، پایه‌ام'), 'join:m-1:سلام، پایه‌ام', AppStrings.joinRequested),
    );

    test('withdraw', () => expectAction((c) => c.withdraw(), 'withdraw:m-1', AppStrings.requestWithdrawn));

    test('accept and decline a request', () async {
      await expectAction((c) => c.acceptRequest('u-3'), 'acceptRequest:m-1:u-3', AppStrings.requestAccepted);
      await expectAction((c) => c.declineRequest('u-4'), 'declineRequest:m-1:u-4', AppStrings.requestDeclined);
    });

    test('answer an invitation', () async {
      await expectAction((c) => c.acceptInvitation(), 'acceptInvitation:m-1', AppStrings.invitationAccepted);
      await expectAction((c) => c.declineInvitation(), 'declineInvitation:m-1', AppStrings.invitationDeclined);
    });

    test('confirm early', () => expectAction((c) => c.confirmEarly(), 'confirm:m-1', AppStrings.matchConfirmed));

    test('leave', () => expectAction((c) => c.leave(), 'leave:m-1', AppStrings.matchLeft));

    test(
      'remove a participant',
      () => expectAction((c) => c.removeParticipant('u-2'), 'remove:m-1:u-2', AppStrings.participantRemovedDone),
    );

    test(
      'cancel with a reason',
      () => expectAction((c) => c.cancel(reason: 'باران'), 'cancel:m-1:باران', AppStrings.matchCancelled),
    );

    test(
      'regenerate the share link',
      () => expectAction((c) => c.regenerateShareToken(), 'shareToken:m-1', AppStrings.linkRegenerated),
    );

    test('a copied link is said', () async {
      final cubit = await open();
      cubit.linkCopied();
      expect(cubit.state.feedback?.message, AppStrings.linkCopied);
    });

    test('a join message over 200 characters is refused on the device', () async {
      final cubit = await open();

      await cubit.join(message: 'x' * 201);

      expect(matches.calls, ['getMatch:m-1'], reason: 'nothing was sent');
      expect(cubit.state.feedback?.message, AppStrings.messageTooLong);
      expect(cubit.state.feedback?.isError, isTrue);
    });

    test('one action at a time', () async {
      final cubit = await open();
      final first = cubit.withdraw();
      await cubit.leave();
      await first;

      expect(matches.calls.where((c) => c != 'getMatch:m-1'), ['withdraw:m-1']);
    });
  });

  group('refusals, in the app\'s words for each code', () {
    const cases = {
      MatchErrorCodes.scheduleConflict: AppStrings.scheduleConflict,
      MatchErrorCodes.noOpenSpot: AppStrings.noOpenSpot,
      MatchErrorCodes.matchClosed: AppStrings.matchClosed,
      MatchErrorCodes.matchStarted: AppStrings.matchStarted,
      MatchErrorCodes.matchFinished: AppStrings.matchFinished,
      MatchErrorCodes.alreadyInMatch: AppStrings.alreadyInMatch,
      MatchErrorCodes.notAPost: AppStrings.notAPost,
      MatchErrorCodes.notTheHost: AppStrings.notTheHost,
      MatchErrorCodes.notAParticipant: AppStrings.notAParticipant,
      MatchErrorCodes.notEnoughPlayers: AppStrings.notEnoughPlayers,
      MatchErrorCodes.invalidParticipantState: AppStrings.invalidParticipantState,
      MatchErrorCodes.tooManyPendingRequests: AppStrings.tooManyPendingRequests,
      MatchErrorCodes.tooManyInvitees: AppStrings.tooManyInvitees,
      MatchErrorCodes.noSportProfile: AppStrings.noSportProfileForMatch,
      MatchErrorCodes.messageTooLong: AppStrings.messageTooLong,
      MatchErrorCodes.matchNotFound: AppStrings.matchNotAvailable,
      MatchErrorCodes.tooManyRequests: AppStrings.tooManyRequestsError,
    };

    for (final MapEntry(key: code, value: message) in cases.entries) {
      test(code, () async {
        final cubit = await open();
        final before = cubit.state.match;
        matches.failure = ServerFailure('server words', code: code, statusCode: 409);

        await cubit.join();

        expect(cubit.state.match, before, reason: 'the game shown is unchanged');
        expect(cubit.state.busy, isFalse);
        expect(cubit.state.feedback?.message, message);
        expect(cubit.state.feedback?.isError, isTrue);
        expect(cubit.state.feedback?.code, code);
      });
    }

    test("an unknown code keeps the server's words", () async {
      final cubit = await open();
      matches.failure = const ServerFailure('پیام سرور', code: 'SOMETHING_NEW');

      await cubit.withdraw();

      expect(cubit.state.feedback?.message, 'پیام سرور');
    });
  });

  test('a confirmed game within 12 hours warns of a late cancellation', () async {
    matches.match = testMatch(
      status: MatchStatus.confirmed,
      openSpots: 0,
      myState: ParticipantState.accepted,
      startsAt: testNow.add(const Duration(hours: 5)),
    );
    expect((await open()).isLateCancellation, isTrue);

    matches.match = testMatch(status: MatchStatus.confirmed, openSpots: 0, myState: ParticipantState.accepted);
    expect((await open()).isLateCancellation, isFalse, reason: 'starts in more than a day');
  });
}
