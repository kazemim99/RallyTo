import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/search/data/search_api.dart';
import 'package:rallyto_app/features/search/data/search_repository_impl.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';

import '../../../helpers/fake_server.dart';

/// Partner search and saved searches over the real client stack, against the backend's contract (SearchController,
/// SearchCriteriaInput, SearchResultsView, SavedSearchView): weekdays comma-separated on the GET and a list in the
/// body, repeated venueIds, Jalali dates, «HH:mm» times, `results=`; the saved view's criteria come back in the input
/// shape, with the city's and clubs' names.
void main() {
  late FakeServer server;
  late SearchRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = SearchRepositoryImpl(SearchApi(server.dio()));
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  group('search', () {
    test('only the sport and what differs from the server defaults go in the query', () async {
      server.routes['GET /api/v1/search/partners'] = (_) => okBody(_resultsJson);

      await repository.searchPartners(const SearchFilters(sportId: 's-tennis'));

      expect(
        server.requests.single.uri.query,
        'sportId=s-tennis&results=Both',
        reason: 'the whole day, any day: nothing else',
      );
    });

    test('asks the server for players or posts only with results=', () async {
      server.routes['GET /api/v1/search/partners'] = (_) => okBody(_resultsJson);

      await repository.searchPartners(const SearchFilters(sportId: 's-tennis'), results: SearchResultType.players);
      await repository.searchPartners(const SearchFilters(sportId: 's-tennis'), results: SearchResultType.posts);

      expect([for (final r in server.requests) r.uri.queryParameters['results']], ['Players', 'Posts']);
    });

    test('weekdays are comma-separated (Saturday first), clubs repeated, times HH:mm, enums as strings', () async {
      server.routes['GET /api/v1/search/partners'] = (_) => okBody(_resultsJson);

      await repository.searchPartners(
        const SearchFilters(
          sportId: 's-tennis',
          cityId: 10,
          venues: [
            NamedRef(id: 'v-1', name: 'الف'),
            NamedRef(id: 'v-2', name: 'ب'),
          ],
          weekdays: {Weekday.monday, Weekday.saturday},
          fromMinute: 20 * 60,
          toMinute: 24 * 60,
          minLevel: LevelTier.intermediate,
          maxLevel: LevelTier.advanced,
          gender: Gender.female,
          format: PlayFormat.doubles,
        ),
        cursor: 'next',
      );

      final uri = server.requests.single.uri;
      expect(uri.queryParametersAll, {
        'sportId': ['s-tennis'],
        'cityId': ['10'],
        'venueIds': ['v-1', 'v-2'],
        'weekdays': ['Saturday,Monday'],
        'from': ['20:00'],
        'minLevel': ['Intermediate'],
        'maxLevel': ['Advanced'],
        'gender': ['Female'],
        'format': ['Doubles'],
        'cursor': ['next'],
        'results': ['Both'],
      });
    });

    test('a date search sends the Jalali date in ASCII digits, and no weekdays', () async {
      server.routes['GET /api/v1/search/partners'] = (_) => okBody(_resultsJson);

      await repository.searchPartners(
        SearchFilters(sportId: 's-tennis', date: Jalali(1405, 8, 2), weekdays: const {Weekday.friday}),
      );

      expect(server.requests.single.uri.queryParameters, {
        'sportId': 's-tennis',
        'date': '1405/08/02',
        'results': 'Both',
      });
    });

    test('reads players with their overlapping windows, posts, and the next cursor', () async {
      server.routes['GET /api/v1/search/partners'] = (_) => okBody(_resultsJson);

      final page = valueOf(await repository.searchPartners(const SearchFilters(sportId: 's-tennis')));

      final player = page.players.single;
      expect(player.userId, 'u-2');
      expect(player.displayName, 'علی');
      expect(player.gender, Gender.male);
      expect(player.level, LevelTier.intermediate);
      expect(player.levelName, 'متوسط');
      expect(player.lastActive, LastActive.thisWeek);
      expect(player.experience, isNull);
      final window = player.windows.single;
      expect(window.weekdays, [Weekday.saturday, Weekday.monday]);
      expect(window.overlapStart, '20:00');
      expect(window.overlapEnd, '22:00');
      expect(window.venues, const [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')]);
      expect(window.formats, [PlayFormat.singles]);
      expect(page.posts.single.status, MatchStatus.open);
      expect(page.nextCursor, 'bzoyMA==');
    });

    test("reads each player's reliability tier and star rating", () async {
      server.routes['GET /api/v1/search/partners'] = (_) => okBody(_resultsJson);

      final player = valueOf(await repository.searchPartners(const SearchFilters(sportId: 's-tennis'))).players.single;

      expect(player.reliability, ReliabilityTier.high);
      expect(player.ratingAverage, 4.8);
      expect(player.ratingCount, 18);
    });

    test('a new player has no average; an Unknown tier, or none at all, shows no chip', () async {
      Map<String, Object?> player(String id, Map<String, Object?> reputation) => {
        'userId': id,
        'displayName': 'بازیکن',
        'gender': 'Male',
        'ageRange': '25-34',
        'level': 'Beginner',
        'levelName': 'مبتدی',
        'lastActive': 'Today',
        'windows': const <Object?>[],
        ...reputation,
      };
      server.routes['GET /api/v1/search/partners'] = (_) => okBody({
        'players': [
          player('u-new', {'reliability': 'New', 'ratingAverage': null, 'ratingCount': 2}),
          player('u-unknown', {'reliability': 'Unknown', 'ratingAverage': 4, 'ratingCount': 3}),
          player('u-old', const {}),
        ],
        'posts': const <Object?>[],
        'nextCursor': null,
      });

      final players = valueOf(await repository.searchPartners(const SearchFilters(sportId: 's-tennis'))).players;

      expect([for (final p in players) p.reliability], [ReliabilityTier.newPlayer, null, null]);
      expect([for (final p in players) p.ratingAverage], [null, 4.0, null], reason: 'an integer average reads as 4.0');
      expect([for (final p in players) p.ratingCount], [2, 3, 0]);
    });

    test('the 61st search in a minute is 429 TOO_MANY_REQUESTS', () async {
      server.routes['GET /api/v1/search/partners'] = (_) =>
          errorBody(429, 'TOO_MANY_REQUESTS', 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.');

      final failure = failureOf(await repository.searchPartners(const SearchFilters(sportId: 's-tennis')));

      expect(failure.code, 'TOO_MANY_REQUESTS');
    });
  });

  group('saved searches', () {
    test('the criteria come back in the input shape (Jalali date, weekday names, «HH:mm»), with names', () async {
      server.routes['GET /api/v1/saved-searches'] = (_) => okBody([_savedJson, _savedDateJson]);

      final saved = valueOf(await repository.getSavedSearches());

      final weekly = saved.first;
      expect(weekly.name, 'شنبه‌شب‌ها');
      expect(weekly.alertsEnabled, isTrue);
      expect(weekly.pendingMatches, 2);
      expect(weekly.filters.sportId, 's-tennis');
      expect(weekly.filters.cityId, 10);
      expect(weekly.filters.cityName, 'تهران');
      expect(weekly.filters.weekdays, {Weekday.saturday, Weekday.monday});
      expect(weekly.filters.date, isNull);
      expect(weekly.filters.fromMinute, 18 * 60);
      expect(weekly.filters.toMinute, 24 * 60, reason: '«24:00»');
      expect(weekly.filters.minLevel, LevelTier.lowerIntermediate);
      expect(weekly.filters.gender, isNull);
      expect(weekly.filters.venues, const [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')]);

      final once = saved.last;
      expect(once.filters.date, Jalali(1405, 8, 10));
      expect(once.filters.weekdays, isEmpty);
      expect(once.filters.isWholeDay, isTrue);
      expect(once.expiresOn, '1405/08/10');
      expect(once.filters.gender, Gender.female);
      expect(once.filters.format, PlayFormat.doubles);
    });

    test('saving sends the name, the alerts and the criteria in the input shape', () async {
      server.routes['POST /api/v1/saved-searches'] = (_) => okBody(_savedJson, status: 201);

      final saved = valueOf(
        await repository.createSavedSearch(
          name: ' شنبه‌شب‌ها ',
          alertsEnabled: true,
          filters: const SearchFilters(
            sportId: 's-tennis',
            cityId: 10,
            weekdays: {Weekday.saturday},
            fromMinute: 18 * 60,
            toMinute: 22 * 60,
          ),
        ),
      );

      expect(server.lastJson, {
        'name': 'شنبه‌شب‌ها',
        'alertsEnabled': true,
        'criteria': {
          'sportId': 's-tennis',
          'cityId': 10,
          'weekdays': ['Saturday'],
          'from': '18:00',
          'to': '22:00',
        },
      });
      expect(saved.id, 'ss-1');
    });

    test('toggling alerts sends the whole search back; a date one with its Jalali date', () async {
      server.routes['PUT /api/v1/saved-searches/ss-2'] = (_) => okBody(_savedDateJson);
      server.routes['GET /api/v1/saved-searches'] = (_) => okBody([_savedDateJson]);
      final once = valueOf(await repository.getSavedSearches()).single;

      await repository.updateSavedSearch(once.id, name: once.name, alertsEnabled: false, filters: once.filters);

      expect(server.lastJson, {
        'name': 'جمعه',
        'alertsEnabled': false,
        'criteria': {
          'sportId': 's-padel',
          'cityId': 10,
          'date': '1405/08/10',
          'minLevel': 'Beginner',
          'maxLevel': 'Intermediate',
          'gender': 'Female',
          'format': 'Doubles',
        },
      });
    });

    test('the sixth is 409 TOO_MANY_SAVED_SEARCHES; delete is a 204', () async {
      server.routes['POST /api/v1/saved-searches'] = (_) =>
          errorBody(409, 'TOO_MANY_SAVED_SEARCHES', 'حداکثر ۵ جستجو را می‌توانید ذخیره کنید.');
      server.routes['DELETE /api/v1/saved-searches/ss-1'] = (_) => noContentBody();

      final failure = failureOf(
        await repository.createSavedSearch(
          name: 'ششم',
          alertsEnabled: true,
          filters: const SearchFilters(sportId: 's-tennis'),
        ),
      );
      expect(failure.code, 'TOO_MANY_SAVED_SEARCHES');
      expect(valueOf(await repository.deleteSavedSearch('ss-1')), unit);
    });
  });
}

const Map<String, Object?> _resultsJson = {
  'players': [
    {
      'userId': 'u-2',
      'displayName': 'علی',
      'photoUrl': null,
      'gender': 'Male',
      'ageRange': '25-34',
      'level': 'Intermediate',
      'levelName': 'متوسط',
      'experience': null,
      'lastActive': 'ThisWeek',
      'reliability': 'High',
      'ratingAverage': 4.8,
      'ratingCount': 18,
      'windows': [
        {
          'availabilityId': 'w-1',
          'venues': [
            {'id': 'v-1', 'name': 'باشگاه انقلاب'},
          ],
          'weekdays': ['Monday', 'Saturday'],
          'date': null,
          'startTime': '18:00',
          'endTime': '24:00',
          'overlapStart': '20:00',
          'overlapEnd': '22:00',
          'formats': ['Singles'],
        },
      ],
    },
  ],
  'posts': [
    {
      'id': 'm-7',
      'visibility': 'Public',
      'status': 'Open',
      'sport': {'id': 's-tennis', 'code': 'tennis', 'name': 'تنیس'},
      'format': 'Singles',
      'capacity': 2,
      'openSpots': 1,
      'venue': {'id': 'v-1', 'name': 'باشگاه انقلاب'},
      'date': '1405/08/02',
      'startTime': '19:00',
      'endTime': '20:30',
      'durationMinutes': 90,
      'startsAt': '2026-10-24T15:30:00Z',
      'host': {'userId': 'u-9', 'displayName': 'نرگس', 'level': 'Advanced'},
      'minLevel': 'Intermediate',
      'maxLevel': 'Advanced',
      'partnerGender': 'Any',
      'courtBooked': true,
      'playersBrought': 0,
      'shareUrl': 'https://rallyto.ir/m/abcdef123456',
      'participants': null,
      'myState': null,
    },
  ],
  'nextCursor': 'bzoyMA==',
};

const Map<String, Object?> _savedJson = {
  'id': 'ss-1',
  'name': 'شنبه‌شب‌ها',
  'alertsEnabled': true,
  'alertsSent': 1,
  'pendingMatches': 2,
  'lastAlertAt': '2026-10-22T10:00:00Z',
  'expiresOn': null,
  'criteria': {
    'sportId': 's-tennis',
    'cityId': 10,
    'venueIds': ['v-1'],
    'date': null,
    'weekdays': ['Saturday', 'Monday'],
    'from': '18:00',
    'to': '24:00',
    'minLevel': 'LowerIntermediate',
    'maxLevel': 'Advanced',
    'gender': null,
    'format': null,
  },
  'city': {'id': 10, 'name': 'تهران'},
  'venues': [
    {'id': 'v-1', 'name': 'باشگاه انقلاب'},
  ],
};

const Map<String, Object?> _savedDateJson = {
  'id': 'ss-2',
  'name': 'جمعه',
  'alertsEnabled': true,
  'alertsSent': 0,
  'pendingMatches': 0,
  'lastAlertAt': null,
  'expiresOn': '1405/08/10',
  'criteria': {
    'sportId': 's-padel',
    'cityId': 10,
    'venueIds': <Object>[],
    'date': '1405/08/10',
    'weekdays': <Object>[],
    'from': '00:00',
    'to': '24:00',
    'minLevel': 'Beginner',
    'maxLevel': 'Intermediate',
    'gender': 'Female',
    'format': 'Doubles',
  },
  'city': {'id': 10, 'name': 'تهران'},
  'venues': <Object>[],
};
