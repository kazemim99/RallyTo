part of 'venue_picker_cubit.dart';

class VenuePickerState extends Equatable {
  const VenuePickerState({
    required this.maxSelection,
    this.query = '',
    this.status = CatalogLoadStatus.loading,
    this.results = const [],
    this.selected = const [],
    this.sportNames = const {},
    this.limitHits = 0,
    this.errorMessage,
  });

  final int maxSelection;

  /// The search as typed.
  final String query;

  /// The state of the latest search.
  final CatalogLoadStatus status;

  /// The latest search's venues. Kept while the next search loads, so the list does not flash.
  final List<Venue> results;

  /// In the order selected. Kept across searches.
  final List<Venue> selected;

  /// Persian sport names by code, for the tags.
  final Map<String, String> sportNames;

  /// How many times selecting past [maxSelection] was refused.
  final int limitHits;
  final String? errorMessage;

  bool get isFull => selected.length >= maxSelection;

  bool isSelected(String venueId) => selected.any((v) => v.id == venueId);

  VenuePickerState copyWith({
    String? query,
    CatalogLoadStatus? status,
    List<Venue>? results,
    List<Venue>? selected,
    Map<String, String>? sportNames,
    int? limitHits,
    String? Function()? errorMessage,
  }) => VenuePickerState(
    maxSelection: maxSelection,
    query: query ?? this.query,
    status: status ?? this.status,
    results: results ?? this.results,
    selected: selected ?? this.selected,
    sportNames: sportNames ?? this.sportNames,
    limitHits: limitHits ?? this.limitHits,
    errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
  );

  @override
  List<Object?> get props => [maxSelection, query, status, results, selected, sportNames, limitHits, errorMessage];
}
