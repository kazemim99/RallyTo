import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/catalog_repository.dart';
import 'package:rallyto_app/features/catalog/domain/entities/place.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/catalog/domain/entities/venue.dart';

/// A [CatalogRepository] answering from what the test set, recording what it was asked.
class FakeCatalogRepository implements CatalogRepository {
  Either<Failure, List<Sport>> sports = Right([tennis(), padel()]);
  Either<Failure, List<Province>> provinces = const Right(testProvinces);
  Map<int, Either<Failure, List<City>>> cities = {1: const Right(tehranCities), 2: const Right(isfahanCities)};
  Either<Failure, Venue> Function(String id) venue = (id) => Right(testVenue(id: id));

  /// Answers [searchVenues] from [query]; by default the venues whose name contains it.
  Either<Failure, List<Venue>> Function(String? query) venues = (query) => Right([
    for (final v in testVenues)
      if (query == null || v.name.contains(query)) v,
  ]);

  final List<int> citiesAskedFor = [];
  final List<({int cityId, String? sportCode, String? query})> searches = [];

  /// When set, venue searches wait on the gate their call found, so a test can answer them out of order.
  List<Completer<void>>? searchGates;

  @override
  Future<Either<Failure, List<Sport>>> getSports() async => sports;

  @override
  Future<Either<Failure, List<Province>>> getProvinces() async => provinces;

  @override
  Future<Either<Failure, List<City>>> getCities(int provinceId) async {
    citiesAskedFor.add(provinceId);
    return cities[provinceId] ?? const Right([]);
  }

  @override
  Future<Either<Failure, List<Venue>>> searchVenues({required int cityId, String? sportCode, String? query}) async {
    final index = searches.length;
    searches.add((cityId: cityId, sportCode: sportCode, query: query));
    final gates = searchGates;
    if (gates != null && index < gates.length) await gates[index].future;
    return venues(query);
  }

  @override
  Future<Either<Failure, Venue>> getVenue(String id) async => venue(id);
}

const List<Province> testProvinces = [Province(id: 1, name: 'تهران'), Province(id: 2, name: 'اصفهان')];

/// Clubs first, as the server orders them. «کرج» is not in Tehran province, but its spelling with ک and ی is what
/// the search tests need.
const List<City> tehranCities = [
  City(id: 10, provinceId: 1, name: 'تهران', activeVenueCount: 12),
  City(id: 11, provinceId: 1, name: 'شهریار', activeVenueCount: 2),
  City(id: 12, provinceId: 1, name: 'کرج'),
  City(id: 13, provinceId: 1, name: 'رباط‌کریم'),
];

const List<City> isfahanCities = [City(id: 20, provinceId: 2, name: 'اصفهان', activeVenueCount: 5)];

Sport tennis() => const Sport(
  id: 's-tennis',
  code: 'tennis',
  nameFa: 'تنیس',
  nameEn: 'Tennis',
  sortOrder: 1,
  isActive: true,
  defaultSessionMinutes: 90,
  formats: [
    SportFormat(format: PlayFormat.singles, playersPerSide: 1, capacity: 2),
    SportFormat(format: PlayFormat.doubles, playersPerSide: 2, capacity: 4),
  ],
  levels: [
    SportLevel(tier: LevelTier.beginner, order: 1, name: 'مبتدی', description: 'تازه راکت به دست گرفته‌اید'),
    SportLevel(
      tier: LevelTier.lowerIntermediate,
      order: 2,
      name: 'متوسط رو به پایین',
      description: 'رالی کوتاه را نگه می‌دارید',
    ),
    SportLevel(tier: LevelTier.intermediate, order: 3, name: 'متوسط', description: 'سرویس و بک‌هند مطمئن دارید'),
    SportLevel(tier: LevelTier.advanced, order: 4, name: 'پیشرفته', description: 'در مسابقات باشگاهی بازی می‌کنید'),
    SportLevel(tier: LevelTier.professional, order: 5, name: 'حرفه‌ای', description: 'بازیکن رده‌بندی‌شده هستید'),
  ],
  surfaces: [CourtSurface.hard, CourtSurface.clay],
);

Sport padel() => const Sport(
  id: 's-padel',
  code: 'padel',
  nameFa: 'پدل',
  nameEn: 'Padel',
  sortOrder: 2,
  isActive: true,
  defaultSessionMinutes: 90,
  formats: [SportFormat(format: PlayFormat.doubles, playersPerSide: 2, capacity: 4)],
  surfaces: [CourtSurface.artificialGrass],
);

Venue testVenue({
  String id = 'v-1',
  String name = 'باشگاه انقلاب',
  String? address = 'تهران، خیابان انقلاب',
  double? latitude = 35.7,
  double? longitude = 51.4,
  List<VenueSport> sports = const [
    VenueSport(sportCode: 'tennis', courtCount: 6, setting: CourtSetting.outdoor, surface: CourtSurface.clay),
  ],
}) => Venue(
  id: id,
  name: name,
  cityId: 10,
  cityName: 'تهران',
  address: address,
  latitude: latitude,
  longitude: longitude,
  status: 'Active',
  sports: sports,
);

final List<Venue> testVenues = [
  testVenue(id: 'v-1', name: 'باشگاه انقلاب'),
  testVenue(
    id: 'v-2',
    name: 'مجموعه آزادی',
    sports: const [
      VenueSport(sportCode: 'tennis', courtCount: 4),
      VenueSport(sportCode: 'padel', courtCount: 2, setting: CourtSetting.indoor),
    ],
  ),
  testVenue(id: 'v-3', name: 'باشگاه نیاوران'),
  testVenue(id: 'v-4', name: 'باشگاه ولنجک'),
];
