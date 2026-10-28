/// An instant the API wrote (ISO 8601), in UTC. A time without a zone is UTC too: the server stores UTC, and a value
/// read back from the database may lose its «Z». Null when [text] is not a date.
DateTime? parseServerInstant(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return null;
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(value);
  final hasTime = value.contains('T') || value.contains(' ');
  return DateTime.tryParse(hasTime && !hasZone ? '${value}Z' : value)?.toUtc();
}
