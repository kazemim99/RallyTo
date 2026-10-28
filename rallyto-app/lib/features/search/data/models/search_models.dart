import 'package:json_annotation/json_annotation.dart';

import '../../../../core/utils/jalali_date_text.dart';
import '../../../availability/domain/availability_rules.dart';
import '../../../availability/domain/entities/availability_window.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../matches/data/models/match_models.dart';
import '../../../profile/data/models/profile_models.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';
import '../../../ratings/domain/entities/rating.dart';
import '../../domain/entities/search.dart';

part 'search_models.g.dart';

/// `MatchingWindowView`.
@JsonSerializable(createToJson: false)
class MatchingWindowModel {
  const MatchingWindowModel({
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

  factory MatchingWindowModel.fromJson(Map<String, dynamic> json) => _$MatchingWindowModelFromJson(json);

  final String availabilityId;
  final List<NamedRefModel> venues;
  final List<String> weekdays;
  final String? date;
  final String startTime;
  final String endTime;
  final String overlapStart;
  final String overlapEnd;
  final List<String> formats;

  MatchingWindow toEntity() {
    final days = {for (final d in weekdays) ?Weekday.tryParse(d)};
    return MatchingWindow(
      availabilityId: availabilityId,
      venues: [for (final v in venues) v.toEntity()],
      weekdays: [
        for (final d in Weekday.values)
          if (days.contains(d)) d,
      ],
      date: date,
      startTime: startTime,
      endTime: endTime,
      overlapStart: overlapStart,
      overlapEnd: overlapEnd,
      formats: [for (final f in formats) ?PlayFormat.tryParse(f)],
    );
  }
}

/// `PartnerResultView`.
@JsonSerializable(createToJson: false)
class PartnerResultModel {
  const PartnerResultModel({
    required this.userId,
    this.displayName = '',
    this.photoUrl,
    this.gender,
    this.ageRange = '',
    this.level,
    this.levelName = '',
    this.experience,
    this.lastActive,
    this.windows = const [],
    this.reliability,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  factory PartnerResultModel.fromJson(Map<String, dynamic> json) => _$PartnerResultModelFromJson(json);

  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? gender;
  final String ageRange;
  final String? level;
  final String levelName;
  final String? experience;
  final String? lastActive;
  final List<MatchingWindowModel> windows;

  /// "New" | "Low" | "Good" | "High" | "Unknown".
  final String? reliability;

  /// Null below 3 revealed ratings.
  final double? ratingAverage;
  final int ratingCount;

  PartnerResult toEntity() => PartnerResult(
    userId: userId,
    displayName: displayName,
    photoUrl: photoUrl == null || photoUrl!.isEmpty ? null : photoUrl,
    gender: Gender.tryParse(gender),
    ageRange: ageRange,
    level: LevelTier.tryParse(level),
    levelName: levelName,
    experience: ExperienceBand.tryParse(experience),
    lastActive: LastActive.tryParse(lastActive),
    windows: [for (final w in windows) w.toEntity()],
    reliability: ReliabilityTier.tryParse(reliability),
    ratingAverage: ratingAverage,
    ratingCount: ratingCount < 0 ? 0 : ratingCount,
  );
}

/// `SearchResultsView`.
@JsonSerializable(createToJson: false)
class SearchResultsModel {
  const SearchResultsModel({this.players = const [], this.posts = const [], this.nextCursor});

  factory SearchResultsModel.fromJson(Map<String, dynamic> json) => _$SearchResultsModelFromJson(json);

  final List<PartnerResultModel> players;
  final List<MatchViewModel> posts;
  final String? nextCursor;

  SearchResults toEntity() => SearchResults(
    players: [for (final p in players) p.toEntity()],
    posts: [for (final p in posts) p.toEntity()],
    nextCursor: nextCursor == null || nextCursor!.isEmpty ? null : nextCursor,
  );
}

/// The `criteria` of a `SavedSearchView`, in the shape it is sent in (`SearchCriteriaInput`): a Jalali date or null,
/// weekday names, and «HH:mm» times (`to` may be «24:00»). The view names the city and the clubs beside it.
@JsonSerializable(createToJson: false)
class SearchCriteriaModel {
  const SearchCriteriaModel({
    required this.sportId,
    this.cityId,
    this.venueIds = const [],
    this.date,
    this.weekdays = const [],
    this.from,
    this.to,
    this.minLevel,
    this.maxLevel,
    this.gender,
    this.format,
  });

  factory SearchCriteriaModel.fromJson(Map<String, dynamic> json) => _$SearchCriteriaModelFromJson(json);

  final String sportId;
  final int? cityId;
  final List<String> venueIds;
  final String? date;
  final List<String> weekdays;
  final String? from;
  final String? to;
  final String? minLevel;
  final String? maxLevel;
  final String? gender;
  final String? format;

  /// The filters, with the city's and the clubs' names from the view.
  SearchFilters toEntity({CityRefModel? city, List<NamedRefModel> venues = const []}) {
    final days = {for (final d in weekdays) ?Weekday.tryParse(d)};
    final names = {for (final v in venues) v.id: v.name};
    final id = cityId ?? city?.id;
    return SearchFilters(
      sportId: sportId,
      cityId: id,
      cityName: city != null && city.id == id ? city.name : '',
      venues: [for (final venueId in venueIds) NamedRef(id: venueId, name: names[venueId] ?? '')],
      date: JalaliDateText.tryParse(date),
      weekdays: days,
      fromMinute: TimeOfDayText.tryParse(from) ?? 0,
      toMinute: TimeOfDayText.tryParse(to) ?? SearchFilters.endOfDay,
      minLevel: LevelTier.tryParse(minLevel),
      maxLevel: LevelTier.tryParse(maxLevel),
      gender: Gender.tryParse(gender),
      format: PlayFormat.tryParse(format),
    );
  }
}

/// `SavedSearchView`.
@JsonSerializable(createToJson: false)
class SavedSearchModel {
  const SavedSearchModel({
    required this.id,
    required this.criteria,
    this.name = '',
    this.alertsEnabled = false,
    this.alertsSent = 0,
    this.pendingMatches = 0,
    this.lastAlertAt,
    this.expiresOn,
    this.city,
    this.venues = const [],
  });

  factory SavedSearchModel.fromJson(Map<String, dynamic> json) => _$SavedSearchModelFromJson(json);

  final String id;
  final String name;
  final bool alertsEnabled;
  final int alertsSent;
  final int pendingMatches;
  final String? lastAlertAt;
  final String? expiresOn;
  final SearchCriteriaModel criteria;

  /// The criteria's city, named.
  final CityRefModel? city;

  /// The criteria's clubs, named.
  final List<NamedRefModel> venues;

  SavedSearch toEntity() => SavedSearch(
    id: id,
    name: name,
    alertsEnabled: alertsEnabled,
    alertsSent: alertsSent,
    pendingMatches: pendingMatches,
    lastAlertAt: lastAlertAt == null ? null : DateTime.tryParse(lastAlertAt!),
    expiresOn: expiresOn,
    filters: criteria.toEntity(city: city, venues: venues),
  );
}

/// `SearchCriteriaInput`: the input shape (Jalali date, a weekday list, «HH:mm» times).
@JsonSerializable(createFactory: false, includeIfNull: false)
class SearchCriteriaInputModel {
  const SearchCriteriaInputModel({
    required this.sportId,
    this.cityId,
    this.venueIds,
    this.date,
    this.weekdays,
    this.from,
    this.to,
    this.minLevel,
    this.maxLevel,
    this.gender,
    this.format,
  });

  factory SearchCriteriaInputModel.fromFilters(SearchFilters filters) {
    final query = SearchQuery.of(filters);
    return SearchCriteriaInputModel(
      sportId: filters.sportId,
      cityId: filters.cityId,
      venueIds: query.venueIds,
      date: query.date,
      weekdays: query.weekdayList,
      from: query.from,
      to: query.to,
      minLevel: query.minLevel,
      maxLevel: query.maxLevel,
      gender: query.gender,
      format: query.format,
    );
  }

  final String sportId;
  final int? cityId;
  final List<String>? venueIds;
  final String? date;
  final List<String>? weekdays;
  final String? from;
  final String? to;
  final String? minLevel;
  final String? maxLevel;
  final String? gender;
  final String? format;

  Map<String, dynamic> toJson() => _$SearchCriteriaInputModelToJson(this);
}

/// `{name, alertsEnabled, criteria}`.
@JsonSerializable(createFactory: false, explicitToJson: true)
class SavedSearchRequestModel {
  const SavedSearchRequestModel({required this.name, required this.alertsEnabled, required this.criteria});

  final String name;
  final bool alertsEnabled;
  final SearchCriteriaInputModel criteria;

  Map<String, dynamic> toJson() => _$SavedSearchRequestModelToJson(this);
}

/// [SearchFilters] as the API spells them; members the server defaults are null (left out).
class SearchQuery {
  const SearchQuery._({
    this.venueIds,
    this.date,
    this.weekdayList,
    this.from,
    this.to,
    this.minLevel,
    this.maxLevel,
    this.gender,
    this.format,
  });

  factory SearchQuery.of(SearchFilters filters) {
    final date = filters.date;
    final weekdays = [
      for (final d in Weekday.values)
        if (filters.weekdays.contains(d)) d.wire,
    ];
    return SearchQuery._(
      venueIds: filters.venues.isEmpty ? null : [for (final v in filters.venues) v.id],
      date: date == null ? null : JalaliDateText.toApi(date),
      weekdayList: date != null || weekdays.isEmpty ? null : weekdays,
      from: filters.fromMinute == 0 ? null : TimeOfDayText.toApi(filters.fromMinute),
      to: filters.toMinute == SearchFilters.endOfDay ? null : TimeOfDayText.toApi(filters.toMinute),
      minLevel: filters.minLevel?.wire,
      maxLevel: filters.maxLevel?.wire,
      gender: filters.gender?.wire,
      format: filters.format?.wire,
    );
  }

  final List<String>? venueIds;
  final String? date;
  final List<String>? weekdayList;
  final String? from;
  final String? to;
  final String? minLevel;
  final String? maxLevel;
  final String? gender;
  final String? format;

  /// Comma-separated, as GET /search/partners takes them: «Saturday,Monday».
  String? get weekdays => weekdayList?.join(',');
}
