import '../../../core/constants/app_strings.dart';
import '../../../core/utils/persian_digits.dart';
import '../domain/entities/sport.dart';
import '../domain/entities/venue.dart';

/// Persian labels for catalog values.
class CatalogLabels {
  CatalogLabels._();

  static String setting(CourtSetting setting) => switch (setting) {
    CourtSetting.indoor => AppStrings.courtIndoor,
    CourtSetting.outdoor => AppStrings.courtOutdoor,
    CourtSetting.both => AppStrings.courtIndoorOutdoor,
  };

  static String surface(CourtSurface surface) => switch (surface) {
    CourtSurface.hard => AppStrings.surfaceHard,
    CourtSurface.clay => AppStrings.surfaceClay,
    CourtSurface.grass => AppStrings.surfaceGrass,
    CourtSurface.artificialGrass => AppStrings.surfaceArtificialGrass,
    CourtSurface.carpet => AppStrings.surfaceCarpet,
    CourtSurface.wood => AppStrings.surfaceWood,
    CourtSurface.synthetic => AppStrings.surfaceSynthetic,
    CourtSurface.glass => AppStrings.surfaceGlass,
  };

  /// The sport's Persian name from [sportNames], or its code when the names are not loaded.
  static String sportName(String code, Map<String, String> sportNames) => sportNames[code] ?? code;

  /// A short tag: «تنیس ۶ زمین», or just «تنیس» when the court count is unknown.
  static String sportTag(VenueSport sport, Map<String, String> sportNames) {
    final name = sportName(sport.sportCode, sportNames);
    final count = sport.courtCount;
    return count == null ? name : AppStrings.sportCourts(name, PersianDigits.fromInt(count));
  }
}
