import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/catalog_repository.dart';
import '../../domain/entities/venue.dart';
import 'catalog_load_status.dart';

part 'venue_picker_state.dart';

/// What a `VenuePicker` is opened with.
class VenuePickerArgs extends Equatable {
  /// [maxSelection] is clamped to 1–5.
  VenuePickerArgs({required this.cityId, this.sportCode, int maxSelection = 1, this.initialSelection = const []})
    : maxSelection = maxSelection.clamp(minSelectionLimit, maxSelectionLimit);

  static const int minSelectionLimit = 1;
  static const int maxSelectionLimit = 5;

  final int cityId;

  /// Only venues with courts for this sport, when set.
  final String? sportCode;
  final int maxSelection;

  /// Venues already chosen, e.g. when editing a profile.
  final List<Venue> initialSelection;

  @override
  List<Object?> get props => [cityId, sportCode, maxSelection, initialSelection];
}

/// Venue search and multi-select: the server is searched as the player types (debounced, so a word typed quickly
/// is one request), and at most [VenuePickerArgs.maxSelection] venues can be selected.
@injectable
class VenuePickerCubit extends Cubit<VenuePickerState> {
  VenuePickerCubit(this._repository, @factoryParam VenuePickerArgs args, {@ignoreParam this.debounce = defaultDebounce})
    : _args = args,
      super(
        VenuePickerState(
          maxSelection: args.maxSelection,
          selected: args.initialSelection.take(args.maxSelection).toList(growable: false),
        ),
      );

  static const Duration defaultDebounce = Duration(milliseconds: 400);

  final CatalogRepository _repository;
  final VenuePickerArgs _args;

  /// How long typing must pause before the server is searched.
  final Duration debounce;

  Timer? _debounceTimer;
  int _searchSeq = 0;
  String? _lastSearched;

  /// Loads the sport names for the tags and the city's venues. Called once when the picker opens.
  Future<void> start() async {
    await Future.wait([_loadSportNames(), _search(state.query)]);
  }

  /// The player typed. The search runs once typing pauses for [debounce].
  void queryChanged(String query) {
    emit(state.copyWith(query: query));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (query.trim() != _lastSearched) unawaited(_search(query));
    });
  }

  /// Repeats the failed search now.
  Future<void> retry() {
    _debounceTimer?.cancel();
    return _search(state.query);
  }

  /// Selects [venue], or unselects it when it is selected. Selecting past the limit is refused, and
  /// [VenuePickerState.limitHits] goes up so the screen can say why.
  void toggle(Venue venue) {
    if (state.isSelected(venue.id)) {
      emit(state.copyWith(selected: [...state.selected.where((v) => v.id != venue.id)]));
    } else if (state.isFull) {
      emit(state.copyWith(limitHits: state.limitHits + 1));
    } else {
      emit(state.copyWith(selected: [...state.selected, venue]));
    }
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    _lastSearched = query.trim();
    emit(state.copyWith(status: CatalogLoadStatus.loading, errorMessage: () => null));
    final result = await _repository.searchVenues(cityId: _args.cityId, sportCode: _args.sportCode, query: query);
    // A later search was started while this one was out: its answer is the one to show.
    if (isClosed || seq != _searchSeq) return;
    result.fold((failure) {
      _lastSearched = null;
      emit(state.copyWith(status: CatalogLoadStatus.failure, errorMessage: () => failure.message));
    }, (venues) => emit(state.copyWith(status: CatalogLoadStatus.ready, results: venues)));
  }

  /// Sport names are only for the tags: without them a tag shows the sport's code.
  Future<void> _loadSportNames() async {
    final result = await _repository.getSports();
    if (isClosed) return;
    result.fold((_) {}, (sports) => emit(state.copyWith(sportNames: {for (final s in sports) s.code: s.nameFa})));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
