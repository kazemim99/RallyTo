import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/api/models/api_response.dart';
import '../../../core/errors/failures.dart';
import '../domain/availability_repository.dart';
import '../domain/entities/availability_window.dart';
import 'availability_api.dart';
import 'models/availability_models.dart';

/// [AvailabilityRepository] over [AvailabilityApi]. Nothing is cached.
@LazySingleton(as: AvailabilityRepository)
class AvailabilityRepositoryImpl implements AvailabilityRepository {
  AvailabilityRepositoryImpl(this._api);

  final AvailabilityApi _api;

  @override
  Future<Either<Failure, List<AvailabilityWindow>>> getMine() => _list(_api.mine);

  @override
  Future<Either<Failure, List<AvailabilityWindow>>> getForPlayer(String userId) => _list(() => _api.forPlayer(userId));

  @override
  Future<Either<Failure, AvailabilityWindow>> create(AvailabilityDraft draft) =>
      _one(() => _api.create(AvailabilityInputModel.fromDraft(draft)));

  @override
  Future<Either<Failure, AvailabilityWindow>> update(String id, AvailabilityDraft draft) =>
      _one(() => _api.update(id, AvailabilityInputModel.fromDraft(draft)));

  @override
  Future<Either<Failure, AvailabilityWindow>> pause(String id) => _one(() => _api.pause(id));

  @override
  Future<Either<Failure, AvailabilityWindow>> resume(String id) => _one(() => _api.resume(id));

  @override
  Future<Either<Failure, AvailabilityWindow>> confirm(String id) => _one(() => _api.confirm(id));

  @override
  Future<Either<Failure, Unit>> delete(String id) => safeNoContentCall(() => _api.delete(id));

  Future<Either<Failure, List<AvailabilityWindow>>> _list(
    Future<ApiResponse<List<AvailabilityViewModel>>> Function() request,
  ) async {
    final result = await safeApiCall(request);
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }

  Future<Either<Failure, AvailabilityWindow>> _one(
    Future<ApiResponse<AvailabilityViewModel>> Function() request,
  ) async {
    final result = await safeApiCall(request);
    return result.map((model) => model.toEntity());
  }
}
