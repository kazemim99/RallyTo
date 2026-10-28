import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/catalog_models.dart';

part 'catalog_api.g.dart';

/// The catalog endpoints, on the `apiDio` client: everything but the sports list needs a signed-in player.
@RestApi()
abstract class CatalogApi {
  factory CatalogApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _CatalogApi;

  @GET(ApiPaths.sports)
  Future<ApiResponse<List<SportModel>>> sports();

  @GET(ApiPaths.provinces)
  Future<ApiResponse<List<ProvinceModel>>> provinces();

  @GET(ApiPaths.provinceCities)
  Future<ApiResponse<List<CityModel>>> cities(@Path('id') int provinceId);

  /// Null [sport] and [q] are left out of the query.
  @GET(ApiPaths.venues)
  Future<ApiResponse<List<VenueModel>>> venues(
    @Query('cityId') int cityId, {
    @Query('sport') String? sport,
    @Query('q') String? q,
  });

  @GET(ApiPaths.venue)
  Future<ApiResponse<VenueModel>> venue(@Path('id') String id);
}

/// Registers [CatalogApi] with get_it.
@module
abstract class CatalogModule {
  @lazySingleton
  CatalogApi catalogApi(@Named(DioNames.api) Dio dio) => CatalogApi(dio);
}
