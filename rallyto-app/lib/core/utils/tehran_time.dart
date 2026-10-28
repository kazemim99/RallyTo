/// Tehran's offset from UTC. Iran abolished daylight saving in 2022, so it is fixed all year: UTC+03:30.
const Duration tehranOffset = Duration(hours: 3, minutes: 30);

/// An INSTANT (a match's start, a message's send time) as Tehran's wall clock: a zone-less `DateTime` carrying
/// Tehran's digits, so the formatters show it as it is on a phone set to any zone.
DateTime tehranWallClock(DateTime instant) {
  final t = instant.toUtc().add(tehranOffset);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond, t.microsecond);
}

/// The instant at which Tehran's clock reads [wallClock]'s digits — the inverse of [tehranWallClock]. Only the
/// digits of [wallClock] are used; its zone is ignored. The result is in UTC, ready to send to the API.
DateTime fromTehranWallClock(DateTime wallClock) => DateTime.utc(
  wallClock.year,
  wallClock.month,
  wallClock.day,
  wallClock.hour,
  wallClock.minute,
  wallClock.second,
  wallClock.millisecond,
  wallClock.microsecond,
).subtract(tehranOffset);

/// Tehran's wall clock now. [now] is the instant to read; it defaults to the current time.
DateTime tehranNow({DateTime? now}) => tehranWallClock(now ?? DateTime.now());

/// Tehran's calendar day for [instant], at midnight on the wall clock: the day a player in Iran calls «today» for it.
DateTime tehranDate(DateTime instant) {
  final t = tehranWallClock(instant);
  return DateTime(t.year, t.month, t.day);
}
