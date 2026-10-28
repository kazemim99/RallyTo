import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/rating.dart';

/// Ratings of the other players of a Completed game. Refusals carry the server's code ([RatingErrorCodes]).
abstract class RatingRepository {
  /// Sends a hidden, final rating; answers with its id. `RATING_NOT_ALLOWED`, `RATING_WINDOW_CLOSED`, `ALREADY_RATED`,
  /// `CANNOT_RATE_SELF`, `INVALID_STARS`, `TOO_MANY_TAGS`, `LEVEL_ACCURACY_REQUIRED`, `NOTE_TOO_LONG` when refused.
  Future<Either<Failure, String>> rate(String matchId, RatingDraft draft);
}
