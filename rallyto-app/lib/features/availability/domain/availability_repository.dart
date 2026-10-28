import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/availability_window.dart';

/// The player's availability windows, and other players' active ones. Nothing is cached.
abstract class AvailabilityRepository {
  /// Every window of this player, whatever its status.
  Future<Either<Failure, List<AvailabilityWindow>>> getMine();

  /// [userId]'s active windows.
  Future<Either<Failure, List<AvailabilityWindow>>> getForPlayer(String userId);

  /// 409 `TOO_MANY_WINDOWS` or `OVERLAPPING_WINDOW`, or a rule's code (`WINDOW_TOO_SHORT`, …) when refused.
  Future<Either<Failure, AvailabilityWindow>> create(AvailabilityDraft draft);

  Future<Either<Failure, AvailabilityWindow>> update(String id, AvailabilityDraft draft);

  Future<Either<Failure, AvailabilityWindow>> pause(String id);

  Future<Either<Failure, AvailabilityWindow>> resume(String id);

  /// "Still available": a recurring window not confirmed for 30 days pauses itself.
  Future<Either<Failure, AvailabilityWindow>> confirm(String id);

  Future<Either<Failure, Unit>> delete(String id);
}
