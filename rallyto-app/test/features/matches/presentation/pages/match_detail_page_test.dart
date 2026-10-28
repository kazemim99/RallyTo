import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/domain/match_rules.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_detail_cubit.dart';
import 'package:rallyto_app/features/matches/presentation/pages/match_detail_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_matches.dart';

/// The game screen: its facts in Persian, the actions this player's place allows, the host's request list with
/// out-of-range badges, the share link, and the late-cancellation warning.
void main() {
  late FakeMatchRepository matches;

  setUp(() => matches = FakeMatchRepository());

  Future<MatchDetailCubit> show(WidgetTester tester, Match match) async {
    matches.match = match;
    final cubit = matchDetailCubit(matches);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpInShell(tester, BlocProvider.value(value: cubit, child: const MatchDetailPage()));
    return cubit;
  }

  /// Scrolls the game's list until [finder] is built and on screen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a player who is not involved sees the post and asks to join with a message', (tester) async {
    await show(tester, testMatch());

    expect(find.text('تنیس ‏•‏ انفرادی'), findsOneWidget);
    expect(find.text('شنبه ۲ آبان ۱۴۰۵، ۱۹:۰۰ تا ۲۰:۳۰'), findsOneWidget);
    expect(find.text('باشگاه انقلاب'), findsOneWidget);
    expect(find.text('۱ جای خالی از ۲'), findsOneWidget);
    expect(find.text('متوسط رو به پایین تا پیشرفته'), findsOneWidget, reason: "the sport's own level names");
    expect(find.text(AppStrings.courtBookedShort), findsOneWidget);
    expect(find.text('بازی عصر شنبه'), findsOneWidget, reason: 'the cover names the game by its day and time');
    expect(find.text(AppStrings.playersCount('۱', '۲')), findsOneWidget);
    final host = find.byKey(MatchDetailPage.participantKey('u-1'));
    expect(find.descendant(of: host, matching: find.text('سارا')), findsOneWidget);
    expect(find.descendant(of: host, matching: find.text(AppStrings.participantHost)), findsOneWidget);
    expect(
      find.descendant(of: host, matching: find.text('متوسط')),
      findsOneWidget,
      reason: "the host's level",
    );
    await reveal(tester, find.byKey(MatchDetailPage.policyNoticeKey));

    await reveal(tester, find.byKey(MatchDetailPage.joinKey));
    expect(find.byKey(MatchDetailPage.cancelKey), findsNothing);
    expect(find.text(AppStrings.playersLabel), findsNothing, reason: 'the participant list is for those involved');

    await tester.tap(find.byKey(MatchDetailPage.joinKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(MatchDetailPage.dialogTextKey), 'سلام، پایه‌ام');
    await tester.tap(find.byKey(MatchDetailPage.dialogConfirmKey));
    await tester.pumpAndSettle();

    expect(matches.calls.last, 'join:m-1:سلام، پایه‌ام');
    expect(find.text(AppStrings.joinRequested), findsOneWidget);
  });

  testWidgets("a refused join is said in the app's words", (tester) async {
    await show(tester, testMatch());
    matches.failure = const ServerFailure('x', code: MatchErrorCodes.scheduleConflict, statusCode: 409);

    await reveal(tester, find.byKey(MatchDetailPage.joinKey));
    await tester.tap(find.byKey(MatchDetailPage.joinKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MatchDetailPage.dialogConfirmKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.scheduleConflict), findsOneWidget);
  });

  testWidgets('the host sees players and requests, the out-of-range one marked, and accepts one', (tester) async {
    await show(tester, testHostedMatch());

    expect(find.text(AppStrings.myStateHost), findsOneWidget);
    await reveal(tester, find.byKey(MatchDetailPage.confirmEarlyKey));
    expect(find.byKey(MatchDetailPage.joinKey), findsNothing);
    await reveal(tester, find.byKey(MatchDetailPage.removeKey('u-2')));
    expect(find.byKey(MatchDetailPage.removeKey('u-1')), findsNothing, reason: 'the host is not removable');

    await reveal(tester, find.byKey(MatchDetailPage.acceptRequestKey('u-4')));
    await reveal(tester, find.text(AppStrings.requestsLabel, skipOffstage: false));
    expect(find.text(AppStrings.requestsLabel), findsOneWidget);
    expect(find.text('سلام، پایه‌ام'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(MatchDetailPage.participantKey('u-4')),
        matching: find.textContaining(AppStrings.outOfRange),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(MatchDetailPage.participantKey('u-3')),
        matching: find.textContaining(AppStrings.outOfRange),
      ),
      findsNothing,
    );

    await reveal(tester, find.byKey(MatchDetailPage.acceptRequestKey('u-3')));
    await tester.tap(find.byKey(MatchDetailPage.acceptRequestKey('u-3')));
    await tester.pumpAndSettle();

    expect(matches.calls.last, 'acceptRequest:m-1:u-3');
    expect(find.text(AppStrings.requestAccepted), findsOneWidget);
  });

  testWidgets('the host copies the share link, and regenerating it asks first', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await show(tester, testHostedMatch());

    await reveal(tester, find.byKey(MatchDetailPage.copyLinkKey));
    expect(find.text('https://rallyto.ir/m/abc123def456'), findsOneWidget);
    await tester.tap(find.byKey(MatchDetailPage.copyLinkKey));
    await tester.pumpAndSettle();
    expect(copied, ['https://rallyto.ir/m/abc123def456']);
    expect(find.text(AppStrings.linkCopied), findsOneWidget);

    await tester.tap(find.byKey(MatchDetailPage.overflowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MatchDetailPage.regenerateKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.regenerateLinkQuestion), findsOneWidget);
    await tester.tap(find.byKey(MatchDetailPage.dialogConfirmKey));
    await tester.pumpAndSettle();
    expect(matches.calls.last, 'shareToken:m-1');
  });

  testWidgets('the host cancels with a reason', (tester) async {
    await show(tester, testHostedMatch());

    await reveal(tester, find.byKey(MatchDetailPage.cancelKey));
    await tester.tap(find.byKey(MatchDetailPage.cancelKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MatchDetailPage.lateWarningKey), findsNothing, reason: 'an open game is not a late cancellation');
    await tester.enterText(find.byKey(MatchDetailPage.dialogTextKey), 'باران');
    await tester.tap(find.byKey(MatchDetailPage.dialogConfirmKey));
    await tester.pumpAndSettle();

    expect(matches.calls.last, 'cancel:m-1:باران');
    expect(find.text(AppStrings.matchCancelled), findsOneWidget);
  });

  testWidgets('leaving a confirmed game 5 hours before warns of a late cancellation', (tester) async {
    await show(
      tester,
      testMatch(
        status: MatchStatus.confirmed,
        openSpots: 0,
        myState: ParticipantState.accepted,
        startsAt: testNow.add(const Duration(hours: 5)),
        participants: const [
          MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
          MatchParticipant(userId: 'u-me', displayName: 'من', state: ParticipantState.accepted),
        ],
      ),
    );

    await reveal(tester, find.text(AppStrings.myStateAccepted));
    expect(find.text(AppStrings.myStateAccepted), findsOneWidget);
    await reveal(tester, find.byKey(MatchDetailPage.leaveKey));
    await tester.tap(find.byKey(MatchDetailPage.leaveKey));
    await tester.pumpAndSettle();

    expect(find.byKey(MatchDetailPage.lateWarningKey), findsOneWidget);
    await tester.tap(find.byKey(MatchDetailPage.dialogConfirmKey));
    await tester.pumpAndSettle();
    expect(matches.calls.last, 'leave:m-1');
  });

  testWidgets("the host's main actions are pinned: invite players and confirm early", (tester) async {
    await show(tester, testHostedMatch());

    final sticky = find.byKey(MatchDetailPage.stickyActionsKey);
    expect(find.descendant(of: sticky, matching: find.byKey(MatchDetailPage.inviteKey)), findsOneWidget);
    expect(find.descendant(of: sticky, matching: find.byKey(MatchDetailPage.confirmEarlyKey)), findsOneWidget);
    expect(find.byKey(MatchDetailPage.confirmedBannerKey), findsNothing, reason: 'not confirmed yet');

    await tester.tap(find.byKey(MatchDetailPage.confirmEarlyKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.confirmEarlyQuestion), findsOneWidget);
    await tester.tap(find.byKey(MatchDetailPage.dialogConfirmKey));
    await tester.pumpAndSettle();
    expect(matches.calls.last, 'confirm:m-1');
  });

  testWidgets('the host declines a request with its mini action', (tester) async {
    await show(tester, testHostedMatch());

    await reveal(tester, find.byKey(MatchDetailPage.declineRequestKey('u-4')));
    await tester.tap(find.byKey(MatchDetailPage.declineRequestKey('u-4')));
    await tester.pumpAndSettle();

    expect(matches.calls.last, 'declineRequest:m-1:u-4');
    expect(find.text(AppStrings.requestDeclined), findsOneWidget);
  });

  testWidgets('a confirmed game says so, and warns on the page when leaving would be late', (tester) async {
    await show(
      tester,
      testMatch(
        status: MatchStatus.confirmed,
        openSpots: 0,
        myState: ParticipantState.accepted,
        startsAt: testNow.add(const Duration(hours: 5)),
        participants: const [
          MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
          MatchParticipant(userId: 'u-me', displayName: 'من', state: ParticipantState.accepted),
        ],
      ),
    );

    expect(find.byKey(MatchDetailPage.confirmedBannerKey), findsOneWidget);
    expect(find.text(AppStrings.confirmedBannerTitle), findsOneWidget);
    await reveal(tester, find.byKey(MatchDetailPage.lateNoticeKey));
    expect(find.byKey(MatchDetailPage.policyNoticeKey), findsNothing, reason: 'nothing left to accept');
  });

  testWidgets('an open game far from its start has no late notice', (tester) async {
    await show(tester, testHostedMatch());
    expect(find.byKey(MatchDetailPage.lateNoticeKey), findsNothing);
  });

  testWidgets('an invitee accepts the invitation', (tester) async {
    await show(tester, testMatch(visibility: MatchVisibility.private, myState: ParticipantState.invited));

    await reveal(tester, find.text(AppStrings.myStateInvited));
    expect(find.text(AppStrings.myStateInvited), findsOneWidget);
    await reveal(tester, find.byKey(MatchDetailPage.declineInvitationKey));
    expect(find.byKey(MatchDetailPage.joinKey), findsNothing);
    await reveal(tester, find.byKey(MatchDetailPage.acceptInvitationKey));
    await tester.tap(find.byKey(MatchDetailPage.acceptInvitationKey));
    await tester.pumpAndSettle();

    expect(matches.calls.last, 'acceptInvitation:m-1');
  });

  testWidgets('a game the player may not see is "not available", with no retry', (tester) async {
    matches.loadFailure = const NotFoundFailure('x', code: MatchErrorCodes.matchNotAvailable);
    final cubit = matchDetailCubit(matches, ref: const MatchRef.token('old'));
    addTearDown(cubit.close);
    await cubit.load();
    await pumpInShell(tester, BlocProvider.value(value: cubit, child: const MatchDetailPage()));

    expect(find.text(AppStrings.matchNotAvailable), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });
}
