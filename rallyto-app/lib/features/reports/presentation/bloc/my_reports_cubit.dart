import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/widgets/state_switcher.dart';
import '../../domain/entities/report.dart';
import '../../domain/report_repository.dart';
import '../report_labels.dart';

/// «گزارش‌های من»: the reports this player filed, each open or resolved. The action taken is never shown.
@injectable
class MyReportsCubit extends Cubit<MyReportsState> {
  MyReportsCubit(this._reports) : super(const MyReportsState());

  final ReportRepository _reports;

  Future<void> load() async {
    emit(const MyReportsState());
    final result = await _reports.getMine();
    if (isClosed) return;
    result.fold(
      (failure) => emit(MyReportsState(status: ViewStatus.error, errorMessage: ReportLabels.error(failure))),
      (reports) => emit(
        MyReportsState(status: reports.isEmpty ? ViewStatus.empty : ViewStatus.content, reports: _newestFirst(reports)),
      ),
    );
  }

  static List<MyReport> _newestFirst(List<MyReport> reports) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return [...reports]..sort((a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch));
  }
}

class MyReportsState extends Equatable {
  const MyReportsState({this.status = ViewStatus.loading, this.reports = const [], this.errorMessage});

  final ViewStatus status;

  /// Newest first.
  final List<MyReport> reports;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, reports, errorMessage];
}
