import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_detail_cubit.dart';
import 'package:rallyto_app/features/matches/presentation/pages/match_detail_page.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';

import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_share.dart';
import '../../../../helpers/router_shell.dart';

/// The game screen after the game (a rating or attendance push lands here): the attendance question with no-shows,
/// the answer and the outcome once resolved, and the players to rate; plus sharing a public post and reporting it.
void main() {
  late FakeMatchRepository matches;
  late FakeShareService share;

  /// What the stand-in rating and report screens were opened with.
  late List<String> opened;
  late Object? openedExtra;

  /// What the stand-in screens close with.
  late bool closeWith;

  setUp(() {
    matches = FakeMatchRepository();
    share = FakeShareService();
    opened = [];
    openedExtra = null;
    closeWith = true;
  });

  GoRoute standIn(String path) => GoRoute(
    path: path,
    builder: (context, state) {
      opened.add(state.uri.path);
      openedExtra = state.extra;
      return Scaffold(
        body: TextButton(onPressed: () => Navigator.of(context).pop(closeWith), child: const Text('close')),
      );
    },
  );

  Future<MatchDetailCubit> show(WidgetTester tester, Match match) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    matches.match = match;
    final cubit = matchDetailCubit(matches, share: share);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const MatchDetailPage()),
      ),
      standIn(Routes.rateMatchPlayer),
      standIn(Routes.report),
    ]);
    return cubit;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  /// Opens the top bar's «•••» menu.
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(MatchDetailPage.overflowKey));
    await tester.pumpAndSettle();
  }

  group('the attendance question', () {
    testWidgets('«بازی انجام شد», flagging another player as a no-show', (tester) async {
      await show(tester, testEndedMatch());

      expect(find.text(AppStrings.attendanceTitle), findsOneWidget);
      expect(find.byKey(MatchDetailPage.noShowKey('u-3')), findsNothing, reason: 'no-shows only with «played»');
      expect(
        tester.widget<AppButton>(find.byKey(MatchDetailPage.submitAttendanceKey)).onPressed,
        isNull,
        reason: 'nothing chosen yet',
      );

      await tester.tap(find.byKey(MatchDetailPage.attendancePlayedKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.noShowTitle), findsOneWidget);
      for (final other in ['u-1', 'u-3', 'u-4']) {
        expect(find.byKey(MatchDetailPage.noShowKey(other)), findsOneWidget);
      }
      expect(find.byKey(MatchDetailPage.noShowKey('u-me')), findsNothing, reason: 'not oneself');

      await tester.tap(find.byKey(MatchDetailPage.noShowKey('u-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MatchDetailPage.submitAttendanceKey));
      await tester.pumpAndSettle();

      expect(matches.calls.last, 'attendance:m-1:Played:u-4');
      expect(find.text(AppStrings.attendanceSaved), findsOneWidget);
    });

    testWidgets('«بازی انجام نشد» goes without no-shows, even if some were ticked before', (tester) async {
      await show(tester, testEndedMatch());

      await tester.tap(find.byKey(MatchDetailPage.attendancePlayedKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MatchDetailPage.noShowKey('u-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MatchDetailPage.attendanceDidNotHappenKey));
      await tester.pumpAndSettle();

      expect(find.byKey(MatchDetailPage.noShowKey('u-3')), findsNothing);
      await tester.tap(find.byKey(MatchDetailPage.submitAttendanceKey));
      await tester.pumpAndSettle();

      expect(matches.calls.last, 'attendance:m-1:DidNotHappen:');
    });

    testWidgets("a refusal is said in the app's words", (tester) async {
      await show(tester, testEndedMatch());
      matches.failure = const ServerFailure('x', code: 'ALREADY_ANSWERED', statusCode: 409);

      await tester.tap(find.byKey(MatchDetailPage.attendanceDidNotHappenKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MatchDetailPage.submitAttendanceKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.alreadyAnswered), findsOneWidget);
    });

    testWidgets('answered, not yet resolved: the answer, and waiting for the others', (tester) async {
      await show(
        tester,
        testEndedMatch(
          attendance: MatchAttendance(
            open: true,
            closesAt: testEndedAt.add(const Duration(hours: 72)),
            myAnswer: AttendanceAnswer.played,
          ),
        ),
      );

      expect(find.byKey(MatchDetailPage.attendancePlayedKey), findsNothing);
      expect(find.text(AppStrings.myAttendanceAnswer(AppStrings.attendancePlayed)), findsOneWidget);
      expect(find.text(AppStrings.attendanceWaiting), findsOneWidget);
    });

    testWidgets('Completed: the outcome for this player and each participant, and the match status', (tester) async {
      await show(
        tester,
        testEndedMatch(
          status: MatchStatus.completed,
          participants: const [
            MatchParticipant(
              userId: 'u-1',
              displayName: 'سارا',
              state: ParticipantState.host,
              outcome: AttendanceOutcome.played,
            ),
            MatchParticipant(
              userId: 'u-me',
              displayName: 'من',
              state: ParticipantState.accepted,
              outcome: AttendanceOutcome.played,
            ),
            MatchParticipant(
              userId: 'u-3',
              displayName: 'رضا',
              state: ParticipantState.accepted,
              outcome: AttendanceOutcome.noShow,
            ),
            MatchParticipant(
              userId: 'u-4',
              displayName: 'مینا',
              state: ParticipantState.accepted,
              outcome: AttendanceOutcome.contested,
            ),
          ],
          attendance: MatchAttendance(
            open: false,
            closesAt: testEndedAt.add(const Duration(hours: 72)),
            myAnswer: AttendanceAnswer.played,
            myOutcome: AttendanceOutcome.played,
            resolvedAt: testNow,
          ),
        ),
      );

      expect(find.text(AppStrings.matchStatusCompleted), findsOneWidget);
      expect(find.text(AppStrings.resolutionCompleted), findsOneWidget);
      expect(find.text(AppStrings.myAttendanceOutcome(AppStrings.outcomePlayed)), findsOneWidget);
      await reveal(tester, find.byKey(MatchDetailPage.participantKey('u-4')));
      expect(find.text('${AppStrings.participantAccepted} ‏•‏ ${AppStrings.outcomeNoShow}'), findsOneWidget);
      expect(find.text('${AppStrings.participantAccepted} ‏•‏ ${AppStrings.outcomeContested}'), findsOneWidget);
    });

    for (final (status, statusLabel, resolution) in [
      (MatchStatus.disputed, AppStrings.matchStatusDisputed, AppStrings.resolutionDisputed),
      (MatchStatus.unconfirmed, AppStrings.matchStatusUnconfirmed, AppStrings.resolutionUnconfirmed),
    ]) {
      testWidgets('${status.wire}: said, with no effect on ratings and no outcome', (tester) async {
        await show(
          tester,
          testEndedMatch(
            status: status,
            attendance: MatchAttendance(
              open: false,
              closesAt: testEndedAt.add(const Duration(hours: 72)),
              myAnswer: AttendanceAnswer.didNotHappen,
              resolvedAt: testNow,
            ),
          ),
        );

        expect(find.text(statusLabel), findsOneWidget);
        expect(find.text(AppStrings.myAttendanceAnswer(AppStrings.attendanceDidNotHappen)), findsOneWidget);
        expect(find.text(resolution), findsOneWidget);
        expect(find.byKey(MatchDetailPage.attendanceOutcomeKey), findsNothing);
        expect(find.byKey(MatchDetailPage.rateSectionKey), findsNothing);
      });
    }

    testWidgets('a game not ended has no attendance section', (tester) async {
      await show(tester, testHostedMatch());

      expect(find.byKey(MatchDetailPage.attendanceKey), findsNothing);
    });
  });

  group('rating the other players', () {
    Match completed({List<String> canRate = const ['u-1', 'u-4']}) => testEndedMatch(
      status: MatchStatus.completed,
      attendance: MatchAttendance(
        open: false,
        closesAt: testEndedAt.add(const Duration(hours: 72)),
        myAnswer: AttendanceAnswer.played,
        myOutcome: AttendanceOutcome.played,
        resolvedAt: testNow,
        canRate: canRate,
      ),
    );

    testWidgets('each player still to rate opens the form; a stored rating reloads the game', (tester) async {
      await show(tester, completed());

      expect(find.text(AppStrings.rateTitle), findsOneWidget);
      expect(find.text(AppStrings.ratePlayer('سارا')), findsOneWidget);
      expect(find.text(AppStrings.ratePlayer('مینا')), findsOneWidget);
      expect(find.text(AppStrings.ratePlayer('رضا')), findsNothing);

      matches.match = completed(canRate: const ['u-1']);
      await tester.tap(find.byKey(MatchDetailPage.rateKey('u-4')));
      await tester.pumpAndSettle();

      expect(opened, ['/matches/m-1/rate/u-4']);
      expect(openedExtra, 'مینا');

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(matches.calls.where((c) => c == 'getMatch:m-1'), hasLength(2), reason: 'loaded again');
      expect(find.text(AppStrings.ratePlayer('مینا')), findsNothing);
    });

    testWidgets('backing out of the form does not reload', (tester) async {
      await show(tester, completed());
      closeWith = false;

      await tester.tap(find.byKey(MatchDetailPage.rateKey('u-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(matches.calls.where((c) => c == 'getMatch:m-1'), hasLength(1));
    });

    testWidgets('nobody left to rate: no section', (tester) async {
      await show(tester, completed(canRate: const []));

      expect(find.byKey(MatchDetailPage.rateSectionKey), findsNothing);
    });
  });

  group('sharing and reporting a public post', () {
    testWidgets('a player who is not the host shares the link (and can copy it), but cannot regenerate it', (
      tester,
    ) async {
      await show(tester, testMatch());

      await reveal(tester, find.byKey(MatchDetailPage.shareKey));
      expect(find.text(AppStrings.shareHintPublic), findsOneWidget);
      expect(find.byKey(MatchDetailPage.copyLinkKey), findsOneWidget);
      await openMenu(tester);
      expect(find.byKey(MatchDetailPage.reportPostKey), findsOneWidget);
      expect(find.byKey(MatchDetailPage.regenerateKey), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MatchDetailPage.shareKey));
      await tester.pumpAndSettle();

      expect(share.shared.single.$1, contains('https://rallyto.ir/m/abc123def456'));
    });

    testWidgets('the host shares, copies and regenerates', (tester) async {
      await show(tester, testHostedMatch());

      await reveal(tester, find.byKey(MatchDetailPage.shareKey));
      expect(find.byKey(MatchDetailPage.copyLinkKey), findsOneWidget);
      await openMenu(tester);
      expect(find.byKey(MatchDetailPage.regenerateKey), findsOneWidget);
    });

    testWidgets('a full post is not passed on by others', (tester) async {
      await show(tester, testMatch(status: MatchStatus.confirmed, openSpots: 0));
      expect(find.byKey(MatchDetailPage.shareKey), findsNothing);
    });

    testWidgets('another player reports the post: the form opens with the game and its host', (tester) async {
      await show(tester, testMatch());
      closeWith = false;

      await openMenu(tester);
      await tester.tap(find.byKey(MatchDetailPage.reportPostKey));
      await tester.pumpAndSettle();

      expect(opened, [Routes.report]);
      expect(openedExtra, const ReportTarget.post('m-1', hostName: 'سارا'));
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(matches.calls.where((c) => c == 'getMatch:m-1'), hasLength(1), reason: 'not blocked: nothing to reload');
    });

    testWidgets('the host cannot report their own post', (tester) async {
      await show(tester, testHostedMatch());
      await openMenu(tester);
      expect(find.byKey(MatchDetailPage.reportPostKey), findsNothing);
    });
  });
}
