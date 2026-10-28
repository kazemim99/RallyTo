import 'persian_digits.dart';

/// Normalisation of Persian text for client-side search. A player may type with an Arabic keyboard (ي, ك, ى) or
/// with a half-space where the data has a space, so both the text and the query are normalised before comparing.
class PersianText {
  PersianText._();

  static final RegExp _spaces = RegExp(r'\s+');

  /// [input] with Arabic yeh (ي, ى) as Persian yeh (ی), Arabic kaf (ك) as Persian kaf (ک), the zero-width
  /// non-joiner as a space, digits as Western digits, whitespace collapsed, trimmed and lower-cased.
  static String normalize(String input) {
    final text = input
        .replaceAll('\u064A', '\u06CC') // Arabic yeh to Persian yeh
        .replaceAll('\u0649', '\u06CC') // alef maksura to Persian yeh
        .replaceAll('\u0643', '\u06A9') // Arabic kaf to Persian kaf
        .replaceAll('\u200C', ' '); // zero-width non-joiner to a space
    return PersianDigits.normalize(text).replaceAll(_spaces, ' ').trim().toLowerCase();
  }

  /// Whether [text] contains [query], both normalised. An empty query matches everything.
  static bool matches(String text, String query) {
    final q = normalize(query);
    return q.isEmpty || normalize(text).contains(q);
  }
}
