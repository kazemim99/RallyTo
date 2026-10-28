import '../../../core/constants/app_strings.dart';
import '../../catalog/domain/entities/sport.dart';
import 'entities/player_profile.dart';

/// The rules a sport profile must meet, mirrored from the server so the player hears about them before sending.
class SportRules {
  SportRules._();

  /// The formats [sport] may be played in: padel is doubles only and squash singles only; tennis and badminton
  /// allow both. The catalog's list is used, kept within those rules.
  static List<PlayFormat> allowedFormats(Sport sport) {
    final byRule = _byCode(sport.code);
    final inCatalog = {for (final f in sport.formats) f.format};
    final allowed = [
      for (final format in byRule)
        if (inCatalog.isEmpty || inCatalog.contains(format)) format,
    ];
    return allowed.isEmpty ? byRule : allowed;
  }

  static List<PlayFormat> _byCode(String code) => switch (code.toLowerCase()) {
    'padel' => const [PlayFormat.doubles],
    'squash' => const [PlayFormat.singles],
    _ => PlayFormat.values,
  };

  /// The first thing missing from [draft] for [sport], as the message to show; null when it is complete.
  static String? validate(SportProfileDraft draft, Sport sport) {
    if (draft.level == null) return AppStrings.sportLevelRequired(sport.nameFa);
    if (draft.experience == null) return AppStrings.sportExperienceRequired(sport.nameFa);
    if (draft.formats.isEmpty) return AppStrings.sportFormatRequired(sport.nameFa);
    final allowed = allowedFormats(sport);
    if (draft.formats.any((f) => !allowed.contains(f))) return AppStrings.sportFormatNotAllowed(sport.nameFa);
    if (draft.goals.isEmpty) return AppStrings.sportGoalRequired(sport.nameFa);
    return null;
  }

  /// A new draft for [sport]: a sport with a single allowed format starts with it chosen.
  static SportProfileDraft newDraft(Sport sport) {
    final allowed = allowedFormats(sport);
    return SportProfileDraft(sportId: sport.id, formats: allowed.length == 1 ? {allowed.single} : const {});
  }
}
