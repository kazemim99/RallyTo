import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../catalog/domain/entities/sport.dart';
import '../../profile/domain/entities/player_profile.dart';
import '../../profile/domain/entities/profile_enums.dart';
import 'entities/search.dart';

/// The server's `error.code`s for partner search and saved searches.
class SearchErrorCodes {
  SearchErrorCodes._();

  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  static const String dateOutOfRange = 'DATE_OUT_OF_RANGE';
  static const String invalidTimeRange = 'INVALID_TIME_RANGE';
  static const String invalidDate = 'INVALID_DATE';
  static const String invalidTime = 'INVALID_TIME';
  static const String unknownSport = 'UNKNOWN_SPORT';
  static const String tooManySavedSearches = 'TOO_MANY_SAVED_SEARCHES';
  static const String invalidSavedSearchName = 'INVALID_SAVED_SEARCH_NAME';
  static const String profileRequired = 'PROFILE_REQUIRED';
}

/// The search defaults and rules, mirrored from the server (spec partner-search).
class SearchRules {
  SearchRules._();

  /// A date search is today to this many days ahead.
  static const int maxDaysAhead = 30;
  static const int maxSavedSearches = 5;
  static const int maxNameLength = 40;

  /// Clubs the filter sheet lets the player pick (none means every club in the city).
  static const int maxVenues = 5;
  static const int step = 30;

  /// 00:00 to 23:30.
  static List<int> get fromOptions => [for (var m = 0; m < SearchFilters.endOfDay; m += step) m];

  /// 00:30 to 24:00.
  static List<int> get toOptions => [for (var m = step; m <= SearchFilters.endOfDay; m += step) m];

  /// The player's tier ± 1, or every tier when they have no level for the sport.
  static (LevelTier, LevelTier) levelRange(LevelTier? own) {
    if (own == null) return (LevelTier.beginner, LevelTier.professional);
    final tiers = LevelTier.values;
    final low = own.index - 1 < 0 ? 0 : own.index - 1;
    final high = own.index + 1 >= tiers.length ? tiers.length - 1 : own.index + 1;
    return (tiers[low], tiers[high]);
  }

  /// A same-gender-only player always searches their own gender; anyone else chooses.
  static Gender? lockedGender(MyProfile profile) =>
      profile.visibility == ProfileVisibility.sameGender ? profile.gender : null;

  /// The player's level in [sportId], or null.
  static LevelTier? levelIn(MyProfile profile, String sportId) {
    for (final sport in profile.sports) {
      if (sport.sportId == sportId) return sport.level;
    }
    return null;
  }

  /// The defaults for [sport]: the profile city with all its clubs, any day, the whole day, the player's tier ± 1,
  /// any gender (their own when same-gender only), any format.
  static SearchFilters defaults(MyProfile profile, Sport sport) {
    final (min, max) = levelRange(levelIn(profile, sport.id));
    return SearchFilters(
      sportId: sport.id,
      cityId: profile.city.id,
      cityName: profile.city.name,
      minLevel: min,
      maxLevel: max,
      gender: lockedGender(profile),
    );
  }

  /// [filters] with the profile's constraint applied: a same-gender-only player's gender cannot be changed.
  static SearchFilters enforce(SearchFilters filters, MyProfile profile) {
    final locked = lockedGender(profile);
    return locked == null || filters.gender == locked ? filters : filters.copyWith(gender: () => locked);
  }

  /// The end after the start: `INVALID_TIME_RANGE` otherwise.
  static String? checkTime(int fromMinute, int toMinute) =>
      toMinute <= fromMinute ? SearchErrorCodes.invalidTimeRange : null;

  /// A date from [today] to 30 days on: `DATE_OUT_OF_RANGE` otherwise.
  static String? checkDate(Jalali date, Jalali today) =>
      date.compareTo(today) < 0 || date.compareTo(today.addDays(maxDaysAhead)) > 0
      ? SearchErrorCodes.dateOutOfRange
      : null;

  /// A saved search's name is 1 to 40 characters.
  static String? checkName(String name) {
    final length = name.trim().length;
    return length < 1 || length > maxNameLength ? SearchErrorCodes.invalidSavedSearchName : null;
  }
}
