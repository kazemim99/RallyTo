import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/home/presentation/bloc/home_cubit.dart';
import 'package:rallyto_app/features/home/presentation/home_labels.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';

import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_profile.dart';

/// Home's data: the greeting by Tehran's clock, the next game, the pending actions and the availability reminder.
void main() {
  group('the greeting follows the time of day in Tehran', () {
    // Tehran is UTC+3:30.
    DateTime tehran(int hour, [int minute = 0]) =>
        DateTime.utc(2026, 10, 23, hour, minute).subtract(const Duration(hours: 3, minutes: 30));

    test('morning from 05:00, noon from 12:00, afternoon from 15:00, night from 19:00', () {
      expect(HomeLabels.greeting(tehran(4, 59)), AppStrings.greetingNight);
      expect(HomeLabels.greeting(tehran(5)), AppStrings.greetingMorning);
      expect(HomeLabels.greeting(tehran(11, 59)), AppStrings.greetingMorning);
      expect(HomeLabels.greeting(tehran(12)), AppStrings.greetingNoon);
      expect(HomeLabels.greeting(tehran(15)), AppStrings.greetingAfternoon);
      expect(HomeLabels.greeting(tehran(19)), AppStrings.greetingNight);
      expect(HomeLabels.greeting(tehran(23, 30)), AppStrings.greetingNight);
    });
  });

  group('the next game', () {
    test('the soonest active game I play in, not one I am only invited to or one already started', () {
      final later = testMatch(
        id: 'later',
        myState: ParticipantState.host,
        startsAt: testStartsAt.add(const Duration(days: 2)),
      );
      final sooner = testMatch(id: 'sooner', myState: ParticipantState.accepted, status: MatchStatus.confirmed);
      final invited = testMatch(
        id: 'invited',
        myState: ParticipantState.invited,
        startsAt: testNow.add(const Duration(hours: 1)),
      );
      final started = testMatch(id: 'started', myState: ParticipantState.accepted, startsAt: testNow);

      expect(HomeCubit.nextGameOf([later, invited, started, sooner], testNow)?.id, 'sooner');
      expect(HomeCubit.nextGameOf([invited], testNow), isNull);
    });
  });

  group('pending actions', () {
    test('invitations and join requests soonest first, then attendance and ratings of ended games', () {
      final invitation = testMatch(
        id: 'inv',
        myState: ParticipantState.invited,
        startsAt: testStartsAt.add(const Duration(days: 1)),
      );
      final hosted = testHostedMatch();
      final quietHost = testHostedMatch(participants: const []);
      final attendance = testEndedMatch();
      final rating = testEndedMatch(
        attendance: MatchAttendance(
          open: false,
          closesAt: testEndedAt,
          myAnswer: AttendanceAnswer.played,
          canRate: const ['u-3'],
        ),
      );

      final tasks = HomeTask.from(upcoming: [invitation, quietHost, hosted], past: [attendance, rating], now: testNow);

      expect(
        [for (final t in tasks) t.kind],
        [HomeTaskKind.requests, HomeTaskKind.invitation, HomeTaskKind.attendance, HomeTaskKind.rating],
      );
    });
  });

  group('loading', () {
    test('each part on its own: games failing leave the name and availability shown', () async {
      final matches = FakeMatchRepository()..loadFailure = const NetworkFailure(AppStrings.offlineActionError);
      final cubit = HomeCubit(FakeProfileRepository(), matches, FakeAvailabilityRepository(), clock: () => testNow);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.name, 'سارا');
      expect(cubit.state.gamesStatus, ViewStatus.error);
      expect(cubit.state.gamesError, AppStrings.offlineActionError);
      expect(cubit.state.activeWindowCount, 1);
      expect(cubit.state.showReconfirm, isFalse, reason: 'the active weekly window was confirmed recently');
    });

    test('«هنوز آزادم» confirms only the windows that need it, and the reminder goes', () async {
      final availability = FakeAvailabilityRepository()
        ..mine = [
          testWindow(id: 'w-1', needsReconfirmation: true, pausesOn: '1405/09/02'),
          testWindow(id: 'w-fresh', pausesOn: '1405/09/20'),
          testWindow(id: 'w-3', needsReconfirmation: true, pausesOn: '1405/08/30'),
          testWindow(id: 'w-paused', status: AvailabilityStatus.paused),
          testWindow(id: 'w-once', kind: AvailabilityKind.oneOff),
        ];
      final cubit = HomeCubit(FakeProfileRepository(), FakeMatchRepository(), availability, clock: () => testNow);
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.showReconfirm, isTrue);
      expect([for (final w in cubit.state.reconfirmCandidates) w.id], ['w-1', 'w-3']);
      expect(HomeLabels.reconfirmTitle(cubit.state.reconfirmCandidates), AppStrings.reconfirmTitle);
      expect(
        HomeLabels.reconfirmBody(cubit.state.reconfirmCandidates),
        AppStrings.reconfirmPausesOnMany('۳۰ آبان ۱۴۰۵'),
        reason: 'the first of the pause days',
      );
      await cubit.reconfirm();

      expect(availability.actions, [('confirm', 'w-1'), ('confirm', 'w-3')], reason: 'w-fresh is left alone');
      expect(cubit.state.showReconfirm, isFalse);
      expect(cubit.state.feedback?.message, AppStrings.availabilityConfirmed);
    });

    test('active weekly windows that do not need it yet: no reminder, and «هنوز آزادم» does nothing', () async {
      final availability = FakeAvailabilityRepository()
        ..mine = [testWindow(id: 'w-1', pausesOn: '1405/09/20'), testWindow(id: 'w-2', pausesOn: '1405/09/21')];
      final cubit = HomeCubit(FakeProfileRepository(), FakeMatchRepository(), availability, clock: () => testNow);
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.showReconfirm, isFalse);
      await cubit.reconfirm();
      expect(availability.actions, isEmpty);
    });

    test('a single window names its pause day; without one the general hint stays', () {
      final due = testWindow(needsReconfirmation: true, pausesOn: '1405/08/30');
      final undated = testWindow(needsReconfirmation: true);

      expect(HomeLabels.reconfirmBody([due]), 'بازهٔ زمانی شما ۳۰ آبان ۱۴۰۵ متوقف می‌شود.');
      expect(HomeLabels.reconfirmBody([undated]), AppStrings.confirmStillAvailableHint);
    });
  });
}
