import 'package:equatable/equatable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../availability/domain/entities/availability_window.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';
import '../../../ratings/domain/entities/rating.dart';

/// Which results a search asks for (`results=Both|Players|Posts`): the server returns only those.
enum SearchResultType {
  both('Both'),
  players('Players'),
  posts('Posts');

  const SearchResultType(this.wire);

  final String wire;
}

/// What a partner search asks for (spec partner-search › Search input and defaults). Minutes are from midnight on
/// Tehran's clock; 1440 is «24:00».
class SearchFilters extends Equatable {
  const SearchFilters({
    required this.sportId,
    this.cityId,
    this.cityName = '',
    this.venues = const [],
    this.date,
    this.weekdays = const {},
    this.fromMinute = 0,
    this.toMinute = endOfDay,
    this.minLevel,
    this.maxLevel,
    this.gender,
    this.format,
  });

  static const int endOfDay = 24 * 60;

  final String sportId;

  /// Null: the player's profile city.
  final int? cityId;
  final String cityName;

  /// Empty: every club in the city that offers the sport.
  final List<NamedRef> venues;

  /// One day, or null to search by [weekdays].
  final Jalali? date;

  /// Ignored when [date] is set. Empty: any day.
  final Set<Weekday> weekdays;
  final int fromMinute;
  final int toMinute;

  /// Null: the player's level for the sport ± 1 tier.
  final LevelTier? minLevel;
  final LevelTier? maxLevel;

  /// Null: any. Forced to the player's own for a same-gender-only player.
  final Gender? gender;

  /// Null: any format.
  final PlayFormat? format;

  bool get isWholeDay => fromMinute == 0 && toMinute == endOfDay;

  SearchFilters copyWith({
    String? sportId,
    int? Function()? cityId,
    String? cityName,
    List<NamedRef>? venues,
    Jalali? Function()? date,
    Set<Weekday>? weekdays,
    int? fromMinute,
    int? toMinute,
    LevelTier? Function()? minLevel,
    LevelTier? Function()? maxLevel,
    Gender? Function()? gender,
    PlayFormat? Function()? format,
  }) => SearchFilters(
    sportId: sportId ?? this.sportId,
    cityId: cityId == null ? this.cityId : cityId(),
    cityName: cityName ?? this.cityName,
    venues: venues ?? this.venues,
    date: date == null ? this.date : date(),
    weekdays: weekdays ?? this.weekdays,
    fromMinute: fromMinute ?? this.fromMinute,
    toMinute: toMinute ?? this.toMinute,
    minLevel: minLevel == null ? this.minLevel : minLevel(),
    maxLevel: maxLevel == null ? this.maxLevel : maxLevel(),
    gender: gender == null ? this.gender : gender(),
    format: format == null ? this.format : format(),
  );

  @override
  List<Object?> get props => [
    sportId,
    cityId,
    cityName,
    venues,
    date,
    weekdays,
    fromMinute,
    toMinute,
    minLevel,
    maxLevel,
    gender,
    format,
  ];
}

/// The availability window of a result that matched, with the time it overlaps the search.
class MatchingWindow extends Equatable {
  const MatchingWindow({
    required this.availabilityId,
    required this.startTime,
    required this.endTime,
    required this.overlapStart,
    required this.overlapEnd,
    this.venues = const [],
    this.weekdays = const [],
    this.date,
    this.formats = const [],
  });

  final String availabilityId;

  /// The clubs the window shares with the search.
  final List<NamedRef> venues;

  /// Saturday first; empty for a one-off window.
  final List<Weekday> weekdays;

  /// Jalali «1405/08/02» for a one-off window.
  final String? date;

  /// «HH:mm».
  final String startTime;
  final String endTime;
  final String overlapStart;
  final String overlapEnd;
  final List<PlayFormat> formats;

  @override
  List<Object?> get props => [
    availabilityId,
    venues,
    weekdays,
    date,
    startTime,
    endTime,
    overlapStart,
    overlapEnd,
    formats,
  ];
}

/// A player whose availability overlaps the search. No phone, birth date or exact activity time.
class PartnerResult extends Equatable {
  const PartnerResult({
    required this.userId,
    required this.displayName,
    required this.ageRange,
    required this.levelName,
    this.photoUrl,
    this.gender,
    this.level,
    this.experience,
    this.lastActive,
    this.windows = const [],
    this.reliability,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final Gender? gender;
  final String ageRange;
  final LevelTier? level;

  /// The sport's own Persian name for [level].
  final String levelName;
  final ExperienceBand? experience;
  final LastActive? lastActive;

  /// Best overlap first.
  final List<MatchingWindow> windows;

  /// The reliability tier across sports; null when the server does not know it (`Unknown`) or sent a value this app
  /// does not know.
  final ReliabilityTier? reliability;

  /// The star average in the searched sport; null below 3 revealed ratings (a new player).
  final double? ratingAverage;

  /// Revealed ratings in the searched sport.
  final int ratingCount;

  @override
  List<Object?> get props => [
    userId,
    displayName,
    photoUrl,
    gender,
    ageRange,
    level,
    levelName,
    experience,
    lastActive,
    windows,
    reliability,
    ratingAverage,
    ratingCount,
  ];
}

/// One page of results: players ranked by fit, open posts soonest first (first page only), and the token for the
/// next page of players.
class SearchResults extends Equatable {
  const SearchResults({this.players = const [], this.posts = const [], this.nextCursor});

  final List<PartnerResult> players;
  final List<Match> posts;

  /// Null on the last page.
  final String? nextCursor;

  @override
  List<Object?> get props => [players, posts, nextCursor];
}

/// A search the player saved, with alerts for new matches.
class SavedSearch extends Equatable {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.alertsEnabled,
    required this.filters,
    this.alertsSent = 0,
    this.pendingMatches = 0,
    this.lastAlertAt,
    this.expiresOn,
  });

  final String id;
  final String name;
  final bool alertsEnabled;
  final int alertsSent;

  /// Matches waiting for the next alert (at most one alert per 6 hours).
  final int pendingMatches;
  final DateTime? lastAlertAt;

  /// Jalali «1405/08/02», for a search on one date.
  final String? expiresOn;

  /// As the server resolved them: levels and gender filled in.
  final SearchFilters filters;

  SavedSearch copyWith({bool? alertsEnabled}) => SavedSearch(
    id: id,
    name: name,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    filters: filters,
    alertsSent: alertsSent,
    pendingMatches: pendingMatches,
    lastAlertAt: lastAlertAt,
    expiresOn: expiresOn,
  );

  @override
  List<Object?> get props => [id, name, alertsEnabled, alertsSent, pendingMatches, lastAlertAt, expiresOn, filters];
}
