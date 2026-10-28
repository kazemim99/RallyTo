import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_form_cubit.dart';
import 'package:rallyto_app/features/matches/presentation/pages/match_form_page.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/router_shell.dart';

/// The post and invitation form: its defaults shown, what is missing marked, and once saved, on to the game.
void main() {
  late FakeMatchRepository matches;
  late FakeProfileRepository profiles;

  setUp(() {
    matches = FakeMatchRepository();
    profiles = FakeProfileRepository();
  });

  Future<MatchFormCubit> show(WidgetTester tester, {MatchFormArgs args = const MatchFormArgs.post()}) async {
    final cubit = MatchFormCubit(matches, profiles, FakeCatalogRepository(), args, clock: () => testNow);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const MatchFormPage()),
      ),
      landingRoute(Routes.match),
    ]);
    return cubit;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets("a post starts from the player's sport, format, session length and level ± 1", (tester) async {
    await show(tester);

    expect(find.text(AppStrings.newPostTitle), findsOneWidget);
    expect(find.text('تنیس'), findsOneWidget);
    expect(find.text(AppStrings.formatSingles), findsOneWidget);
    expect(find.text('۱۸:۰۰'), findsOneWidget);
    expect(find.text('۹۰ دقیقه'), findsOneWidget);
    await reveal(tester, find.byKey(MatchFormPage.levelsKey));
    expect(find.text('متوسط رو به پایین'), findsOneWidget);
    expect(find.text('پیشرفته'), findsOneWidget);
    await reveal(tester, find.byKey(MatchFormPage.openSpotsKey));
    expect(find.text(AppStrings.openSpotsPost('۱'), findRichText: true), findsOneWidget);
    expect(find.text(AppStrings.genderLockedHint), findsNothing);
  });

  testWidgets('sending without a club or date marks both', (tester) async {
    await show(tester);

    await reveal(tester, find.byKey(MatchFormPage.submitKey));
    await tester.tap(find.byKey(MatchFormPage.submitKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.venueRequired),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(AppStrings.venueRequired), findsOneWidget);
    expect(find.text(AppStrings.dateRequired), findsOneWidget);
    expect(matches.posts, isEmpty);
  });

  testWidgets('a valid post is published, and the screen moves on to the game', (tester) async {
    final cubit = await show(tester);
    cubit
      ..venueSelected(testVenue())
      ..dateSelected(Jalali(1405, 8, 2))
      ..startSelected(19 * 60);
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(MatchFormPage.submitKey));
    await tester.tap(find.byKey(MatchFormPage.submitKey));
    await tester.pumpAndSettle();

    expect(matches.posts.single.venueId, 'v-1');
    expect(find.text('landed /matches/m-1'), findsOneWidget);
    expect(find.text(AppStrings.postPublished), findsOneWidget);
  });

  testWidgets('a same-gender-only host sees why the gender is fixed', (tester) async {
    profiles.profile = testMyProfile(visibility: ProfileVisibility.sameGender);
    await show(tester);

    await reveal(tester, find.text(AppStrings.genderLockedHint));
    expect(find.text(AppStrings.genderLockedHint), findsOneWidget);
  });

  testWidgets('an invitation offers the open posts first, and invites into one', (tester) async {
    matches.upcoming = [testHostedMatch()];
    await show(
      tester,
      args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2', displayName: 'علی')),
    );

    expect(find.text(AppStrings.inviteTo('علی')), findsOneWidget);
    expect(find.text(AppStrings.chooseGameLabel), findsOneWidget);
    expect(find.text('تنیس در باشگاه انقلاب'), findsOneWidget);
    expect(find.byKey(MatchFormPage.levelsKey), findsNothing, reason: 'an invitation has no level range');
    expect(find.byKey(MatchFormPage.messageKey), findsNothing, reason: 'an invitation into a post carries no message');

    await tester.tap(find.byKey(MatchFormPage.inviteIntoKey('m-1')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(MatchFormPage.submitKey));
    await tester.tap(find.byKey(MatchFormPage.submitKey));
    await tester.pumpAndSettle();

    expect(matches.calls.last, 'invite:m-1:u-2');
    expect(find.text('landed /matches/m-1'), findsOneWidget);
    expect(find.text(AppStrings.invitationSent), findsOneWidget);
  });

  testWidgets('the level range opens a picker; a new lower end shows at once', (tester) async {
    await show(tester);

    await reveal(tester, find.byKey(MatchFormPage.levelsKey));
    await tester.tap(find.byKey(MatchFormPage.levelsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MatchFormPage.minLevelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مبتدی').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MatchFormPage.levelsDoneKey));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(MatchFormPage.levelsKey), matching: find.text('مبتدی')), findsOneWidget);
  });

  testWidgets('«ساخت بازی جدید» turns an invitation into a new private game, with a counted message', (tester) async {
    matches.upcoming = [testHostedMatch()];
    final cubit = await show(
      tester,
      args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2', displayName: 'علی')),
    );

    await tester.tap(find.byKey(MatchFormPage.newGameKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.newGameDetails), findsOneWidget);

    await reveal(tester, find.byKey(MatchFormPage.messageKey));
    expect(find.text(AppStrings.countOf('۰', '۲۰۰')), findsOneWidget);
    await tester.enterText(find.byKey(MatchFormPage.messageKey), 'سلام');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.countOf('۴', '۲۰۰')), findsOneWidget);

    cubit
      ..venueSelected(testVenue())
      ..dateSelected(Jalali(1405, 8, 2))
      ..startSelected(19 * 60);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(MatchFormPage.contactNoteKey));
    await reveal(tester, find.byKey(MatchFormPage.submitKey));
    await tester.tap(find.byKey(MatchFormPage.submitKey));
    await tester.pumpAndSettle();

    expect(matches.invitations.single.invitees, ['u-2']);
    expect(matches.invitations.single.message, 'سلام');
    expect(find.text(AppStrings.invitationSent), findsOneWidget);
  });

  testWidgets('without an open post, an invitation is a new game straight away', (tester) async {
    matches.upcoming = [];
    await show(
      tester,
      args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2', displayName: 'علی')),
    );

    expect(find.byKey(MatchFormPage.newGameKey), findsNothing);
    expect(find.text(AppStrings.chooseGameLabel), findsNothing);
    await reveal(tester, find.byKey(MatchFormPage.messageKey));
    expect(find.byKey(MatchFormPage.messageKey), findsOneWidget);
  });

  testWidgets('without a sport profile, it points to the profile', (tester) async {
    profiles.profile = testMyProfile(sports: const []);
    await show(tester);

    expect(find.text(AppStrings.noSportProfiles), findsOneWidget);
    expect(find.byKey(MatchFormPage.formatKey(PlayFormat.singles)), findsNothing);
  });
}
