import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/search.dart';
import '../domain/search_repository.dart';
import 'models/search_models.dart';
import 'search_api.dart';

/// [SearchRepository] over [SearchApi]. Nothing is cached.
@LazySingleton(as: SearchRepository)
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._api);

  final SearchApi _api;

  @override
  Future<Either<Failure, SearchResults>> searchPartners(
    SearchFilters filters, {
    String? cursor,
    SearchResultType results = SearchResultType.both,
  }) async {
    final query = SearchQuery.of(filters);
    final result = await safeApiCall(
      () => _api.partners(
        filters.sportId,
        cityId: filters.cityId,
        venueIds: query.venueIds,
        date: query.date,
        weekdays: query.weekdays,
        from: query.from,
        to: query.to,
        minLevel: query.minLevel,
        maxLevel: query.maxLevel,
        gender: query.gender,
        format: query.format,
        cursor: cursor,
        results: results.wire,
      ),
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, List<SavedSearch>>> getSavedSearches() async {
    final result = await safeApiCall(_api.savedSearches);
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }

  @override
  Future<Either<Failure, SavedSearch>> createSavedSearch({
    required String name,
    required bool alertsEnabled,
    required SearchFilters filters,
  }) async {
    final result = await safeApiCall(() => _api.createSavedSearch(_request(name, alertsEnabled, filters)));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, SavedSearch>> updateSavedSearch(
    String id, {
    required String name,
    required bool alertsEnabled,
    required SearchFilters filters,
  }) async {
    final result = await safeApiCall(() => _api.updateSavedSearch(id, _request(name, alertsEnabled, filters)));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, Unit>> deleteSavedSearch(String id) => safeNoContentCall(() => _api.deleteSavedSearch(id));

  static SavedSearchRequestModel _request(String name, bool alertsEnabled, SearchFilters filters) =>
      SavedSearchRequestModel(
        name: name.trim(),
        alertsEnabled: alertsEnabled,
        criteria: SearchCriteriaInputModel.fromFilters(filters),
      );
}
