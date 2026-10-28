import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';
import 'package:rallyto_app/features/search/presentation/bloc/partner_search_cubit.dart';
import 'package:rallyto_app/features/search/presentation/pages/partner_search_page.dart';
import 'package:rallyto_app/features/search/presentation/widgets/partner_result_card.dart';
import 'package:rallyto_app/features/search/presentation/widgets/search_filter_sheet.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_search.dart';
import '../../../../helpers/router_shell.dart';

/// The search screen: the filters' summary, posts and player cards with the overlap, more players, the filter sheet,
/// saving the search, and the way to a profile, an invitation and a saved search.
void main() {
  late FakeSearchRepository search;

  setUp(() => search = FakeSearchRepository());

  Future<PartnerSearchCubit> show(WidgetTester tester) async {
    final cubit = PartnerSearchCubit(
      search,
      FakeProfileRepository(),
      FakeCatalogRepository(),
      null,
      clock: () => testNow,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const PartnerSearchPage()),
      ),
      landingRoute(Routes.player),
      landingRoute(Routes.invitePlayer),
      landingRoute(Routes.playerChat),
      landingRoute(Routes.match),
      GoRoute(
        path: Routes.savedSearches,
        builder: (context, state) => Scaffold(
          body: TextButton(onPressed: () => context.pop(testSavedSearch().filters), child: const Text('run saved')),
        ),
      ),
    ]);
    return cubit;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the defaults as chips, then posts and players with their overlap', (tester) async {
    await show(tester);

    Finder chip(String label) =>
        find.descendant(of: find.byKey(PartnerSearchPage.summaryKey), matching: find.text(label));
    expect(chip('تنیس'), findsOneWidget);
    expect(chip('${AppStrings.anyDay} ‏•‏ ${AppStrings.wholeDay}'), findsOneWidget);
    expect(chip('متوسط رو به پایین تا پیشرفته'), findsOneWidget);
    expect(chip('تهران ‏•‏ ${AppStrings.allVenues}'), findsOneWidget);
    expect(find.text(AppStrings.searchOpenPostsTitle), findsOneWidget);
    expect(find.byKey(PartnerSearchPage.postKey('m-7')), findsOneWidget);
    await reveal(tester, find.byKey(PartnerSearchPage.playerKey('u-2')));
    expect(find.text(AppStrings.overlapBoxTitle), findsWidgets);
    expect(find.text('هم‌پوشانی ۲۰:۰۰ تا ۲۲:۰۰'), findsWidgets);
    expect(find.text('شنبه، ۱۸:۰۰ تا ۲۴:۰۰'), findsWidgets);
    expect(find.text('۲۵ تا ۳۴ سال ‏•‏ متوسط، ۱ تا ۳ سال'), findsWidgets, reason: 'age ‏•‏ level ‏•‏ experience');
  });

  testWidgets('an open post: its open spots, the host, and that the player may ask to join', (tester) async {
    await show(tester);

    final post = find.byKey(PartnerSearchPage.postKey('m-7'));
    expect(find.descendant(of: post, matching: find.text(AppStrings.openSpotsShort('۱'))), findsOneWidget);
    expect(find.descendant(of: post, matching: find.text('تنیس ‏•‏ انفرادی')), findsOneWidget);
    expect(find.descendant(of: post, matching: find.text(AppStrings.postHost('سارا'))), findsOneWidget);
    expect(find.descendant(of: post, matching: find.text(AppStrings.join)), findsOneWidget);
  });

  testWidgets('a filter chip opens the filter sheet', (tester) async {
    await show(tester);

    await tester.tap(find.descendant(of: find.byKey(PartnerSearchPage.summaryKey), matching: find.text('تنیس')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFilterSheet), findsOneWidget);
    expect(find.text(AppStrings.searchShowResults), findsOneWidget);
  });

  testWidgets('more players, page by page', (tester) async {
    final cubit = await show(tester);

    await reveal(tester, find.byKey(PartnerSearchPage.loadMoreKey));
    await tester.tap(find.byKey(PartnerSearchPage.loadMoreKey));
    await tester.pumpAndSettle();

    expect(cubit.state.players.map((p) => p.userId), ['u-2', 'u-3', 'u-4']);
    await reveal(tester, find.byKey(PartnerSearchPage.playerKey('u-4')));
    expect(find.byKey(PartnerSearchPage.loadMoreKey), findsNothing, reason: 'the last page');
  });

  testWidgets('players only asks the server for players, and the posts go', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(PartnerSearchPage.resultTypeKey(SearchResultType.players)));
    await tester.pumpAndSettle();

    expect(search.resultTypes.last, SearchResultType.players);
    expect(find.byKey(PartnerSearchPage.postKey('m-7')), findsNothing);
    expect(find.byKey(PartnerSearchPage.playerKey('u-2')), findsOneWidget);
  });

  testWidgets("a player card's message button opens a conversation with them", (tester) async {
    await show(tester);
    await reveal(tester, find.byKey(PartnerSearchPage.playerKey('u-2')));

    await tester.tap(find.byKey(PartnerResultCard.messageKey('u-2')));
    await tester.pumpAndSettle();
    expect(find.text('landed /players/u-2/chat علی'), findsOneWidget);
  });

  testWidgets("a player card's invite button opens the invitation, with their name", (tester) async {
    await show(tester);
    await reveal(tester, find.byKey(PartnerSearchPage.playerKey('u-2')));

    await tester.tap(find.byKey(PartnerResultCard.inviteKey('u-2')));
    await tester.pumpAndSettle();
    expect(find.text('landed /players/u-2/invite علی'), findsOneWidget);
  });

  testWidgets('a player card opens the profile', (tester) async {
    await show(tester);
    await reveal(tester, find.byKey(PartnerSearchPage.playerKey('u-2')));

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    expect(find.text('landed /players/u-2'), findsOneWidget);
  });

  testWidgets('a post opens its game', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(PartnerSearchPage.postKey('m-7')));
    await tester.pumpAndSettle();

    expect(find.text('landed /matches/m-7'), findsOneWidget);
  });

  testWidgets('the filter sheet: weekdays applied together, and a date mode without a date refused', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(PartnerSearchPage.filtersKey));
    await tester.pumpAndSettle();
    final sheet = find.descendant(of: find.byType(SearchFilterSheet), matching: find.byType(Scrollable));
    Future<void> scrollTo(Key key, double delta) async {
      await tester.scrollUntilVisible(find.byKey(key), delta, scrollable: sheet);
      await tester.pumpAndSettle();
    }

    final saturday = SearchFilterSheet.weekdayKey(Weekday.saturday);
    await scrollTo(saturday, 100);
    await tester.tap(find.byKey(saturday));
    await tester.pumpAndSettle();
    await scrollTo(SearchFilterSheet.byDateKey, -100);
    await tester.tap(find.byKey(SearchFilterSheet.byDateKey));
    await tester.pumpAndSettle();
    // «نمایش نتایج» stays pinned under the sections: no scrolling to reach it.
    await tester.tap(find.byKey(SearchFilterSheet.applyKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.dateRequired), findsOneWidget);

    await scrollTo(SearchFilterSheet.byWeekdaysKey, -200);
    await tester.tap(find.byKey(SearchFilterSheet.byWeekdaysKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SearchFilterSheet.applyKey));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFilterSheet), findsNothing, reason: 'applied, the sheet closes');
    expect(search.searches.last.$1.weekdays, {Weekday.saturday});
    expect(search.searches.last.$1.date, isNull);
  });

  testWidgets('saving the search asks for a name', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(PartnerSearchPage.saveKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(PartnerSearchPage.saveNameKey), 'شنبه‌شب‌ها');
    await tester.tap(find.byKey(PartnerSearchPage.saveConfirmKey));
    await tester.pumpAndSettle();

    expect(search.created.single.$1, 'شنبه‌شب‌ها');
    expect(search.created.single.$2, isTrue, reason: 'alerts on by default');
    expect(find.text(AppStrings.searchSaved), findsOneWidget);
  });

  testWidgets('running a saved search searches with its filters', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(PartnerSearchPage.savedSearchesKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('run saved'));
    await tester.pumpAndSettle();

    expect(search.searches.last.$1.weekdays, {Weekday.saturday});
    expect(search.searches.last.$1.fromMinute, 18 * 60);
  });
}
