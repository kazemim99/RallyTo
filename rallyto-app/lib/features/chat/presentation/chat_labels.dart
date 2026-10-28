import '../../../core/constants/app_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/jalali_formatter.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/utils/tehran_time.dart';
import '../domain/chat_rules.dart';

/// Persian labels for chat, and the messages for the server's chat error codes.
class ChatLabels {
  ChatLabels._();

  /// A message's time on Tehran's clock: «۱۴:۳۰».
  static String time(DateTime instant) => JalaliFormatter.formatTime(tehranWallClock(instant));

  /// When a conversation last moved: the time today, else the day («۱ آبان»), both on Tehran's calendar.
  static String when(DateTime instant, {required DateTime now}) {
    final day = tehranDate(instant);
    return day == tehranDate(now) ? time(instant) : JalaliFormatter.formatShortDate(tehranWallClock(instant));
  }

  /// The day separator above a day's first message, on Tehran's calendar: «شنبه، ۲ آبان».
  static String day(DateTime instant) {
    final wall = tehranWallClock(instant);
    return '${JalaliFormatter.weekday(wall)}، ${JalaliFormatter.formatShortDate(wall)}';
  }

  /// Whether [a] and [b] fall on the same day on Tehran's calendar.
  static bool sameDay(DateTime a, DateTime b) => tehranDate(a) == tehranDate(b);

  /// A count for a badge: «۹+» beyond 9.
  static String badge(int count) => count > 9 ? '${PersianDigits.fromInt(9)}+' : PersianDigits.fromInt(count);

  /// The player-facing message for a failed chat call: the app's words for a known code, else the server's.
  static String error(Failure failure) => _messages[failure.code] ?? failure.message;

  /// The message for a rule checked on the device, by its code.
  static String rule(String code) => _messages[code] ?? AppStrings.genericError;

  static const Map<String, String> _messages = {
    ChatErrorCodes.requestNotAccepted: AppStrings.chatRequestNotAccepted,
    ChatErrorCodes.cannotReply: AppStrings.chatCannotReply,
    ChatErrorCodes.messageTooLong: AppStrings.chatMessageTooLong,
    ChatErrorCodes.requestMessageTooLong: AppStrings.chatRequestMessageTooLong,
    ChatErrorCodes.messageEmpty: AppStrings.chatMessageEmpty,
    ChatErrorCodes.playerNotFound: AppStrings.playerNotFound,
    ChatErrorCodes.conversationNotFound: AppStrings.chatConversationNotFound,
    ChatErrorCodes.tooManyRequests: AppStrings.chatTooManyRequests,
    ChatErrorCodes.cannotMessageSelf: AppStrings.chatCannotMessageSelf,
    ChatErrorCodes.profileRequired: AppStrings.profileRequired,
  };
}
