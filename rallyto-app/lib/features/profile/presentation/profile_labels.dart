import '../../../core/constants/app_strings.dart';
import '../../../core/utils/display_join.dart';
import '../../../core/utils/persian_digits.dart';
import '../../catalog/domain/entities/sport.dart';
import '../domain/entities/profile_enums.dart';

/// Persian labels for profile values.
class ProfileLabels {
  ProfileLabels._();

  static String gender(Gender gender) => switch (gender) {
    Gender.male => AppStrings.genderMale,
    Gender.female => AppStrings.genderFemale,
  };

  static String experience(ExperienceBand band) => switch (band) {
    ExperienceBand.underSixMonths => AppStrings.experienceUnderSixMonths,
    ExperienceBand.sixToTwelveMonths => AppStrings.experienceSixToTwelveMonths,
    ExperienceBand.oneToThreeYears => AppStrings.experienceOneToThreeYears,
    ExperienceBand.threeToFiveYears => AppStrings.experienceThreeToFiveYears,
    ExperienceBand.overFiveYears => AppStrings.experienceOverFiveYears,
  };

  static String format(PlayFormat format) => switch (format) {
    PlayFormat.singles => AppStrings.formatSingles,
    PlayFormat.doubles => AppStrings.formatDoubles,
  };

  static String goal(PlayGoal goal) => switch (goal) {
    PlayGoal.rallyPractice => AppStrings.goalRallyPractice,
    PlayGoal.friendlyMatch => AppStrings.goalFriendlyMatch,
    PlayGoal.competitive => AppStrings.goalCompetitive,
    PlayGoal.fitness => AppStrings.goalFitness,
  };

  static String lastActive(LastActive lastActive) => switch (lastActive) {
    LastActive.today => AppStrings.lastActiveToday,
    LastActive.thisWeek => AppStrings.lastActiveThisWeek,
    LastActive.thisMonth => AppStrings.lastActiveThisMonth,
    LastActive.earlier => AppStrings.lastActiveEarlier,
  };

  /// «25-34» → «۲۵ تا ۳۴ سال»; «55+» → «۵۵ سال به بالا». Anything else as it came, in Persian digits.
  static String ageRange(String range) {
    final span = RegExp(r'^(\d+)-(\d+)$').firstMatch(range.trim());
    if (span != null) {
      return AppStrings.ageRange(PersianDigits.toPersian(span.group(1)!), PersianDigits.toPersian(span.group(2)!));
    }
    final open = RegExp(r'^(\d+)\+$').firstMatch(range.trim());
    if (open != null) return AppStrings.ageRangeFrom(PersianDigits.toPersian(open.group(1)!));
    return PersianDigits.toPersian(range);
  }

  /// The sport's Persian name from [sportNames], or its code when the names are not loaded.
  static String sportName(String code, Map<String, String> sportNames) => sportNames[code] ?? code;

  /// One line about a sport profile: «سابقه ۱ تا ۳ سال • انفرادی، دونفره».
  static String sportSummary({ExperienceBand? experience, List<PlayFormat> formats = const []}) => [
    if (experience != null) ProfileLabels.experience(experience),
    if (formats.isNotEmpty) formats.map(format).join('، '),
  ].joinDisplay();
}
