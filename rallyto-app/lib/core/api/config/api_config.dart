/// Where the API is and how long to wait for it.
class ApiConfig {
  ApiConfig._();

  /// The Android emulator's alias for the host machine's localhost, where the API runs during development.
  static const String defaultBaseUrl = 'http://10.0.2.2:5100';

  /// Build-time override: `flutter run --dart-define=API_BASE_URL=https://api.example.ir`. Empty when not given.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// The API's origin, without a trailing slash. Paths in [ApiPaths] start with `/api/v1`.
  static String get baseUrl => resolveBaseUrl(_baseUrlOverride);

  /// [override] when it is set, otherwise [defaultBaseUrl]; trailing slashes are dropped.
  static String resolveBaseUrl(String override) {
    final url = override.trim().isEmpty ? defaultBaseUrl : override.trim();
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Persian, so the server's messages come back in the player's language.
  static const String acceptLanguage = 'fa-IR';
}

/// API endpoint paths (`api/v{version}/…`).
class ApiPaths {
  ApiPaths._();

  static const String version = 'v1';

  /// `POST {phoneNumber}` → `{expiresInSeconds, resendAfterSeconds}`.
  static const String otpSend = '/api/$version/auth/otp/send';

  /// `POST {phoneNumber, code}` → a token pair.
  static const String otpVerify = '/api/$version/auth/otp/verify';

  /// `POST {refreshToken}` → a new token pair. Refresh tokens are single-use: each refresh rotates it.
  static const String refresh = '/api/$version/auth/refresh';

  /// `POST {refreshToken}` → 204. Revokes the refresh token on the server; signing out locally does not wait on it.
  static const String signOut = '/api/$version/auth/sign-out';

  /// `POST` → `{expiresInSeconds, resendAfterSeconds}`: an SMS code confirming the player's own account deletion.
  /// Rate-limited like sign-in codes (`OTP_RESEND_TOO_SOON`, `OTP_SEND_LIMIT`, `TOO_MANY_REQUESTS`, with Retry-After).
  static const String accountDeletionCode = '/api/$version/account/deletion/code';

  /// `POST {code}` → 204: deletes the player's own account. `CODE_INVALID` / `CODE_EXPIRED` (400) for a wrong code.
  static const String accountDeletion = '/api/$version/account/deletion';

  /// `GET` → every sport with its formats, level tiers and surfaces. Anonymous.
  static const String sports = '/api/$version/sports';

  /// `GET` → `[{id, name}]`.
  static const String provinces = '/api/$version/provinces';

  /// `GET` → a province's cities, those with clubs first.
  static const String provinceCities = '/api/$version/provinces/{id}/cities';

  /// `GET ?cityId=&sport=&q=` → the city's visible venues. The server normalises Persian text in `q`.
  static const String venues = '/api/$version/venues';

  /// `GET` → one venue; 404 when it is hidden.
  static const String venue = '/api/$version/venues/{id}';

  // Profile. Until the player has a profile, every endpoint below except `POST /profile` is 403 PROFILE_REQUIRED.

  /// `POST` → 201 the new profile.
  static const String profile = '/api/$version/profile';

  /// `GET` → the player's own profile.
  static const String profileMe = '/api/$version/profile/me';

  /// `PUT` (add or replace) / `DELETE` (409 LAST_SPORT_PROFILE for the last one) one sport profile.
  static const String profileSport = '/api/$version/profile/sports/{sportId}';

  /// `PUT {venueIds}` (at most 5).
  static const String profileHomeVenues = '/api/$version/profile/home-venues';

  /// `PUT {visibility}`.
  static const String profileVisibility = '/api/$version/profile/visibility';

  /// `PUT` multipart `file` (jpeg/png/webp, ≤5 MB) / `DELETE`.
  static const String profilePhoto = '/api/$version/profile/photo';

  /// `GET` → another player's profile; 404 PLAYER_NOT_FOUND when blocked, hidden or missing alike.
  static const String player = '/api/$version/players/{userId}';

  /// `GET` → another player's active availability windows.
  static const String playerAvailability = '/api/$version/players/{userId}/availability';

  /// `GET` → the players this player blocked.
  static const String blocks = '/api/$version/blocks';

  /// `POST` (block) / `DELETE` (unblock) → 204.
  static const String block = '/api/$version/blocks/{userId}';

  // Availability

  /// `GET` → the player's own windows / `POST` → 201 a new one.
  static const String availability = '/api/$version/availability';

  /// `PUT` (edit) / `DELETE` (204).
  static const String availabilityWindow = '/api/$version/availability/{id}';

  /// `POST` → the window, paused.
  static const String availabilityPause = '/api/$version/availability/{id}/pause';

  /// `POST` → the window, active again.
  static const String availabilityResume = '/api/$version/availability/{id}/resume';

  /// `POST` → "still available": resets the 30-day clock after which a recurring window pauses itself.
  static const String availabilityConfirm = '/api/$version/availability/{id}/confirm';

  // Partner search

  /// `GET ?sportId=&cityId=&venueIds=…&date=|weekdays=Saturday,Monday&from=&to=&minLevel=&maxLevel=&gender=&format=
  /// &cursor=` → `{players, posts, nextCursor}`. Posts come with the first page only. 60 per minute (429 beyond).
  static const String searchPartners = '/api/$version/search/partners';

  /// `GET` → the player's saved searches / `POST {name, alertsEnabled, criteria}` → 201 (at most 5).
  static const String savedSearches = '/api/$version/saved-searches';

  /// `PUT {name, alertsEnabled, criteria}` / `DELETE` (204).
  static const String savedSearch = '/api/$version/saved-searches/{id}';

  // Matches: play posts, invitations and the games the player is in. Every action answers with the whole game.

  /// `POST MatchInput` → 201 a public play post.
  static const String matchPosts = '/api/$version/matches/posts';

  /// `POST InvitationInput` → 201 a private game with invitees.
  static const String matchInvitations = '/api/$version/matches/invitations';

  /// `GET ?scope=upcoming|past`.
  static const String myMatches = '/api/$version/matches/mine';

  /// `GET` → one game; 404 MATCH_NOT_FOUND for one the player may not see.
  static const String match = '/api/$version/matches/{id}';

  /// `GET` → the game behind a share token; 404 MATCH_NOT_AVAILABLE.
  static const String matchByToken = '/api/$version/matches/by-token/{token}';

  /// `POST {reason}` (host).
  static const String matchCancel = '/api/$version/matches/{id}/cancel';

  /// `POST {message}`: a join request.
  static const String matchJoin = '/api/$version/matches/{id}/join';

  /// `POST`: withdraws a pending join request.
  static const String matchWithdraw = '/api/$version/matches/{id}/withdraw';

  /// `POST` (host).
  static const String matchAcceptRequest = '/api/$version/matches/{id}/requests/{playerId}/accept';
  static const String matchDeclineRequest = '/api/$version/matches/{id}/requests/{playerId}/decline';

  /// `POST {playerIds}` (host).
  static const String matchInvite = '/api/$version/matches/{id}/invite';

  /// `POST` (invitee).
  static const String matchAcceptInvitation = '/api/$version/matches/{id}/invitation/accept';
  static const String matchDeclineInvitation = '/api/$version/matches/{id}/invitation/decline';

  /// `POST` (host): confirms with at least 2 players.
  static const String matchConfirm = '/api/$version/matches/{id}/confirm';

  /// `POST` (accepted player).
  static const String matchLeave = '/api/$version/matches/{id}/leave';

  /// `POST` (host).
  static const String matchRemoveParticipant = '/api/$version/matches/{id}/participants/{playerId}/remove';

  /// `POST` (host): a new share token, which invalidates the old link.
  static const String matchShareToken = '/api/$version/matches/{id}/share-token';

  /// `POST {answer: Played|DidNotHappen, noShowPlayerIds}` (a player of the ended game) → the match.
  static const String matchAttendance = '/api/$version/matches/{id}/attendance';

  /// `POST {rateeId, stars, tags, levelAccuracy, privateNote}` → 201 `{id}`: a hidden, final rating.
  static const String matchRatings = '/api/$version/matches/{id}/ratings';

  // Safety

  /// `POST {targetType, targetId, reason, details, block}` → 201 `{id, status}` (20 an hour).
  static const String reports = '/api/$version/reports';

  /// `GET` → `[{id, targetType, reason, status: Open|Resolved, createdAt}]`, never the action taken.
  static const String myReports = '/api/$version/reports/mine';

  // Chat. Live updates come over the realtime hub; these are the reads and every write.

  /// `GET ?box=inbox|requests` → conversation summaries, newest first.
  static const String conversations = '/api/$version/conversations';

  /// `GET` → `{conversations, requests}`: how many of each have unread messages.
  static const String conversationsUnread = '/api/$version/conversations/unread';

  /// `POST {playerId}` → the pair's one direct conversation, existing or new (20 new per day).
  static const String conversationDirect = '/api/$version/conversations/direct';

  /// `GET` → one summary; 404 CONVERSATION_NOT_FOUND for a non-member.
  static const String conversation = '/api/$version/conversations/{id}';

  /// `GET` → the game's group conversation summary; 404 CONVERSATION_NOT_FOUND when there is none or this player is
  /// not in it.
  static const String matchConversation = '/api/$version/conversations/match/{matchId}';

  /// `GET ?before=` → `{items, nextCursor}`, newest first, 50 a page / `POST {clientMessageId, body}` → the message,
  /// idempotent on the client id (30 a minute).
  static const String conversationMessages = '/api/$version/conversations/{id}/messages';

  /// `DELETE` → 204: the sender deletes their own message for everyone.
  static const String conversationMessage = '/api/$version/conversations/{id}/messages/{messageId}';

  /// `POST` (request recipient) → the summary.
  static const String conversationAccept = '/api/$version/conversations/{id}/accept';
  static const String conversationIgnore = '/api/$version/conversations/{id}/ignore';

  /// `POST {upToMessageId}` → 204.
  static const String conversationRead = '/api/$version/conversations/{id}/read';

  /// `POST {muted}` → the summary.
  static const String conversationMute = '/api/$version/conversations/{id}/mute';

  // Notifications

  /// `GET ?page=&pageSize=` → `{items, page, pageSize, totalCount}`, newest first.
  static const String notifications = '/api/$version/notifications';

  /// `GET` → `{count}`.
  static const String notificationsUnreadCount = '/api/$version/notifications/unread-count';

  /// `POST` → 204; 404 NOTIFICATION_NOT_FOUND.
  static const String notificationRead = '/api/$version/notifications/{id}/read';

  /// `POST` → 204.
  static const String notificationsReadAll = '/api/$version/notifications/read-all';

  /// `GET` / `PUT {pushMatches, pushChat, pushRatings, pushSavedSearches, quietHoursEnabled, quietStart, quietEnd}`.
  static const String notificationPreferences = '/api/$version/notifications/preferences';

  /// `POST {token, platform}` (after sign-in and on rotation) / `DELETE {token}` (before sign-out) → 204.
  static const String deviceTokens = '/api/$version/device-tokens';
}
