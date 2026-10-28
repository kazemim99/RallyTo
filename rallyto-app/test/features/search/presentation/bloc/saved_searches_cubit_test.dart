import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/search/domain/search_rules.dart';
import 'package:rallyto_app/features/search/presentation/bloc/saved_searches_cubit.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_search.dart';

/// Saved searches: listed, alerts toggled (the whole search goes back), deleted, at most 5.
void main() {
  late FakeSearchRepository search;

  setUp(() => search = FakeSearchRepository());

  Future<SavedSearchesCubit> open() async {
    final cubit = SavedSearchesCubit(search, FakeCatalogRepository());
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  test('lists the saved searches, with the catalog for their sport names', () async {
    final cubit = await open();

    expect(cubit.state.status, ViewStatus.content);
    expect(cubit.state.searches.map((s) => s.id), ['ss-1', 'ss-2']);
    expect(cubit.state.sportById('s-tennis')?.nameFa, 'تنیس');
    expect(cubit.state.canSaveMore, isTrue);
  });

  test('none saved is empty; five is the most', () async {
    search.saved = [];
    expect((await open()).state.status, ViewStatus.empty);

    search.saved = [for (var i = 0; i < SearchRules.maxSavedSearches; i++) testSavedSearch(id: 'ss-$i')];
    expect((await open()).state.canSaveMore, isFalse);
  });

  test('a failure is an error to retry', () async {
    search.savedFailure = const NetworkFailure(AppStrings.offlineActionError);

    final cubit = await open();

    expect(cubit.state.status, ViewStatus.error);
    expect(cubit.state.errorMessage, AppStrings.offlineActionError);
  });

  test('toggling alerts sends the search back as it was, with alerts the other way', () async {
    final cubit = await open();
    final first = cubit.state.searches.first;

    await cubit.toggleAlerts(first);

    expect(search.updated.single, ('ss-1', first.name, false, first.filters));
    expect(cubit.state.searches.first.alertsEnabled, isFalse);
    expect(cubit.state.feedback?.message, AppStrings.alertsOff);
    expect(cubit.state.busyId, isNull);

    await cubit.toggleAlerts(cubit.state.searches.last);
    expect(cubit.state.feedback?.message, AppStrings.alertsOn);
  });

  test('deleting removes it; the last one leaves the list empty', () async {
    search.saved = [testSavedSearch(id: 'ss-1')];
    final cubit = await open();

    await cubit.delete(cubit.state.searches.single);

    expect(search.deleted, ['ss-1']);
    expect(cubit.state.status, ViewStatus.empty);
    expect(cubit.state.feedback?.message, AppStrings.savedSearchDeleted);
  });

  test('a refusal keeps the list and says why', () async {
    final cubit = await open();
    search.savedFailure = const ServerFailure('x', code: SearchErrorCodes.dateOutOfRange);

    await cubit.toggleAlerts(cubit.state.searches.first);

    expect(cubit.state.searches.first.alertsEnabled, isTrue);
    expect(cubit.state.feedback?.message, AppStrings.searchDateOutOfRange);
    expect(cubit.state.feedback?.isError, isTrue);
    expect(cubit.state.busyId, isNull);
  });
}
