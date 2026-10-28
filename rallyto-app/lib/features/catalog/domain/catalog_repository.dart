import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/place.dart';
import 'entities/sport.dart';
import 'entities/venue.dart';

/// The reference data players pick from: sports, provinces, cities and venues.
///
/// Sports, provinces and cities are cached in memory for the app session; sports are also kept on the device, so
/// onboarding still works when the server cannot be reached. Venue searches are never cached.
abstract class CatalogRepository {
  /// Every sport, in the server's sort order.
  Future<Either<Failure, List<Sport>>> getSports();

  Future<Either<Failure, List<Province>>> getProvinces();

  /// [provinceId]'s cities, those with clubs first (the server's order).
  Future<Either<Failure, List<City>>> getCities(int provinceId);

  /// The visible venues in [cityId], optionally only those with courts for [sportCode] and whose name or address
  /// matches [query] (sent as typed: the server normalises Persian text).
  Future<Either<Failure, List<Venue>>> searchVenues({required int cityId, String? sportCode, String? query});

  /// One venue; a `NotFoundFailure` when it is hidden or gone.
  Future<Either<Failure, Venue>> getVenue(String id);
}
