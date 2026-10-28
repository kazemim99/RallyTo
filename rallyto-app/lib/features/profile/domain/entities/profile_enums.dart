// The profile's enums, each with the server's spelling ([wire]). A value this app does not know parses to null and
// is dropped instead of failing the whole response.

/// Set once at onboarding; only an admin can correct it later (`GENDER_LOCKED` otherwise).
enum Gender {
  male('Male'),
  female('Female');

  const Gender(this.wire);

  final String wire;

  static Gender? tryParse(String? value) => parseWire(values, value, (g) => g.wire);
}

/// Who may see the player in search and on their profile page.
enum ProfileVisibility {
  everyone('Everyone'),
  sameGender('SameGender');

  const ProfileVisibility(this.wire);

  final String wire;

  static ProfileVisibility? tryParse(String? value) => parseWire(values, value, (v) => v.wire);
}

/// How long the player has played a sport.
enum ExperienceBand {
  underSixMonths('UnderSixMonths'),
  sixToTwelveMonths('SixToTwelveMonths'),
  oneToThreeYears('OneToThreeYears'),
  threeToFiveYears('ThreeToFiveYears'),
  overFiveYears('OverFiveYears');

  const ExperienceBand(this.wire);

  final String wire;

  static ExperienceBand? tryParse(String? value) => parseWire(values, value, (e) => e.wire);
}

/// What the player wants from a game.
enum PlayGoal {
  rallyPractice('RallyPractice'),
  friendlyMatch('FriendlyMatch'),
  competitive('Competitive'),
  fitness('Fitness');

  const PlayGoal(this.wire);

  final String wire;

  static PlayGoal? tryParse(String? value) => parseWire(values, value, (g) => g.wire);
}

/// Another player's last activity, only as coarse as this: never a time.
enum LastActive {
  today('Today'),
  thisWeek('ThisWeek'),
  thisMonth('ThisMonth'),
  earlier('Earlier');

  const LastActive(this.wire);

  final String wire;

  static LastActive? tryParse(String? value) => parseWire(values, value, (l) => l.wire);
}

/// The item of [values] the server spells [value] (case aside), or null.
T? parseWire<T>(List<T> values, String? value, String Function(T) wire) {
  for (final item in values) {
    if (wire(item).toLowerCase() == value?.toLowerCase()) return item;
  }
  return null;
}
