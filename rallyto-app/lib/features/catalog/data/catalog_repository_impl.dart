import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/errors/failures.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/catalog_repository.dart';
import '../domain/entities/place.dart';
import '../domain/entities/sport.dart';
import '../domain/entities/venue.dart';
import 'catalog_api.dart';
import 'models/catalog_models.dart';

/// [CatalogRepository] over [CatalogApi].
///
/// Caching, decided per kind of data:
/// * sports, provinces and cities change rarely and are the same for every player: kept in memory for the app
///   session once fetched (a failure is not cached, so the next call asks again);
/// * sports are also written to the device after every successful fetch. The server stays the source of truth: the
///   device copy is used only when the server cannot answer, so onboarding works offline;
/// * venue searches are never cached: every call asks the server.
@LazySingleton(as: CatalogRepository)
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._api, this._storage);

  /// Versioned, so a later change to the stored shape starts from an empty cache instead of misreading it.
  static const String sportsCacheKey = 'catalog_sports_v1';

  final CatalogApi _api;
  final SecureStorageService _storage;

  List<Sport>? _sports;
  List<Province>? _provinces;
  final Map<int, List<City>> _cities = {};

  @override
  Future<Either<Failure, List<Sport>>> getSports() async {
    final cached = _sports;
    if (cached != null) return Right(cached);

    final result = await safeApiCall(_api.sports);
    return result.fold(
      (failure) async {
        final stored = await _readStoredSports();
        return stored == null ? Left(failure) : Right(_toSports(stored));
      },
      (models) async {
        final sports = _toSports(models);
        _sports = sports;
        await _storeSports(models);
        return Right(sports);
      },
    );
  }

  @override
  Future<Either<Failure, List<Province>>> getProvinces() async {
    final cached = _provinces;
    if (cached != null) return Right(cached);
    final result = await safeApiCall(_api.provinces);
    return result.map((models) => _provinces = List.unmodifiable([for (final m in models) m.toEntity()]));
  }

  @override
  Future<Either<Failure, List<City>>> getCities(int provinceId) async {
    final cached = _cities[provinceId];
    if (cached != null) return Right(cached);
    final result = await safeApiCall(() => _api.cities(provinceId));
    return result.map((models) => _cities[provinceId] = List.unmodifiable([for (final m in models) m.toEntity()]));
  }

  @override
  Future<Either<Failure, List<Venue>>> searchVenues({required int cityId, String? sportCode, String? query}) async {
    final result = await safeApiCall(() => _api.venues(cityId, sport: _nullIfBlank(sportCode), q: _nullIfBlank(query)));
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }

  @override
  Future<Either<Failure, Venue>> getVenue(String id) async {
    final result = await safeApiCall(() => _api.venue(id));
    return result.map((model) => model.toEntity());
  }

  static List<Sport> _toSports(List<SportModel> models) {
    final sports = <Sport>[for (final m in models) m.toEntity()]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(sports);
  }

  static String? _nullIfBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();

  /// The device copy, or null when there is none or it cannot be read.
  Future<List<SportModel>?> _readStoredSports() async {
    try {
      final raw = await _storage.read(sportsCacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return null;
      return [for (final item in decoded) SportModel.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  /// Best effort: a write that fails leaves the previous copy, and never fails the call.
  Future<void> _storeSports(List<SportModel> models) async {
    try {
      await _storage.write(sportsCacheKey, jsonEncode([for (final m in models) m.toJson()]));
    } catch (_) {
      // The memory cache still serves this session.
    }
  }
}
