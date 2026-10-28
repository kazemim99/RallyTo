import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/api/client/safe_api_call.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/report.dart';
import '../domain/report_repository.dart';
import 'models/report_models.dart';
import 'report_api.dart';

/// [ReportRepository] over [ReportApi]. Nothing is cached.
@LazySingleton(as: ReportRepository)
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._api);

  final ReportApi _api;

  @override
  Future<Either<Failure, ReportReceipt>> file(ReportDraft draft) async {
    final result = await safeApiCall(() => _api.file(ReportInputModel.fromDraft(draft)));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, List<MyReport>>> getMine() async {
    final result = await safeApiCall(_api.mine);
    return result.map((models) => [for (final m in models) m.toEntity()]);
  }
}
