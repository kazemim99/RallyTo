import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/presentation/pages/match_detail_page.dart';
import 'package:rallyto_app/features/matches/presentation/widgets/match_card.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_chat.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/router_shell.dart';

/// A game's way into chat (a message to the host or the other player, the group conversation once the server says
/// there is one), and a cancelled game's reason.
void main() {
  late FakeMatchRepository matches;

  setUp(() => matches = FakeMatchRepository());

  Future<void> show(WidgetTester tester, Match match, {FakeChatRepository? chat}) async {
    matches.match = match;
    final cubit = matchDetailCubit(matches, chat: chat);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const MatchDetailPage()),
      ),
      landingRoute(Routes.playerChat),
      landingRoute(Routes.conversation),
    ]);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// A doubles game hosted by «سارا» with two accepted players: a group conversation exists.
  Match padelGroup({ParticipantState myState = ParticipantState.accepted}) => testMatch(
    capacity: 4,
    openSpots: 1,
    format: PlayFormat.doubles,
    myState: myState,
    participants: const [
      MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
      MatchParticipant(userId: 'u-me', displayName: 'من', state: ParticipantState.accepted),
      MatchParticipant(userId: 'u-3', displayName: 'رضا', state: ParticipantState.accepted),
    ],
  );

  testWidgets('a player who is not the host can message the host', (tester) async {
    await show(tester, testMatch());

    await reveal(tester, find.byKey(MatchDetailPage.messageKey));
    expect(
      find.descendant(of: find.byKey(MatchDetailPage.messageKey), matching: find.text(AppStrings.messageShort)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(MatchDetailPage.messageKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /players/u-1/chat سارا'), findsOneWidget);
  });

  testWidgets('the host of a singles game messages the other player', (tester) async {
    await show(
      tester,
      testMatch(
        myState: ParticipantState.host,
        openSpots: 0,
        status: MatchStatus.confirmed,
        participants: const [
          MatchParticipant(userId: 'u-1', displayName: 'سارا', state: ParticipantState.host),
          MatchParticipant(userId: 'u-2', displayName: 'علی', state: ParticipantState.accepted),
        ],
      ),
    );

    await reveal(tester, find.byKey(MatchDetailPage.messageKey));
    await tester.tap(find.byKey(MatchDetailPage.messageKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /players/u-2/chat علی'), findsOneWidget);
  });

  testWidgets('a game the server has a group conversation for links straight to it', (tester) async {
    final chat = FakeChatRepository();
    await show(tester, padelGroup(), chat: chat);

    expect(chat.calls, ['match:m-1']);
    await reveal(tester, find.byKey(MatchDetailPage.groupChatKey));
    await tester.tap(find.byKey(MatchDetailPage.groupChatKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /chat/c-group'), findsOneWidget);
  });

  testWidgets('no group link when the server has none for this player (CONVERSATION_NOT_FOUND)', (tester) async {
    final chat = FakeChatRepository()..matchGroups = {};
    await show(tester, testHostedMatch(), chat: chat);

    expect(chat.calls, ['match:m-1']);
    expect(find.byKey(MatchDetailPage.groupChatKey), findsNothing);
  });

  testWidgets('a player who is not in the game is not looked up, and gets no group link', (tester) async {
    final chat = FakeChatRepository();
    await show(tester, testMatch(), chat: chat);

    expect(chat.calls, isEmpty);
    expect(find.byKey(MatchDetailPage.groupChatKey), findsNothing);
  });

  testWidgets("a cancelled game shows the host's reason", (tester) async {
    await show(tester, testMatch(status: MatchStatus.cancelled, cancelReason: 'باران'));

    expect(find.byKey(MatchDetailPage.cancelReasonKey), findsOneWidget);
    expect(find.text(AppStrings.cancelReason('باران')), findsOneWidget);
  });

  testWidgets('a cancelled game without a reason, or a game not cancelled, shows none', (tester) async {
    await show(tester, testMatch(status: MatchStatus.cancelled));
    expect(find.byKey(MatchDetailPage.cancelReasonKey), findsNothing);
  });

  testWidgets("a cancelled game's card in a list shows the reason too", (tester) async {
    await pumpInShell(
      tester,
      MatchCard(
        match: testMatch(status: MatchStatus.cancelled, cancelReason: 'باران'),
      ),
    );

    expect(find.text(AppStrings.cancelReason('باران')), findsOneWidget);
  });
}
