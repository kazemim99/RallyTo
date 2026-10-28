import 'entities/rating.dart';

/// The server's `error.code`s for ratings.
class RatingErrorCodes {
  RatingErrorCodes._();

  static const String ratingNotAllowed = 'RATING_NOT_ALLOWED';
  static const String ratingWindowClosed = 'RATING_WINDOW_CLOSED';
  static const String alreadyRated = 'ALREADY_RATED';
  static const String cannotRateSelf = 'CANNOT_RATE_SELF';
  static const String invalidStars = 'INVALID_STARS';
  static const String tooManyTags = 'TOO_MANY_TAGS';
  static const String levelAccuracyRequired = 'LEVEL_ACCURACY_REQUIRED';
  static const String noteTooLong = 'NOTE_TOO_LONG';
  static const String matchNotFound = 'MATCH_NOT_FOUND';
}

/// The rating rules the app checks before sending (spec player-ratings › Rating content).
class RatingRules {
  RatingRules._();

  static const int minStars = 1;
  static const int maxStars = 5;
  static const int maxTags = 3;
  static const int maxNoteLength = 500;

  /// The server's code for what is wrong with [draft], or null when it can be sent.
  static String? check(RatingDraft draft) {
    if (draft.stars < minStars || draft.stars > maxStars) return RatingErrorCodes.invalidStars;
    if (draft.tags.toSet().length > maxTags) return RatingErrorCodes.tooManyTags;
    if (draft.levelAccuracy == null) return RatingErrorCodes.levelAccuracyRequired;
    if ((draft.privateNote?.trim().length ?? 0) > maxNoteLength) return RatingErrorCodes.noteTooLong;
    return null;
  }
}
