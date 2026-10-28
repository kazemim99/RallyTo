import '../../../config/routes/app_router.dart';

/// Where a notification's deep link goes in the app. The server writes `/matches/{id}`, `/chat/{conversationId}`,
/// `/saved-searches/{id}`, `/availability` and `/profile`, on the inbox entry and in the push's data.
class DeepLinks {
  DeepLinks._();

  /// The app location for [deepLink], or null when it names nothing the app knows.
  static String? locationFor(String? deepLink) {
    final path = Uri.tryParse(deepLink?.trim() ?? '')?.path ?? '';
    final segments = [
      for (final s in path.split('/'))
        if (s.isNotEmpty) s,
    ];
    switch (segments) {
      case ['matches', final id]:
        return Routes.matchPath(id);
      case ['chat', final id]:
        return Routes.chatPath(id);
      // There is no screen for one saved search: its list, where it can be run.
      case ['saved-searches', _]:
      case ['saved-searches']:
        return Routes.savedSearches;
      case ['availability']:
        return Routes.availability;
      case ['profile']:
        return Routes.profile;
    }
    return null;
  }

  /// Where tapping a push with [deepLink] goes: [locationFor], else the notification inbox.
  static String targetFor(String? deepLink) => locationFor(deepLink) ?? Routes.notifications;
}
