import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';
import 'package:rallyto_app/features/search/domain/search_rules.dart';
import 'package:rallyto_app/features/search/presentation/bloc/partner_search_cubit.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/fake_search.dart';

/// Partner search: the profile's defaults, the first page with posts, more players page by page without repeats,
/// filters checked before searching, and saving the current filters.
void main() {
  late FakeSearchRepository search;
  late FakeProfileRepository profiles;

  setUp(() {
    search = FakeSearchRepository();
    profiles = FakeProfileRepository();
  });

  Future<PartnerSearchCubit> open({SearchFilters? initial}) async {
    final cubit = PartnerSearchCubit(search, profiles, FakeCatalogRepository(), initial, clock: () => testNow);
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  group('loading', () {
    test("searches straight away with the profile's defaults", () async {
      final cubit = await open();
      final state = cubit.state;

      expect(state.setupStatus, ViewStatus.content);
      expect(state.sports.map((s) => s.code), ['tennis']);
      expect(state.filters, SearchRules.defaults(profiles.profile, tennis()));
      expect(search.searches.single, (state.filters, null));
      expect(state.resultsStatus, ViewStatus.content);
      expect(state.players.map((p) => p.userId), ['u-2', 'u-3']);
      expect(state.posts.map((m) => m.id), ['m-7']);
      expect(state.hasMore, isTrue);
    });

    test('a same-gender-only player always searches her own gender', () async {
      profiles.profile = testMyProfile(visibility: ProfileVisibility.sameGender);

      final cubit = await open(initial: const SearchFilters(sportId: 's-tennis'));

      expect(cubit.state.lockedGender, Gender.female);
      expect(cubit.state.filters?.gender, Gender.female);
      expect(search.searches.single.$1.gender, Gender.female);

      cubit.applyFilters(cubit.state.filters!.copyWith(gender: () => null));
      expect(cubit.state.filters?.gender, Gender.female);
    });

    test('filters passed in (a saved search) replace the defaults; the profile city keeps its name', () async {
      final saved = testSavedSearch().filters;

      final cubit = await open(initial: saved);

      expect(cubit.state.filters?.weekdays, {Weekday.saturday});
      expect(cubit.state.filters?.fromMinute, 18 * 60);
      expect(cubit.state.filters?.cityName, 'تهران');
    });

    test("a saved search in another city keeps that city's name and its clubs' names, from the server", () async {
      final saved = testSavedSearch().filters.copyWith(
        cityId: () => 20,
        cityName: 'اصفهان',
        venues: const [NamedRef(id: 'v-9', name: 'باشگاه نقش جهان')],
      );

      final cubit = await open(initial: saved);

      expect(cubit.state.filters?.cityId, 20);
      expect(cubit.state.filters?.cityName, 'اصفهان');
      expect(cubit.state.filters?.venues.single.name, 'باشگاه نقش جهان');
    });

    test('without a sport profile there is nothing to search', () async {
      profiles.profile = testMyProfile(sports: const []);

      final cubit = await open();

      expect(cubit.state.setupStatus, ViewStatus.empty);
      expect(search.searches, isEmpty);
    });

    test('a profile that cannot be loaded is an error to retry', () async {
      final cubit = PartnerSearchCubit(search, _FailingProfiles(), FakeCatalogRepository(), null, clock: () => testNow);
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.setupStatus, ViewStatus.error);
      expect(cubit.state.setupError, AppStrings.offlineActionError);
    });
  });

  group('results', () {
    test('nothing found is empty', () async {
      search.pages = {null: const SearchResults()};

      expect((await open()).state.resultsStatus, ViewStatus.empty);
    });

    test('61 searches a minute: the app says to wait', () async {
      search.searchFailure = const ServerFailure('x', code: SearchErrorCodes.tooManyRequests, statusCode: 429);

      final cubit = await open();

      expect(cubit.state.resultsStatus, ViewStatus.error);
      expect(cubit.state.resultsError, AppStrings.tooManyRequestsError);
    });

    test('the next page adds players not already shown; posts come with the first page only', () async {
      final cubit = await open();

      await cubit.loadMore();

      expect(search.searches.last.$2, 'page-2');
      expect(cubit.state.players.map((p) => p.userId), ['u-2', 'u-3', 'u-4']);
      expect(cubit.state.posts.map((m) => m.id), ['m-7']);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.loadingMore, isFalse);

      await cubit.loadMore();
      expect(search.searches, hasLength(2), reason: 'no page after the last');
    });

    test('a failed next page keeps the results and says why', () async {
      final cubit = await open();
      search.searchFailure = const NetworkFailure(AppStrings.offlineActionError);

      await cubit.loadMore();

      expect(cubit.state.players, hasLength(2));
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.feedback?.message, AppStrings.offlineActionError);
      expect(cubit.state.feedback?.isError, isTrue);
    });

    test('the result type is asked of the server (results=), not filtered on the device', () async {
      final cubit = await open();
      expect(search.resultTypes, [SearchResultType.both]);

      await cubit.resultTypeSelected(SearchResultType.players);
      expect(search.resultTypes.last, SearchResultType.players);
      expect(cubit.state.posts, isEmpty);
      expect(cubit.state.players, hasLength(2));

      await cubit.resultTypeSelected(SearchResultType.posts);
      expect(search.resultTypes.last, SearchResultType.posts);
      expect(cubit.state.players, isEmpty);
      expect(cubit.state.posts, hasLength(1));

      await cubit.resultTypeSelected(SearchResultType.posts);
      expect(search.searches, hasLength(3), reason: 'choosing the type shown does not search again');
    });

    test('the next page keeps asking for the chosen result type', () async {
      final cubit = await open();
      await cubit.resultTypeSelected(SearchResultType.players);

      await cubit.loadMore();

      expect(search.resultTypes, [SearchResultType.both, SearchResultType.players, SearchResultType.players]);
      expect(search.searches.last.$2, 'page-2');
    });

    test('an answer for filters since replaced is dropped', () async {
      final cubit = await open();
      final gate = Completer<void>();
      search.searchGate = gate;
      final first = cubit.state.filters!;
      unawaited(cubit.search());
      search.pages = {
        null: SearchResults(players: [testPartner(id: 'u-8')]),
      };
      search.searchGate = null;
      cubit.applyFilters(first.copyWith(fromMinute: 18 * 60));
      await Future<void>.delayed(Duration.zero);
      search.pages = {
        null: SearchResults(players: [testPartner(id: 'u-9')]),
      };
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.filters?.fromMinute, 18 * 60);
      expect(cubit.state.players.map((p) => p.userId), ['u-8']);
    });
  });

  group('filters', () {
    test('applying new filters searches again from the first page', () async {
      final cubit = await open();
      await cubit.loadMore();

      final error = cubit.applyFilters(
        cubit.state.filters!.copyWith(date: () => Jalali(1405, 8, 2), fromMinute: 18 * 60, toMinute: 22 * 60),
      );
      await Future<void>.delayed(Duration.zero);

      expect(error, isNull);
      expect(search.searches.last.$2, isNull);
      expect(search.searches.last.$1.date, Jalali(1405, 8, 2));
      expect(cubit.state.players.map((p) => p.userId), ['u-2', 'u-3']);
    });

    test('an end before the start, or a date past 30 days, is refused before searching', () async {
      final cubit = await open();
      final filters = cubit.state.filters!;

      expect(cubit.applyFilters(filters.copyWith(fromMinute: 22 * 60, toMinute: 20 * 60)), AppStrings.invalidTimeRange);
      expect(cubit.applyFilters(filters.copyWith(date: () => Jalali(1405, 9, 2))), AppStrings.searchDateOutOfRange);
      expect(cubit.applyFilters(filters.copyWith(date: () => Jalali(1405, 7, 30))), AppStrings.searchDateOutOfRange);
      expect(search.searches, hasLength(1));
      expect(cubit.dateOptions.last, Jalali(1405, 9, 1));
    });

    test('another sport takes its own level range and drops the clubs and format', () async {
      profiles.profile = testMyProfile(
        sports: const [
          testTennisProfile,
          SportProfile(sportId: 's-padel', sportCode: 'padel', level: LevelTier.professional, levelName: 'حرفه‌ای'),
        ],
      );
      final cubit = await open();
      final current = cubit.state.filters!.copyWith(
        venues: const [NamedRef(id: 'v-1', name: 'الف')],
        format: () => PlayFormat.singles,
        fromMinute: 18 * 60,
      );

      final padel = cubit.filtersForSport(current, 's-padel');

      expect(padel.sportId, 's-padel');
      expect(padel.minLevel, LevelTier.advanced);
      expect(padel.maxLevel, LevelTier.professional);
      expect(padel.venues, isEmpty);
      expect(padel.format, isNull);
      expect(padel.fromMinute, 18 * 60, reason: 'when is kept');
    });
  });

  group('saving the search', () {
    test('saves the current filters under a name, with alerts', () async {
      final cubit = await open();

      final error = await cubit.saveSearch('شنبه‌شب‌ها');

      expect(error, isNull);
      expect(search.created.single, ('شنبه‌شب‌ها', true, cubit.state.filters));
      expect(cubit.state.feedback?.message, AppStrings.searchSaved);
      expect(cubit.state.saving, isFalse);
    });

    test('a name of 1 to 40 characters', () async {
      final cubit = await open();

      expect(await cubit.saveSearch('  '), AppStrings.invalidSavedSearchName);
      expect(search.created, isEmpty);
    });

    test('the sixth is refused: at most 5', () async {
      final cubit = await open();
      search.savedFailure = const ServerFailure('x', code: SearchErrorCodes.tooManySavedSearches, statusCode: 409);

      final error = await cubit.saveSearch('ششم', alertsEnabled: false);

      expect(error, AppStrings.tooManySavedSearches);
      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.feedback?.code, SearchErrorCodes.tooManySavedSearches);
    });
  });
}

class _FailingProfiles extends FakeProfileRepository {
  @override
  Future<Either<Failure, MyProfile>> getMyProfile() async => const Left(NetworkFailure(AppStrings.offlineActionError));
}
