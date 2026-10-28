import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/search_models.dart';

part 'search_api.g.dart';

/// The partner search and saved-search endpoints, on the `apiDio` client.
@RestApi()
abstract class SearchApi {
  factory SearchApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _SearchApi;

  /// Null members are left out of the query; [venueIds] is repeated (`venueIds=a&venueIds=b`) and [weekdays] is
  /// comma-separated.
  @GET(ApiPaths.searchPartners)
  Future<ApiResponse<SearchResultsModel>> partners(
    @Query('sportId') String sportId, {
    @Query('cityId') int? cityId,
    @Query('venueIds') List<String>? venueIds,
    @Query('date') String? date,
    @Query('weekdays') String? weekdays,
    @Query('from') String? from,
    @Query('to') String? to,
    @Query('minLevel') String? minLevel,
    @Query('maxLevel') String? maxLevel,
    @Query('gender') String? gender,
    @Query('format') String? format,
    @Query('cursor') String? cursor,
    @Query('results') String? results,
  });

  @GET(ApiPaths.savedSearches)
  Future<ApiResponse<List<SavedSearchModel>>> savedSearches();

  @POST(ApiPaths.savedSearches)
  Future<ApiResponse<SavedSearchModel>> createSavedSearch(@Body() SavedSearchRequestModel body);

  @PUT(ApiPaths.savedSearch)
  Future<ApiResponse<SavedSearchModel>> updateSavedSearch(@Path('id') String id, @Body() SavedSearchRequestModel body);

  /// 204, no body.
  @DELETE(ApiPaths.savedSearch)
  Future<void> deleteSavedSearch(@Path('id') String id);
}

/// Registers [SearchApi] with get_it.
@module
abstract class SearchModule {
  @lazySingleton
  SearchApi searchApi(@Named(DioNames.api) Dio dio) => SearchApi(dio);
}
