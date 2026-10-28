import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';
import 'package:rallyto_app/features/search/domain/search_rules.dart';

import '../../../helpers/fake_catalog.dart';
import '../../../helpers/fake_profile.dart';

/// The search defaults and rules (spec partner-search › Search input and defaults).
void main() {
  test('the level range is the tier ± 1, clamped; every tier without a level', () {
    expect(SearchRules.levelRange(LevelTier.intermediate), (LevelTier.lowerIntermediate, LevelTier.advanced));
    expect(SearchRules.levelRange(LevelTier.beginner), (LevelTier.beginner, LevelTier.lowerIntermediate));
    expect(SearchRules.levelRange(LevelTier.professional), (LevelTier.advanced, LevelTier.professional));
    expect(SearchRules.levelRange(null), (LevelTier.beginner, LevelTier.professional));
  });

  test('defaults: profile city with all its clubs, any day, the whole day, tier ± 1, any gender and format', () {
    final filters = SearchRules.defaults(testMyProfile(), tennis());

    expect(filters.sportId, 's-tennis');
    expect(filters.cityId, 10);
    expect(filters.cityName, 'تهران');
    expect(filters.venues, isEmpty);
    expect(filters.date, isNull);
    expect(filters.weekdays, isEmpty);
    expect(filters.isWholeDay, isTrue);
    expect(filters.minLevel, LevelTier.lowerIntermediate);
    expect(filters.maxLevel, LevelTier.advanced);
    expect(filters.gender, isNull);
    expect(filters.format, isNull);
  });

  test('a same-gender-only player searches their own gender, whatever is asked', () {
    final restricted = testMyProfile(visibility: ProfileVisibility.sameGender);

    expect(SearchRules.defaults(restricted, tennis()).gender, Gender.female);
    expect(SearchRules.lockedGender(restricted), Gender.female);
    expect(SearchRules.lockedGender(testMyProfile()), isNull);
    const anyone = SearchFilters(sportId: 's-tennis');
    expect(SearchRules.enforce(anyone, restricted).gender, Gender.female);
    expect(SearchRules.enforce(anyone, testMyProfile()).gender, isNull);
  });

  test('the end after the start; a date today to 30 days ahead; a name of 1 to 40 characters', () {
    final today = Jalali(1405, 8, 1);
    expect(SearchRules.checkTime(18 * 60, 22 * 60), isNull);
    expect(SearchRules.checkTime(22 * 60, 22 * 60), SearchErrorCodes.invalidTimeRange);
    expect(SearchRules.checkDate(today, today), isNull);
    expect(SearchRules.checkDate(today.addDays(30), today), isNull);
    expect(SearchRules.checkDate(today.addDays(31), today), SearchErrorCodes.dateOutOfRange);
    expect(SearchRules.checkDate(today.addDays(-1), today), SearchErrorCodes.dateOutOfRange);
    expect(SearchRules.checkName('شنبه‌ها'), isNull);
    expect(SearchRules.checkName('  '), SearchErrorCodes.invalidSavedSearchName);
    expect(SearchRules.checkName('x' * 41), SearchErrorCodes.invalidSavedSearchName);
  });
}
