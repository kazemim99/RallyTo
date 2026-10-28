import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'entities/report.dart';

/// Reports of players, messages, play posts and photos. Refusals carry the server's code ([ReportErrorCodes]).
abstract class ReportRepository {
  /// Files a report (and blocks the player behind it when asked). `ALREADY_REPORTED`, `MESSAGE_NOT_FOUND`,
  /// `PHOTO_NOT_FOUND`, `PLAYER_NOT_FOUND`, `MATCH_NOT_FOUND`, `CANNOT_REPORT_SELF`, `DETAILS_TOO_LONG`,
  /// `TOO_MANY_REQUESTS` when refused.
  Future<Either<Failure, ReportReceipt>> file(ReportDraft draft);

  /// This player's reports, with whether each is open or resolved.
  Future<Either<Failure, List<MyReport>>> getMine();
}
