import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/features/home/presentation/pages/home_page.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/player_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/pages/player_profile_page.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_home.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/router_shell.dart';

/// The ways in: a player's profile invites them to a game or opens a conversation, and home leads to the search and
/// to my games.
void main() {
  testWidgets("a player's profile invites them to a game, carrying their name", (tester) async {
    final cubit = PlayerProfileCubit(
      FakeProfileRepository(),
      FakeAvailabilityRepository(),
      FakeCatalogRepository(),
      'u-2',
    );
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const PlayerProfilePage()),
      ),
      landingRoute(Routes.invitePlayer),
    ]);

    await tester.tap(find.byKey(PlayerProfilePage.inviteKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /players/u-2/invite علی'), findsOneWidget);
  });

  testWidgets("a player's profile opens a conversation with them, carrying their name", (tester) async {
    final cubit = PlayerProfileCubit(
      FakeProfileRepository(),
      FakeAvailabilityRepository(),
      FakeCatalogRepository(),
      'u-2',
    );
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const PlayerProfilePage()),
      ),
      landingRoute(Routes.playerChat),
    ]);

    await tester.ensureVisible(find.byKey(PlayerProfilePage.messageKey));
    await tester.tap(find.byKey(PlayerProfilePage.messageKey));
    await tester.pumpAndSettle();

    expect(find.text('landed /players/u-2/chat علی'), findsOneWidget);
  });

  testWidgets('home leads to the search and to my games', (tester) async {
    await pumpRouter(tester, [
      GoRoute(path: '/', builder: (context, state) => homeWithBadges()),
      landingRoute(Routes.search),
      landingRoute(Routes.matches),
    ]);

    await tester.tap(find.byKey(HomePage.searchKey));
    await tester.pumpAndSettle();
    expect(find.text('landed /search'), findsOneWidget);

    GoRouter.of(tester.element(find.text('landed /search'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomePage.matchesKey));
    await tester.pumpAndSettle();
    expect(find.text('landed /matches'), findsOneWidget);
  });
}
