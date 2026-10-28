import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/dio_client.dart';
import 'package:rallyto_app/core/api/interceptors/error_interceptor.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';
import 'package:rallyto_app/features/catalog/data/catalog_api.dart';
import 'package:rallyto_app/features/catalog/data/catalog_repository_impl.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/catalog/domain/entities/venue.dart';

import '../../../helpers/memory_secure_storage.dart';

/// The catalog calls over the real client stack (error interceptor, retrofit, envelope) against the backend's
/// contract: string enums, the error envelope, and what is cached for how long.
void main() {
  late _FakeServer server;
  late MemorySecureStorage device;
  late CatalogRepositoryImpl repository;

  CatalogRepositoryImpl newRepository() {
    final dio = DioFactory.create(baseUrl: 'https://api.test', interceptors: [ErrorInterceptor()], logging: false)
      ..httpClientAdapter = server;
    return CatalogRepositoryImpl(CatalogApi(dio), SecureStorageService(device));
  }

  setUp(() {
    server = _FakeServer();
    device = MemorySecureStorage();
    repository = newRepository();
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  group('sports', () {
    setUp(() => server.routes['/api/v1/sports'] = (_) => _ok(_sportsJson));

    test('reads formats, Persian levels and surfaces from string enums, in sort order', () async {
      final sports = valueOf(await repository.getSports());

      expect(sports.map((s) => s.code), ['tennis', 'padel', 'squash']);
      final tennis = sports.first;
      expect(tennis.nameFa, 'تنیس');
      expect(tennis.formats, const [
        SportFormat(format: PlayFormat.singles, playersPerSide: 1, capacity: 2),
        SportFormat(format: PlayFormat.doubles, playersPerSide: 2, capacity: 4),
      ]);
      expect(tennis.levels.map((l) => l.tier), LevelTier.values, reason: 'ordered by `order`, lowest first');
      expect(tennis.levels.first.name, 'مبتدی');
      expect(tennis.levels.first.description, 'تازه شروع کرده‌اید');
      expect(tennis.surfaces, [CourtSurface.clay, CourtSurface.hard]);

      final padel = sports[1];
      expect(padel.formats.single, const SportFormat(format: PlayFormat.doubles, playersPerSide: 2, capacity: 4));
      final squash = sports[2];
      expect(squash.formats.single, const SportFormat(format: PlayFormat.singles, playersPerSide: 1, capacity: 2));
      expect(squash.levels, isEmpty, reason: 'a tier this app does not know is dropped, not a crash');
    });

    test('are fetched once per session', () async {
      await repository.getSports();
      await repository.getSports();

      expect(server.paths, ['/api/v1/sports']);
    });

    test('are kept on the device and served from there when the server cannot be reached', () async {
      await repository.getSports();
      expect(device.values[CatalogRepositoryImpl.sportsCacheKey], isNotNull);

      // A new app session, offline.
      server.routes['/api/v1/sports'] = (o) => throw DioException.connectionError(requestOptions: o, reason: 'off');
      final offline = newRepository();
      final sports = valueOf(await offline.getSports());

      expect(sports.map((s) => s.code), ['tennis', 'padel', 'squash']);
      expect(sports.first.levels.first.name, 'مبتدی');
    });

    test('the server stays the source of truth: a new session asks it again', () async {
      await repository.getSports();
      server.routes['/api/v1/sports'] = (_) => _ok([_sportsJson.last]);

      final sports = valueOf(await newRepository().getSports());

      expect(sports.map((s) => s.code), ['squash']);
      expect(server.paths, ['/api/v1/sports', '/api/v1/sports']);
    });

    test('offline with nothing on the device is said as such, and not cached', () async {
      server.routes['/api/v1/sports'] = (o) => throw DioException.connectionError(requestOptions: o, reason: 'off');

      final failure = failureOf(await repository.getSports());
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, AppStrings.offlineActionError);

      server.routes['/api/v1/sports'] = (_) => _ok(_sportsJson);
      expect(valueOf(await repository.getSports()), hasLength(3));
    });

    test('an unreadable device copy is ignored', () async {
      device.values[CatalogRepositoryImpl.sportsCacheKey] = '{not json';
      server.routes['/api/v1/sports'] = (_) => _error(503, 'SERVICE_UNAVAILABLE', 'سرویس در دسترس نیست');

      final failure = failureOf(await repository.getSports());

      expect(failure.message, 'سرویس در دسترس نیست');
    });
  });

  group('provinces and cities', () {
    setUp(() {
      server.routes['/api/v1/provinces'] = (_) => _ok([
        {'id': 1, 'name': 'تهران'},
        {'id': 2, 'name': 'اصفهان'},
      ]);
      server.routes['/api/v1/provinces/1/cities'] = (_) => _ok([
        {'id': 10, 'provinceId': 1, 'name': 'تهران', 'activeVenueCount': 12},
        {'id': 11, 'provinceId': 1, 'name': 'دماوند', 'activeVenueCount': 0},
      ]);
      server.routes['/api/v1/provinces/2/cities'] = (_) => _ok([
        {'id': 20, 'provinceId': 2, 'name': 'اصفهان', 'activeVenueCount': 3},
      ]);
    });

    test('provinces are fetched once per session', () async {
      final provinces = valueOf(await repository.getProvinces());
      await repository.getProvinces();

      expect(provinces.map((p) => p.name), ['تهران', 'اصفهان']);
      expect(server.paths, ['/api/v1/provinces']);
    });

    test("cities keep the server's order and are cached per province", () async {
      final tehran = valueOf(await repository.getCities(1));
      await repository.getCities(1);
      await repository.getCities(2);

      expect(tehran.map((c) => (c.name, c.activeVenueCount)), [('تهران', 12), ('دماوند', 0)]);
      expect(server.paths, ['/api/v1/provinces/1/cities', '/api/v1/provinces/2/cities']);
    });

    test('a failure is not cached', () async {
      server.routes['/api/v1/provinces/1/cities'] = (_) => _error(500, 'INTERNAL', 'خطای سرور');
      expect(failureOf(await repository.getCities(1)).message, 'خطای سرور');

      server.routes['/api/v1/provinces/1/cities'] = (_) => _ok(<Object>[]);
      expect(valueOf(await repository.getCities(1)), isEmpty);
      expect(server.paths, hasLength(2));
    });

    test('an answer the app cannot read is a generic error, not a crash', () async {
      server.routes['/api/v1/provinces'] = (_) => _ok([
        {'id': 'one', 'name': null},
      ]);

      expect(failureOf(await repository.getProvinces()).message, AppStrings.genericError);
    });
  });

  group('venues', () {
    setUp(() => server.routes['/api/v1/venues'] = (_) => _ok([_venueJson, _venueWithoutLocationJson]));

    test('sends the city, the sport code and the raw query, and reads courts per sport', () async {
      final venues = valueOf(await repository.searchVenues(cityId: 10, sportCode: 'tennis', query: 'انقلاب كرج'));

      expect(server.requests.single.queryParameters, {'cityId': 10, 'sport': 'tennis', 'q': 'انقلاب كرج'});
      final venue = venues.first;
      expect(venue.name, 'باشگاه انقلاب');
      expect(venue.cityName, 'تهران');
      expect(venue.hasLocation, isTrue);
      expect(
        venue.sports.first,
        const VenueSport(
          sportCode: 'tennis',
          courtCount: 6,
          setting: CourtSetting.outdoor,
          surface: CourtSurface.clay,
          hasLighting: true,
        ),
      );
      expect(venue.sports.last.setting, CourtSetting.both);
      expect(venues.last.hasLocation, isFalse);
      expect(venues.last.address, isNull, reason: 'a blank address is no address');
    });

    test('a blank query and no sport are left out', () async {
      await repository.searchVenues(cityId: 10, query: '   ');

      expect(server.requests.single.queryParameters, {'cityId': 10});
    });

    test('searches are never cached', () async {
      await repository.searchVenues(cityId: 10);
      await repository.searchVenues(cityId: 10);

      expect(server.paths, ['/api/v1/venues', '/api/v1/venues']);
    });

    test('one venue by id', () async {
      server.routes['/api/v1/venues/v-1'] = (_) => _ok(_venueJson);

      final venue = valueOf(await repository.getVenue('v-1'));

      expect(venue.id, 'v-1');
      expect(venue.phone, '02122334455');
    });

    test('a hidden venue is a 404, said in the server\'s words', () async {
      server.routes['/api/v1/venues/v-9'] = (_) => _error(404, 'VENUE_NOT_FOUND', 'باشگاه پیدا نشد');

      final failure = failureOf(await repository.getVenue('v-9'));

      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, 'باشگاه پیدا نشد');
      expect(failure.code, 'VENUE_NOT_FOUND');
    });

    test('a session that could not be renewed is a SessionExpiredFailure', () async {
      server.routes['/api/v1/venues'] = (_) => _error(401, 'UNAUTHORIZED', 'Unauthorized');

      expect(failureOf(await repository.searchVenues(cityId: 10)), isA<SessionExpiredFailure>());
    });
  });
}

final List<Map<String, Object?>> _sportsJson = [
  {
    'id': 's-padel',
    'code': 'padel',
    'nameFa': 'پدل',
    'nameEn': 'Padel',
    'sortOrder': 2,
    'isActive': true,
    'defaultSessionMinutes': 90,
    'formats': [
      {'format': 'Doubles', 'playersPerSide': 2, 'capacity': 4},
    ],
    'levels': <Object>[],
    'surfaces': ['ArtificialGrass', 'Glass'],
  },
  {
    'id': 's-tennis',
    'code': 'tennis',
    'nameFa': 'تنیس',
    'nameEn': 'Tennis',
    'sortOrder': 1,
    'isActive': true,
    'defaultSessionMinutes': 90,
    'formats': [
      {'format': 'Singles', 'playersPerSide': 1, 'capacity': 2},
      {'format': 'Doubles', 'playersPerSide': 2, 'capacity': 4},
    ],
    'levels': [
      {'tier': 'Professional', 'order': 5, 'name': 'حرفه‌ای', 'description': 'بازیکن رده‌بندی‌شده'},
      {'tier': 'Beginner', 'order': 1, 'name': 'مبتدی', 'description': 'تازه شروع کرده‌اید'},
      {'tier': 'LowerIntermediate', 'order': 2, 'name': 'متوسط رو به پایین', 'description': 'رالی کوتاه'},
      {'tier': 'Intermediate', 'order': 3, 'name': 'متوسط', 'description': 'سرویس مطمئن'},
      {'tier': 'Advanced', 'order': 4, 'name': 'پیشرفته', 'description': 'مسابقات باشگاهی'},
    ],
    'surfaces': ['Clay', 'Hard'],
  },
  {
    'id': 's-squash',
    'code': 'squash',
    'nameFa': 'اسکواش',
    'nameEn': 'Squash',
    'sortOrder': 4,
    'isActive': true,
    'defaultSessionMinutes': 60,
    'formats': [
      {'format': 'Singles', 'playersPerSide': 1, 'capacity': 2},
    ],
    'levels': [
      {'tier': 'Legendary', 'order': 9, 'name': 'افسانه‌ای', 'description': ''},
    ],
    'surfaces': ['Wood'],
  },
];

const Map<String, Object?> _venueJson = {
  'id': 'v-1',
  'name': 'باشگاه انقلاب',
  'cityId': 10,
  'cityName': 'تهران',
  'address': 'تهران، خیابان انقلاب',
  'phone': '02122334455',
  'latitude': 35.7,
  'longitude': 51.4,
  'status': 'Active',
  'googlePlaceId': 'place-1',
  'sports': [
    {'sportCode': 'tennis', 'courtCount': 6, 'setting': 'Outdoor', 'surface': 'Clay', 'hasLighting': true},
    {'sportCode': 'padel', 'courtCount': null, 'setting': 'Both', 'surface': null, 'hasLighting': false},
  ],
};

const Map<String, Object?> _venueWithoutLocationJson = {
  'id': 'v-2',
  'name': 'مجموعه آزادی',
  'cityId': 10,
  'cityName': 'تهران',
  'address': ' ',
  'phone': null,
  'latitude': null,
  'longitude': null,
  'status': 'Active',
  'googlePlaceId': null,
  'sports': <Object>[],
};

class _FakeServer implements HttpClientAdapter {
  /// Answers by path; an unknown path is a 404.
  final Map<String, ResponseBody Function(RequestOptions options)> routes = {};
  final List<RequestOptions> requests = [];

  List<String> get paths => [for (final r in requests) r.path];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes[options.path];
    return route == null ? _error(404, 'NOT_FOUND', 'Not found') : route(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(Object? data) => _json(200, {
  'success': true,
  'statusCode': 200,
  'message': 'Request completed successfully',
  'data': data,
  'metadata': {'traceId': 'trace-1'},
});

ResponseBody _error(int status, String code, String message) => _json(status, {
  'success': false,
  'statusCode': '$status',
  'message': message,
  'data': null,
  'error': {'code': code, 'message': message},
  'metadata': {'traceId': 'trace-1'},
});

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
