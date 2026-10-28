import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/my_matches_cubit.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_matches.dart';

/// The player's games: upcoming and past load together, each with its own state.
void main() {
  late FakeMatchRepository matches;

  setUp(() => matches = FakeMatchRepository());

  Future<MyMatchesCubit> open() async {
    final cubit = MyMatchesCubit(matches, FakeCatalogRepository());
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  test('both lists, as the server ordered them, with the catalog for level names', () async {
    final cubit = await open();

    expect(matches.calls, containsAll(['getMine:upcoming', 'getMine:past']));
    expect(cubit.state.upcoming.status, ViewStatus.content);
    expect(cubit.state.upcoming.matches.map((m) => m.id), ['m-1', 'm-2']);
    expect(cubit.state.past.status, ViewStatus.content);
    expect(cubit.state.past.matches.map((m) => m.id), ['m-9']);
    expect(cubit.state.sportById('s-tennis')?.nameFa, 'تنیس');
  });

  test('no games: each list is empty on its own', () async {
    matches.upcoming = [];

    final cubit = await open();

    expect(cubit.state.upcoming.status, ViewStatus.empty);
    expect(cubit.state.past.status, ViewStatus.content);
  });

  test('a failure is an error to retry, in the player\'s words', () async {
    matches.loadFailure = const NetworkFailure(AppStrings.offlineActionError);

    final cubit = await open();

    expect(cubit.state.upcoming.status, ViewStatus.error);
    expect(cubit.state.upcoming.errorMessage, AppStrings.offlineActionError);
    expect(cubit.state.past.status, ViewStatus.error);

    matches.loadFailure = null;
    await cubit.load();
    expect(cubit.state.upcoming.status, ViewStatus.content);
  });
}
