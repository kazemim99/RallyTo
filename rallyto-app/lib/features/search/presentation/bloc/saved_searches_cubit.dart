import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/search.dart';
import '../../domain/search_repository.dart';
import '../../domain/search_rules.dart';
import '../search_labels.dart';

/// The player's saved searches (at most 5): alerts turned on or off, and deleted.
@injectable
class SavedSearchesCubit extends Cubit<SavedSearchesState> {
  SavedSearchesCubit(this._search, this._catalog) : super(const SavedSearchesState());

  final SearchRepository _search;
  final CatalogRepository _catalog;

  Future<void> load() async {
    emit(const SavedSearchesState());
    final sports = _catalog.getSports();
    final result = await _search.getSavedSearches();
    final catalog = (await sports).fold((_) => const <Sport>[], (s) => s);
    if (isClosed) return;
    result.fold(
      (failure) => emit(SavedSearchesState(status: ViewStatus.error, errorMessage: SearchLabels.error(failure))),
      (searches) => emit(
        SavedSearchesState(
          status: searches.isEmpty ? ViewStatus.empty : ViewStatus.content,
          searches: searches,
          sports: catalog,
        ),
      ),
    );
  }

  /// Turns [search]'s alerts the other way. The server takes the whole search back, as it resolved it.
  Future<void> toggleAlerts(SavedSearch search) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: () => search.id));
    final enable = !search.alertsEnabled;
    final result = await _search.updateSavedSearch(
      search.id,
      name: search.name,
      alertsEnabled: enable,
      filters: search.filters,
    );
    if (isClosed) return;
    result.fold(
      _failed,
      (updated) => emit(
        state.copyWith(
          busyId: () => null,
          searches: [for (final s in state.searches) s.id == updated.id ? updated : s],
          feedback: ProfileFeedback(enable ? AppStrings.alertsOn : AppStrings.alertsOff),
        ),
      ),
    );
  }

  Future<void> delete(SavedSearch search) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: () => search.id));
    final result = await _search.deleteSavedSearch(search.id);
    if (isClosed) return;
    result.fold(_failed, (_) {
      final searches = [...state.searches.where((s) => s.id != search.id)];
      emit(
        state.copyWith(
          busyId: () => null,
          searches: searches,
          status: searches.isEmpty ? ViewStatus.empty : ViewStatus.content,
          feedback: const ProfileFeedback(AppStrings.savedSearchDeleted),
        ),
      );
    });
  }

  void _failed(Failure failure) => emit(
    state.copyWith(
      busyId: () => null,
      feedback: ProfileFeedback(SearchLabels.error(failure), isError: true, code: failure.code),
    ),
  );
}

class SavedSearchesState extends Equatable {
  const SavedSearchesState({
    this.status = ViewStatus.loading,
    this.searches = const [],
    this.sports = const [],
    this.busyId,
    this.errorMessage,
    this.feedback,
  });

  final ViewStatus status;
  final List<SavedSearch> searches;

  /// The catalog's sports, for names and level names.
  final List<Sport> sports;

  /// The saved search an action is running on.
  final String? busyId;
  final String? errorMessage;
  final ProfileFeedback? feedback;

  /// Whether another search can be saved.
  bool get canSaveMore => searches.length < SearchRules.maxSavedSearches;

  Sport? sportById(String id) {
    for (final sport in sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  SavedSearchesState copyWith({
    ViewStatus? status,
    List<SavedSearch>? searches,
    String? Function()? busyId,
    ProfileFeedback? feedback,
  }) => SavedSearchesState(
    status: status ?? this.status,
    searches: searches ?? this.searches,
    sports: sports,
    busyId: busyId == null ? this.busyId : busyId(),
    errorMessage: errorMessage,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, searches, sports, busyId, errorMessage, feedback];
}
