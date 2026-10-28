import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/search.dart';
import '../../domain/search_repository.dart';
import '../../domain/search_rules.dart';
import '../search_labels.dart';

/// Partner search (spec partner-search): filters with the profile's defaults (city, tier ± 1, own gender for a
/// same-gender-only player), results with player cards and open posts, paging with the continuation token, and saving
/// the current filters. [SearchFilters] passed in (a saved search, a game to fill) replace the defaults.
@injectable
class PartnerSearchCubit extends Cubit<PartnerSearchState> {
  PartnerSearchCubit(
    this._search,
    this._profiles,
    this._catalog,
    @factoryParam SearchFilters? initial, {
    @ignoreParam DateTime Function()? clock,
  }) : _initial = initial,
       _clock = clock ?? DateTime.now,
       super(const PartnerSearchState());

  final SearchRepository _search;
  final ProfileRepository _profiles;
  final CatalogRepository _catalog;
  final SearchFilters? _initial;
  final DateTime Function() _clock;

  /// Now, by the cubit's clock: whether a post still takes requests.
  DateTime get now => _clock();

  /// Today on Tehran's calendar.
  Jalali get today => JalaliDateText.today(now: _clock());

  /// The dates a search may ask for: today to 30 days ahead.
  List<Jalali> get dateOptions => [for (var i = 0; i <= SearchRules.maxDaysAhead; i++) today.addDays(i)];

  /// Loads the profile and the player's sports, sets the filters, and runs the first search.
  Future<void> load() async {
    emit(const PartnerSearchState());
    final catalog = _catalog.getSports();
    final profile = await _profiles.getMyProfile();
    final sports = await catalog;
    if (isClosed) return;
    final me = profile.fold((_) => null, (p) => p);
    if (me == null) {
      emit(PartnerSearchState(setupStatus: ViewStatus.error, setupError: profile.fold((f) => f.message, (_) => null)));
      return;
    }
    final have = {for (final s in me.sports) s.sportId};
    final offered = sports.fold(
      (_) => const <Sport>[],
      (all) => [
        for (final s in all)
          if (have.contains(s.id) && s.isActive) s,
      ],
    );
    if (offered.isEmpty) {
      emit(const PartnerSearchState(setupStatus: ViewStatus.empty));
      return;
    }
    final initial = _initial;
    final filters = initial == null
        ? SearchRules.defaults(me, offered.first)
        : SearchRules.enforce(_withCityName(initial, me), me);
    emit(PartnerSearchState(setupStatus: ViewStatus.content, profile: me, sports: offered, filters: filters));
    await search();
  }

  /// The defaults for switching the filter sheet to [sportId]: its level range and no club or format, keeping where
  /// and when.
  SearchFilters filtersForSport(SearchFilters current, String sportId) {
    final profile = state.profile;
    final (min, max) = SearchRules.levelRange(profile == null ? null : SearchRules.levelIn(profile, sportId));
    return current.copyWith(
      sportId: sportId,
      venues: const [],
      minLevel: () => min,
      maxLevel: () => max,
      format: () => null,
    );
  }

  /// The message for what is wrong with [filters], or null after they were applied and the search started.
  String? applyFilters(SearchFilters filters) {
    final timeCode = SearchRules.checkTime(filters.fromMinute, filters.toMinute);
    if (timeCode != null) return SearchLabels.rule(timeCode);
    final date = filters.date;
    if (date != null) {
      final dateCode = SearchRules.checkDate(date, today);
      if (dateCode != null) return SearchLabels.rule(dateCode);
    }
    final profile = state.profile;
    emit(state.copyWith(filters: profile == null ? filters : SearchRules.enforce(filters, profile)));
    unawaited(search());
    return null;
  }

  /// The first page for the current filters, of the chosen result type.
  Future<void> search() async {
    final filters = state.filters;
    final type = state.resultType;
    if (filters == null) return;
    emit(
      state.copyWith(
        resultsStatus: ViewStatus.loading,
        players: const [],
        posts: const [],
        nextCursor: () => null,
        loadingMore: false,
      ),
    );
    final result = await _search.searchPartners(filters, results: type);
    if (isClosed || state.filters != filters || state.resultType != type) return;
    result.fold(
      (failure) => emit(state.copyWith(resultsStatus: ViewStatus.error, resultsError: SearchLabels.error(failure))),
      (page) => emit(
        state.copyWith(
          resultsStatus: page.players.isEmpty && page.posts.isEmpty ? ViewStatus.empty : ViewStatus.content,
          players: page.players,
          posts: page.posts,
          nextCursor: () => page.nextCursor,
        ),
      ),
    );
  }

  /// The next page of players (posts come with the first page only). Players already shown are not repeated.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    final filters = state.filters;
    final type = state.resultType;
    if (cursor == null || filters == null || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final result = await _search.searchPartners(filters, cursor: cursor, results: type);
    if (isClosed || state.filters != filters || state.resultType != type) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingMore: false,
          feedback: ProfileFeedback(SearchLabels.error(failure), isError: true, code: failure.code),
        ),
      ),
      (page) {
        final shown = {for (final p in state.players) p.userId};
        emit(
          state.copyWith(
            loadingMore: false,
            players: [
              ...state.players,
              for (final p in page.players)
                if (!shown.contains(p.userId)) p,
            ],
            nextCursor: () => page.nextCursor,
          ),
        );
      },
    );
  }

  /// Asks the server again for [type] only (`results=`); choosing the type already shown does nothing.
  Future<void> resultTypeSelected(SearchResultType type) async {
    if (type == state.resultType) return;
    emit(state.copyWith(resultType: type));
    await search();
  }

  /// Saves the current filters under [name]. The message for what is wrong, or null once saved.
  Future<String?> saveSearch(String name, {bool alertsEnabled = true}) async {
    final filters = state.filters;
    if (filters == null || state.saving) return AppStrings.genericError;
    final nameCode = SearchRules.checkName(name);
    if (nameCode != null) return SearchLabels.rule(nameCode);
    emit(state.copyWith(saving: true));
    final result = await _search.createSavedSearch(name: name, alertsEnabled: alertsEnabled, filters: filters);
    if (isClosed) return null;
    return result.fold(
      (failure) {
        final message = SearchLabels.error(failure);
        emit(state.copyWith(saving: false, feedback: ProfileFeedback(message, isError: true, code: failure.code)));
        return message;
      },
      (_) {
        emit(state.copyWith(saving: false, feedback: const ProfileFeedback(AppStrings.searchSaved)));
        return null;
      },
    );
  }

  /// Filters passed in without a city's name (a game to fill) search the profile city, under its name.
  static SearchFilters _withCityName(SearchFilters filters, MyProfile me) {
    if (filters.cityName.isNotEmpty) return filters;
    if (filters.cityId == null || filters.cityId == me.city.id) {
      return filters.copyWith(cityId: () => me.city.id, cityName: me.city.name);
    }
    return filters;
  }
}

class PartnerSearchState extends Equatable {
  const PartnerSearchState({
    this.setupStatus = ViewStatus.loading,
    this.setupError,
    this.profile,
    this.sports = const [],
    this.filters,
    this.resultsStatus = ViewStatus.loading,
    this.resultsError,
    this.players = const [],
    this.posts = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.resultType = SearchResultType.both,
    this.saving = false,
    this.feedback,
  });

  /// Loading the profile and sports; [ViewStatus.empty] when the player has no sport profile to search.
  final ViewStatus setupStatus;
  final String? setupError;
  final MyProfile? profile;

  /// The player's sports, from the catalog.
  final List<Sport> sports;
  final SearchFilters? filters;
  final ViewStatus resultsStatus;
  final String? resultsError;
  final List<PartnerResult> players;
  final List<Match> posts;

  /// The token for the next page of players; null on the last page.
  final String? nextCursor;
  final bool loadingMore;
  final SearchResultType resultType;
  final bool saving;
  final ProfileFeedback? feedback;

  /// A same-gender-only player's gender, which every search is for; null for anyone else.
  Gender? get lockedGender => profile == null ? null : SearchRules.lockedGender(profile!);

  bool get hasMore => nextCursor != null;

  Sport? get sport {
    for (final s in sports) {
      if (s.id == filters?.sportId) return s;
    }
    return null;
  }

  PartnerSearchState copyWith({
    SearchFilters? filters,
    ViewStatus? resultsStatus,
    String? resultsError,
    List<PartnerResult>? players,
    List<Match>? posts,
    String? Function()? nextCursor,
    bool? loadingMore,
    SearchResultType? resultType,
    bool? saving,
    ProfileFeedback? feedback,
  }) => PartnerSearchState(
    setupStatus: setupStatus,
    setupError: setupError,
    profile: profile,
    sports: sports,
    filters: filters ?? this.filters,
    resultsStatus: resultsStatus ?? this.resultsStatus,
    resultsError: resultsError ?? this.resultsError,
    players: players ?? this.players,
    posts: posts ?? this.posts,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
    loadingMore: loadingMore ?? this.loadingMore,
    resultType: resultType ?? this.resultType,
    saving: saving ?? this.saving,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [
    setupStatus,
    setupError,
    profile,
    sports,
    filters,
    resultsStatus,
    resultsError,
    players,
    posts,
    nextCursor,
    loadingMore,
    resultType,
    saving,
    feedback,
  ];
}
