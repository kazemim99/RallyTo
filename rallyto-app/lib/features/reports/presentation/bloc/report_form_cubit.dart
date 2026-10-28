import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/report.dart';
import '../../domain/report_repository.dart';
import '../../domain/report_rules.dart';
import '../report_labels.dart';

/// Reporting a player, a message, a play post or a profile photo: a reason, optional details (up to 1000 characters)
/// and, in the same step, blocking the player behind it.
@injectable
class ReportFormCubit extends Cubit<ReportFormState> {
  ReportFormCubit(this._reports, @factoryParam ReportTarget target) : super(ReportFormState(target: target));

  final ReportRepository _reports;

  void setReason(ReportReason reason) => emit(state.copyWith(reason: reason));

  void setDetails(String details) => emit(state.copyWith(details: details));

  void setBlock(bool block) => emit(state.copyWith(block: block));

  /// Sends the report once; a missing reason or over-long details are said first, without asking the server.
  Future<void> submit() async {
    if (state.submitting || state.done) return;
    final problem = ReportRules.check(state.reason, state.details);
    if (problem != null) {
      emit(state.copyWith(feedback: ProfileFeedback(ReportLabels.rule(problem), isError: true, code: problem)));
      return;
    }
    emit(state.copyWith(submitting: true));
    final result = await _reports.file(
      ReportDraft(target: state.target, reason: state.reason!, details: state.details, block: state.block),
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          submitting: false,
          feedback: ProfileFeedback(ReportLabels.error(failure), isError: true, code: failure.code),
        ),
      ),
      (_) => emit(
        state.copyWith(
          submitting: false,
          done: true,
          feedback: ProfileFeedback(state.block ? AppStrings.reportSentAndBlocked : AppStrings.reportSent),
        ),
      ),
    );
  }
}

class ReportFormState extends Equatable {
  const ReportFormState({
    required this.target,
    this.reason,
    this.details = '',
    this.block = false,
    this.submitting = false,
    this.done = false,
    this.feedback,
  });

  final ReportTarget target;
  final ReportReason? reason;
  final String details;

  /// Block the player behind the target in the same step.
  final bool block;
  final bool submitting;

  /// The report was filed: the form closes, saying whether the player was blocked too.
  final bool done;
  final ProfileFeedback? feedback;

  ReportFormState copyWith({
    ReportReason? reason,
    String? details,
    bool? block,
    bool? submitting,
    bool? done,
    ProfileFeedback? feedback,
  }) => ReportFormState(
    target: target,
    reason: reason ?? this.reason,
    details: details ?? this.details,
    block: block ?? this.block,
    submitting: submitting ?? this.submitting,
    done: done ?? this.done,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [target, reason, details, block, submitting, done, feedback];
}
