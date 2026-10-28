import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../../core/api/client/dio_names.dart';
import '../../../core/api/config/api_config.dart';
import '../../../core/api/models/api_response.dart';
import 'models/report_models.dart';

part 'report_api.g.dart';

/// The report endpoints, on the `apiDio` client.
@RestApi()
abstract class ReportApi {
  factory ReportApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) = _ReportApi;

  /// 201 `{id, status}`.
  @POST(ApiPaths.reports)
  Future<ApiResponse<ReportReceiptModel>> file(@Body() ReportInputModel body);

  @GET(ApiPaths.myReports)
  Future<ApiResponse<List<MyReportModel>>> mine();
}

/// Registers [ReportApi] with get_it.
@module
abstract class ReportModule {
  @lazySingleton
  ReportApi reportApi(@Named(DioNames.api) Dio dio) => ReportApi(dio);
}
