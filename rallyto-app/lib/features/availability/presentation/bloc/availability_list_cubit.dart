import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/availability_repository.dart';
import '../../domain/entities/availability_window.dart';

/// The player's availability windows, grouped by status, with pause, resume, confirm ("still available") and delete.
@injectable
class AvailabilityListCubit extends Cubit<AvailabilityListState> {
  AvailabilityListCubit(this._availability, this._catalog) : super(const AvailabilityListState());

  final AvailabilityRepository _availability;
  final CatalogRepository _catalog;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final sports = _catalog.getSports();
    final result = await _availability.getMine();
    final names = (await sports).fold((_) => const <String, String>{}, (s) => {for (final x in s) x.code: x.nameFa});
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: ViewStatus.error, errorMessage: failure.message)),
      (windows) => emit(
        state.copyWith(
          status: windows.isEmpty ? ViewStatus.empty : ViewStatus.content,
          windows: windows,
          sportNames: names,
        ),
      ),
    );
  }

  Future<void> pause(AvailabilityWindow window) =>
      _change(window, () => _availability.pause(window.id), AppStrings.availabilityPaused);

  Future<void> resume(AvailabilityWindow window) =>
      _change(window, () => _availability.resume(window.id), AppStrings.availabilityResumed);

  Future<void> confirm(AvailabilityWindow window) =>
      _change(window, () => _availability.confirm(window.id), AppStrings.availabilityConfirmed);

  Future<void> delete(AvailabilityWindow window) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: () => window.id));
    final result = await _availability.delete(window.id);
    if (isClosed) return;
    result.fold((failure) => _failed(failure), (_) {
      final windows = [...state.windows.where((w) => w.id != window.id)];
      emit(
        state.copyWith(
          busyId: () => null,
          windows: windows,
          status: windows.isEmpty ? ViewStatus.empty : ViewStatus.content,
          feedback: const ProfileFeedback(AppStrings.availabilityDeleted),
        ),
      );
    });
  }

  /// A window created or edited on the form: it replaces its old self, or joins the list.
  void saved(AvailabilityWindow window) {
    final exists = state.windows.any((w) => w.id == window.id);
    final windows = exists
        ? [for (final w in state.windows) w.id == window.id ? window : w]
        : [...state.windows, window];
    emit(
      state.copyWith(
        windows: windows,
        status: ViewStatus.content,
        feedback: const ProfileFeedback(AppStrings.availabilitySaved),
      ),
    );
  }

  Future<void> _change(
    AvailabilityWindow window,
    Future<Either<Failure, AvailabilityWindow>> Function() action,
    String done,
  ) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: () => window.id));
    final result = await action();
    if (isClosed) return;
    result.fold(
      _failed,
      (changed) => emit(
        state.copyWith(
          busyId: () => null,
          windows: [for (final w in state.windows) w.id == changed.id ? changed : w],
          feedback: ProfileFeedback(done),
        ),
      ),
    );
  }

  void _failed(Failure failure) => emit(
    state.copyWith(
      busyId: () => null,
      feedback: ProfileFeedback(failure.message, isError: true, code: failure.code),
    ),
  );
}

class AvailabilityListState extends Equatable {
  const AvailabilityListState({
    this.status = ViewStatus.loading,
    this.windows = const [],
    this.sportNames = const {},
    this.busyId,
    this.errorMessage,
    this.feedback,
  });

  final ViewStatus status;
  final List<AvailabilityWindow> windows;

  /// Persian names by sport code.
  final Map<String, String> sportNames;

  /// The window an action is running on.
  final String? busyId;
  final String? errorMessage;
  final ProfileFeedback? feedback;

  /// The windows by status, in the order shown: active, paused, expired. Statuses without windows are left out.
  Map<AvailabilityStatus, List<AvailabilityWindow>> get byStatus => {
    for (final status in AvailabilityStatus.values)
      if (windows.any((w) => w.status == status)) status: [...windows.where((w) => w.status == status)],
  };

  AvailabilityListState copyWith({
    ViewStatus? status,
    List<AvailabilityWindow>? windows,
    Map<String, String>? sportNames,
    String? Function()? busyId,
    String? errorMessage,
    ProfileFeedback? feedback,
  }) => AvailabilityListState(
    status: status ?? this.status,
    windows: windows ?? this.windows,
    sportNames: sportNames ?? this.sportNames,
    busyId: busyId == null ? this.busyId : busyId(),
    errorMessage: errorMessage ?? this.errorMessage,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, windows, sportNames, busyId, errorMessage, feedback];
}
