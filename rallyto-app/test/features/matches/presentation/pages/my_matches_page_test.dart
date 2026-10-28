import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/my_matches_cubit.dart';
import 'package:rallyto_app/features/matches/presentation/pages/my_matches_page.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/router_shell.dart';

/// My games: upcoming and past tabs, each game opening its screen, a new post, and a game opened from a share link.
void main() {
  late FakeMatchRepository matches;

  setUp(() => matches = FakeMatchRepository());

  Future<GoRouter> show(WidgetTester tester) async {
    final cubit = MyMatchesCubit(matches, FakeCatalogRepository());
    addTearDown(cubit.close);
    await cubit.load();
    return pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const MyMatchesPage()),
      ),
      landingRoute(Routes.matchNew),
      landingRoute(Routes.match),
      landingRoute(Routes.sharedMatch),
      landingRoute(Routes.search),
    ]);
  }

  testWidgets('upcoming games first, past ones in their tab, each with its status', (tester) async {
    matches.past = [testMatch(id: 'm-9', status: MatchStatus.completed, myState: ParticipantState.accepted)];
    await show(tester);

    expect(find.byKey(MyMatchesPage.matchKey('m-1')), findsOneWidget);
    expect(find.byKey(MyMatchesPage.matchKey('m-2')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(MyMatchesPage.matchKey('m-2')),
        matching: find.text(AppStrings.matchStatusConfirmed),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.upcomingCount('۲')), findsOneWidget, reason: 'the upcoming tab counts its games');
    expect(find.text('شنبه ۲ آبان ۱۴۰۵، ۱۹:۰۰ تا ۲۰:۳۰'), findsNWidgets(2));

    await tester.tap(find.byKey(MyMatchesPage.pastTabKey));
    await tester.pumpAndSettle();

    expect(find.byKey(MyMatchesPage.matchKey('m-9')), findsOneWidget);
    expect(find.text(AppStrings.matchStatusCompleted), findsOneWidget);
    expect(find.text(AppStrings.myStateAccepted), findsOneWidget);
  });

  testWidgets('the status chips narrow the tab; none matching says so and offers all again', (tester) async {
    matches.upcoming = [testMatch(id: 'm-1'), testMatch(id: 'm-2', status: MatchStatus.confirmed)];
    await show(tester);

    await tester.tap(find.byKey(MyMatchesPage.filterKey(MatchStatusFilter.confirmed)));
    await tester.pumpAndSettle();
    expect(find.byKey(MyMatchesPage.matchKey('m-1')), findsNothing);
    expect(find.byKey(MyMatchesPage.matchKey('m-2')), findsOneWidget);

    await tester.tap(find.byKey(MyMatchesPage.filterKey(MatchStatusFilter.waiting)));
    await tester.pumpAndSettle();
    expect(find.byKey(MyMatchesPage.matchKey('m-1')), findsOneWidget);
    expect(find.byKey(MyMatchesPage.matchKey('m-2')), findsNothing);

    await tester.tap(find.byKey(MyMatchesPage.pastTabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MyMatchesPage.filterKey(MatchStatusFilter.waiting)), findsNothing, reason: 'past has its own');
    await tester.tap(find.byKey(MyMatchesPage.filterKey(MatchStatusFilter.cancelled)));
    await tester.pumpAndSettle();
    expect(find.byKey(MyMatchesPage.matchKey('m-9')), findsNothing);
    expect(find.text(AppStrings.matchFilterEmpty), findsOneWidget);

    await tester.tap(find.text(AppStrings.matchFilterShowAll));
    await tester.pumpAndSettle();
    expect(find.byKey(MyMatchesPage.matchKey('m-9')), findsOneWidget);
  });

  testWidgets('a game card names who plays: the host for others, «شما و …» for the players', (tester) async {
    matches.upcoming = [testMatch(id: 'm-1'), testHostedMatch()];
    await show(tester);

    expect(
      find.descendant(of: find.byKey(MyMatchesPage.matchKey('m-1')), matching: find.text(AppStrings.hostedBy('سارا'))),
      findsOneWidget,
    );
    expect(find.text(AppStrings.youAnd('علی')), findsOneWidget, reason: 'the host and one accepted player');
    expect(find.text('تنیس در باشگاه انقلاب'), findsNWidgets(2));
  });

  testWidgets('the share-link row is there even with no games', (tester) async {
    matches.upcoming = [];
    await show(tester);

    expect(find.text(AppStrings.pasteLinkTitle), findsOneWidget);
    await tester.tap(find.byKey(MyMatchesPage.openLinkKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MyMatchesPage.linkFieldKey), findsOneWidget);
  });

  testWidgets('a game opens its screen, and the list reloads on return', (tester) async {
    final router = await show(tester);
    final before = matches.calls.length;

    await tester.tap(find.byKey(MyMatchesPage.matchKey('m-2')));
    await tester.pumpAndSettle();
    expect(find.text('landed /matches/m-2'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(matches.calls.length, before + 2, reason: 'upcoming and past again');
  });

  testWidgets('no upcoming game: says so and offers the search', (tester) async {
    matches.upcoming = [];
    await show(tester);

    expect(find.text(AppStrings.upcomingEmptyTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.searchTitle));
    await tester.pumpAndSettle();
    expect(find.text('landed /search'), findsOneWidget);
  });

  testWidgets('a new post', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(MyMatchesPage.newPostKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /matches/new'), findsOneWidget);
  });

  testWidgets('a pasted share link opens its game; anything else is not recognised', (tester) async {
    await show(tester);

    await tester.scrollUntilVisible(
      find.byKey(MyMatchesPage.openLinkKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MyMatchesPage.openLinkKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(MyMatchesPage.linkFieldKey), 'سلام');
    await tester.tap(find.byKey(MyMatchesPage.openLinkConfirmKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.shareLinkNotRecognised), findsOneWidget);

    await tester.enterText(find.byKey(MyMatchesPage.linkFieldKey), 'https://rallyto.ir/m/a1b2c3d4e5f6');
    await tester.tap(find.byKey(MyMatchesPage.openLinkConfirmKey));
    await tester.pumpAndSettle();
    expect(find.text('landed /m/a1b2c3d4e5f6'), findsOneWidget);
  });
}
