import 'package:equatable/equatable.dart';

/// How many play on each side. The server writes it as «Singles» or «Doubles».
enum PlayFormat {
  singles('Singles'),
  doubles('Doubles');

  const PlayFormat(this.wire);

  /// The server's spelling.
  final String wire;

  /// The format the server calls [value], or null for one this app does not know.
  static PlayFormat? tryParse(String? value) => _parse(values, value, (f) => f.wire);
}

/// The five skill tiers every sport shares, lowest first. Each sport describes them in its own words.
enum LevelTier {
  beginner('Beginner'),
  lowerIntermediate('LowerIntermediate'),
  intermediate('Intermediate'),
  advanced('Advanced'),
  professional('Professional');

  const LevelTier(this.wire);

  final String wire;

  static LevelTier? tryParse(String? value) => _parse(values, value, (t) => t.wire);
}

/// What a court is made of.
enum CourtSurface {
  hard('Hard'),
  clay('Clay'),
  grass('Grass'),
  artificialGrass('ArtificialGrass'),
  carpet('Carpet'),
  wood('Wood'),
  synthetic('Synthetic'),
  glass('Glass');

  const CourtSurface(this.wire);

  final String wire;

  static CourtSurface? tryParse(String? value) => _parse(values, value, (s) => s.wire);
}

T? _parse<T>(List<T> values, String? value, String Function(T) wire) {
  for (final item in values) {
    if (wire(item).toLowerCase() == value?.toLowerCase()) return item;
  }
  return null;
}

/// A racket sport the app supports: tennis, padel, badminton, squash.
class Sport extends Equatable {
  const Sport({
    required this.id,
    required this.code,
    required this.nameFa,
    required this.nameEn,
    required this.sortOrder,
    required this.isActive,
    required this.defaultSessionMinutes,
    this.formats = const [],
    this.levels = const [],
    this.surfaces = const [],
  });

  final String id;

  /// Stable lower-case key, e.g. `tennis`, `padel`: what the API takes as `sport=`.
  final String code;
  final String nameFa;
  final String nameEn;
  final int sortOrder;
  final bool isActive;
  final int defaultSessionMinutes;

  /// Padel is doubles only and squash singles only; tennis and badminton allow both.
  final List<SportFormat> formats;

  /// The five tiers, in [SportLevel.order].
  final List<SportLevel> levels;
  final List<CourtSurface> surfaces;

  @override
  List<Object?> get props => [
    id,
    code,
    nameFa,
    nameEn,
    sortOrder,
    isActive,
    defaultSessionMinutes,
    formats,
    levels,
    surfaces,
  ];
}

/// One way a sport is played, and how many players a game takes.
class SportFormat extends Equatable {
  const SportFormat({required this.format, required this.playersPerSide, required this.capacity});

  final PlayFormat format;
  final int playersPerSide;

  /// Players in a full game: 2 for singles, 4 for doubles.
  final int capacity;

  @override
  List<Object?> get props => [format, playersPerSide, capacity];
}

/// A skill tier as a sport describes it, with the server's Persian [name] and [description].
class SportLevel extends Equatable {
  const SportLevel({required this.tier, required this.order, required this.name, required this.description});

  final LevelTier tier;
  final int order;
  final String name;
  final String description;

  @override
  List<Object?> get props => [tier, order, name, description];
}
