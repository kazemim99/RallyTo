import 'dart:math';

/// The server's chat error codes (`error.code`).
class ChatErrorCodes {
  ChatErrorCodes._();

  static const String requestNotAccepted = 'REQUEST_NOT_ACCEPTED';
  static const String cannotReply = 'CANNOT_REPLY';
  static const String messageTooLong = 'MESSAGE_TOO_LONG';
  static const String messageEmpty = 'MESSAGE_EMPTY';
  static const String playerNotFound = 'PLAYER_NOT_FOUND';
  static const String conversationNotFound = 'CONVERSATION_NOT_FOUND';
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  static const String cannotMessageSelf = 'CANNOT_MESSAGE_SELF';
  static const String profileRequired = 'PROFILE_REQUIRED';

  /// Not the server's: a first request message over 500 characters, checked on the device.
  static const String requestMessageTooLong = 'REQUEST_MESSAGE_TOO_LONG';
}

/// The chat rules the app checks before asking the server (spec chat › Sending messages, Message requests).
class ChatRules {
  ChatRules._();

  /// Characters in a message, after trimming.
  static const int maxLength = 1000;

  /// Characters in the one message a request's sender may send.
  static const int requestMaxLength = 500;

  /// Messages in a history page.
  static const int pageSize = 50;

  /// The code for what is wrong with [body], or null when it can be sent. [asRequest]: the sender's first message of
  /// a request, limited to [requestMaxLength].
  static String? checkBody(String body, {bool asRequest = false}) {
    final text = body.trim();
    if (text.isEmpty) return ChatErrorCodes.messageEmpty;
    if (asRequest && text.length > requestMaxLength) return ChatErrorCodes.requestMessageTooLong;
    if (text.length > maxLength) return ChatErrorCodes.messageTooLong;
    return null;
  }

  static final Random _random = Random.secure();

  /// A new client message id: 32 random hex digits (the server takes up to 64 characters).
  static String newClientMessageId() =>
      List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
