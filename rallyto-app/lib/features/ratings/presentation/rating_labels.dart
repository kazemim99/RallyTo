import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/persian_digits.dart';
import '../domain/entities/rating.dart';
import '../domain/rating_rules.dart';

/// Persian labels for ratings and reputation, and the messages for the server's rating error codes.
class RatingLabels {
  RatingLabels._();

  static String tag(RatingTag tag) => switch (tag) {
    RatingTag.onTime => AppStrings.tagOnTime,
    RatingTag.friendly => AppStrings.tagFriendly,
    RatingTag.fairCalls => AppStrings.tagFairCalls,
    RatingTag.goodRally => AppStrings.tagGoodRally,
    RatingTag.sportsmanship => AppStrings.tagSportsmanship,
    RatingTag.wellOrganised => AppStrings.tagWellOrganised,
  };

  /// The rating form's choice.
  static String levelAccuracy(LevelAccuracy accuracy) => switch (accuracy) {
    LevelAccuracy.lower => AppStrings.levelLower,
    LevelAccuracy.aboutRight => AppStrings.levelAboutRight,
    LevelAccuracy.higher => AppStrings.levelHigher,
  };

  /// «بیشتر هم‌بازی‌ها می‌گویند سطح اعلام‌شده درست است».
  static String levelStatement(LevelAccuracy accuracy) => switch (accuracy) {
    LevelAccuracy.lower => AppStrings.levelStatementLower,
    LevelAccuracy.aboutRight => AppStrings.levelStatementAboutRight,
    LevelAccuracy.higher => AppStrings.levelStatementHigher,
  };

  /// The badge: «تازه‌وارد», or «خوش‌قولی: خوب». Never a number.
  static String reliability(ReliabilityTier tier) => switch (tier) {
    ReliabilityTier.newPlayer => AppStrings.reliabilityNew,
    ReliabilityTier.low => AppStrings.reliability(AppStrings.reliabilityLow),
    ReliabilityTier.good => AppStrings.reliability(AppStrings.reliabilityGood),
    ReliabilityTier.high => AppStrings.reliability(AppStrings.reliabilityHigh),
  };

  /// «۴٫۳ ستاره از ۳ امتیاز», or «بازیکن جدید» below 3 revealed ratings.
  static String stars(SportReputation reputation) {
    final average = reputation.starAverage;
    if (reputation.isNew || average == null) return AppStrings.reputationNewPlayer;
    return AppStrings.starAverage(decimal(average), PersianDigits.fromInt(reputation.ratingCount));
  }

  /// [value] to one decimal, in Persian digits with the Persian decimal separator: «۴٫۳».
  static String decimal(double value) => PersianDigits.toPersian(value.toStringAsFixed(1)).replaceAll('.', '٫');

  /// The player-facing message for a refused rating: the app's words for a known code, else the server's.
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  /// The message for a rule checked on the device, by the server's code.
  static String rule(String code) => _messages[code] ?? AppStrings.genericError;

  static const Map<String, String> _messages = {
    RatingErrorCodes.ratingNotAllowed: AppStrings.ratingNotAllowed,
    RatingErrorCodes.ratingWindowClosed: AppStrings.ratingWindowClosed,
    RatingErrorCodes.alreadyRated: AppStrings.alreadyRated,
    RatingErrorCodes.cannotRateSelf: AppStrings.cannotRateSelf,
    RatingErrorCodes.invalidStars: AppStrings.invalidStars,
    RatingErrorCodes.tooManyTags: AppStrings.tooManyTags,
    RatingErrorCodes.levelAccuracyRequired: AppStrings.levelAccuracyRequired,
    RatingErrorCodes.noteTooLong: AppStrings.ratingNoteTooLong,
    RatingErrorCodes.matchNotFound: AppStrings.matchNotAvailable,
  };
}
