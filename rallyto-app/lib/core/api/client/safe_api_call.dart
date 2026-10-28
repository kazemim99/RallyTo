import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../constants/app_strings.dart';
import '../../errors/dio_failure_mapper.dart';
import '../../errors/failures.dart';
import '../models/api_response.dart';

/// Runs an API call and unwraps its envelope: `Right(data)` on success, `Left(failure)` otherwise. Repositories use
/// it so no Dio exception or envelope detail leaks past the data layer.
Future<Either<Failure, T>> safeApiCall<T>(Future<ApiResponse<T>> Function() request) async {
  try {
    final response = await request();
    final data = response.data;
    if (response.isSuccess && (data != null || null is T)) return Right(data as T);
    return Left(
      ServerFailure(
        response.error?.message ?? response.message ?? AppStrings.genericError,
        code: response.error?.code,
        statusCode: response.statusCode,
      ),
    );
  } on DioException catch (e) {
    return Left(mapDioFailure(e));
  } catch (_) {
    // An answer the app could not read (a contract mismatch): a generic error, not a crash.
    return const Left(ServerFailure(AppStrings.genericError));
  }
}

/// [safeApiCall] for a call answered with 204 and no envelope: `Right(unit)` on success.
Future<Either<Failure, Unit>> safeNoContentCall(Future<void> Function() request) async {
  try {
    await request();
    return const Right(unit);
  } on DioException catch (e) {
    return Left(mapDioFailure(e));
  } catch (_) {
    return const Left(ServerFailure(AppStrings.genericError));
  }
}
