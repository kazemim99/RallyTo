import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';
import 'package:rallyto_app/features/search/domain/search_repository.dart';

import 'fake_matches.dart';

/// A [SearchRepository] answering from what the test set, recording what it was asked.
class FakeSearchRepository implements SearchRepository {
  /// Pages by cursor: null is the first page.
  Map<String?, SearchResults> pages = {
    null: SearchResults(
      players: [
        testPartner(id: 'u-2'),
        testPartner(id: 'u-3', name: 'رضا'),
      ],
      posts: [testMatch(id: 'm-7')],
      nextCursor: 'page-2',
    ),
    'page-2': SearchResults(
      players: [
        testPartner(id: 'u-3', name: 'رضا'),
        testPartner(id: 'u-4', name: 'مینا'),
      ],
    ),
  };

  List<SavedSearch> saved = [testSavedSearch(id: 'ss-1'), testSavedSearch(id: 'ss-2', alertsEnabled: false)];

  /// When set, searches answer with it.
  Failure? searchFailure;

  /// When set, saved-search calls answer with it.
  Failure? savedFailure;

  /// When set, searches wait on it.
  Completer<void>? searchGate;

  final List<(SearchFilters, String?)> searches = [];

  /// The `results=` of every search, in order.
  final List<SearchResultType> resultTypes = [];
  final List<(String name, bool alerts, SearchFilters filters)> created = [];
  final List<(String id, String name, bool alerts, SearchFilters filters)> updated = [];
  final List<String> deleted = [];

  /// Answers like the server: only the asked-for kind of results.
  @override
  Future<Either<Failure, SearchResults>> searchPartners(
    SearchFilters filters, {
    String? cursor,
    SearchResultType results = SearchResultType.both,
  }) async {
    searches.add((filters, cursor));
    resultTypes.add(results);
    await searchGate?.future;
    final failure = searchFailure;
    if (failure != null) return Left(failure);
    final page = pages[cursor] ?? const SearchResults();
    return Right(
      SearchResults(
        players: results == SearchResultType.posts ? const [] : page.players,
        posts: results == SearchResultType.players ? const [] : page.posts,
        nextCursor: results == SearchResultType.posts ? null : page.nextCursor,
      ),
    );
  }

  @override
  Future<Either<Failure, List<SavedSearch>>> getSavedSearches() async {
    final failure = savedFailure;
    return failure == null ? Right(saved) : Left(failure);
  }

  @override
  Future<Either<Failure, SavedSearch>> createSavedSearch({
    required String name,
    required bool alertsEnabled,
    required SearchFilters filters,
  }) async {
    created.add((name, alertsEnabled, filters));
    final failure = savedFailure;
    return failure == null
        ? Right(testSavedSearch(id: 'ss-new', name: name, alertsEnabled: alertsEnabled))
        : Left(failure);
  }

  @override
  Future<Either<Failure, SavedSearch>> updateSavedSearch(
    String id, {
    required String name,
    required bool alertsEnabled,
    required SearchFilters filters,
  }) async {
    updated.add((id, name, alertsEnabled, filters));
    final failure = savedFailure;
    return failure == null ? Right(testSavedSearch(id: id, name: name, alertsEnabled: alertsEnabled)) : Left(failure);
  }

  @override
  Future<Either<Failure, Unit>> deleteSavedSearch(String id) async {
    deleted.add(id);
    final failure = savedFailure;
    return failure == null ? const Right(unit) : Left(failure);
  }
}

PartnerResult testPartner({
  String id = 'u-2',
  String name = 'علی',
  ReliabilityTier? reliability,
  double? ratingAverage,
  int ratingCount = 0,
}) => PartnerResult(
  userId: id,
  displayName: name,
  reliability: reliability,
  ratingAverage: ratingAverage,
  ratingCount: ratingCount,
  gender: Gender.male,
  ageRange: '25-34',
  level: LevelTier.intermediate,
  levelName: 'متوسط',
  experience: ExperienceBand.oneToThreeYears,
  lastActive: LastActive.today,
  windows: const [
    MatchingWindow(
      availabilityId: 'w-1',
      venues: [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')],
      weekdays: [Weekday.saturday],
      startTime: '18:00',
      endTime: '24:00',
      overlapStart: '20:00',
      overlapEnd: '22:00',
      formats: [PlayFormat.singles],
    ),
  ],
);

SavedSearch testSavedSearch({String id = 'ss-1', String name = 'شنبه‌شب‌ها', bool alertsEnabled = true}) => SavedSearch(
  id: id,
  name: name,
  alertsEnabled: alertsEnabled,
  filters: const SearchFilters(
    sportId: 's-tennis',
    cityId: 10,
    cityName: 'تهران',
    venues: [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')],
    weekdays: {Weekday.saturday},
    fromMinute: 18 * 60,
    toMinute: 22 * 60,
    minLevel: LevelTier.lowerIntermediate,
    maxLevel: LevelTier.advanced,
  ),
);
