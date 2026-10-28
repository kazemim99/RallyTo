import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/rating_models.dart';

part 'rating_api.g.dart';

/// The rating endpoint, on the `apiDio` client.
@RestApi()
abstract class RatingApi {
  factory RatingApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _RatingApi;

  /// 201 `{id}`.
  @POST(ApiPaths.matchRatings)
  Future<ApiResponse<RatingReceiptModel>> rate(@Path('id') String matchId, @Body() RatingInputModel body);
}

/// Registers [RatingApi] with get_it.
@module
abstract class RatingModule {
  @lazySingleton
  RatingApi ratingApi(@Named(DioNames.api) Dio dio) => RatingApi(dio);
}
