import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/search.dart';

/// Partner search and saved searches. Nothing is cached. Refusals carry the server's code ([SearchErrorCodes]).
abstract class SearchRepository {
  /// One page of [results] (players, posts or both); [cursor] is the previous page's `nextCursor`. 429
  /// `TOO_MANY_REQUESTS` beyond 60 a minute.
  Future<Either<Failure, SearchResults>> searchPartners(
    SearchFilters filters, {
    String? cursor,
    SearchResultType results = SearchResultType.both,
  });

  Future<Either<Failure, List<SavedSearch>>> getSavedSearches();

  /// 409 `TOO_MANY_SAVED_SEARCHES` beyond 5.
  Future<Either<Failure, SavedSearch>> createSavedSearch({
    required String name,
    required bool alertsEnabled,
    required SearchFilters filters,
  });

  Future<Either<Failure, SavedSearch>> updateSavedSearch(
    String id, {
    required String name,
    required bool alertsEnabled,
    required SearchFilters filters,
  });

  Future<Either<Failure, Unit>> deleteSavedSearch(String id);
}
