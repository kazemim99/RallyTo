import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/rating.dart';
import '../domain/rating_repository.dart';
import 'models/rating_models.dart';
import 'rating_api.dart';

/// [RatingRepository] over [RatingApi].
@LazySingleton(as: RatingRepository)
class RatingRepositoryImpl implements RatingRepository {
  RatingRepositoryImpl(this._api);

  final RatingApi _api;

  @override
  Future<Either<Failure, String>> rate(String matchId, RatingDraft draft) async {
    final result = await safeApiCall(() => _api.rate(matchId, RatingInputModel.fromDraft(draft)));
    return result.map((receipt) => receipt.id);
  }
}
