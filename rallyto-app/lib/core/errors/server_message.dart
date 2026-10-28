/// The words an error response carries for the player, whichever shape it came in — null when it carries none:
///
/// * the API's envelope: `{ success: false, message, error: { code, message, errors: { field: [..] } } }`;
/// * a bare `{ message }` or `{ errors: { field: [..] } }`;
/// * a list of errors: `{ errors: [ { code, message } ] }` or `{ errors: [ "…" ] }`.
///
/// A validation failure's headline is the server's English wrapper («Validation failed …»); the player's words are in
/// the per-field list, so that is read instead.
String? serverMessage(Object? data) {
  if (data is! Map) return null;

  final errors = data['errors'];
  if (errors is List && errors.isNotEmpty) {
    final first = errors.first;
    final text = first is Map ? _text(first['message']) : _text(first);
    if (text != null) return text;
  }

  final error = data['error'] is Map ? data['error'] as Map : null;
  final message = _text(data['message']) ?? _text(error?['message']);
  if (message == null || message.startsWith('Validation failed')) {
    final fields = errors is Map ? errors : error?['errors'];
    if (fields is Map) {
      for (final value in fields.values) {
        final text = value is List && value.isNotEmpty ? _text(value.first) : _text(value);
        if (text != null) return text;
      }
    }
  }
  return message;
}

/// The envelope's machine-readable `error.code`, or null.
String? serverErrorCode(Object? data) {
  if (data is! Map) return null;
  final error = data['error'];
  return error is Map ? _text(error['code']) : null;
}

/// The envelope's per-field messages (`error.errors`, or a top-level `errors` map), keyed by field name.
Map<String, List<String>> serverFieldErrors(Object? data) {
  if (data is! Map) return const {};
  final error = data['error'];
  final fields = error is Map && error['errors'] is Map ? error['errors'] : data['errors'];
  if (fields is! Map) return const {};
  return {for (final entry in fields.entries) '${entry.key}': _texts(entry.value)};
}

List<String> _texts(Object? value) {
  final items = value is List ? value : [value];
  return [for (final item in items) ?_text(item)];
}

String? _text(Object? value) => value is String && value.trim().isNotEmpty ? value.trim() : null;
