import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/auth/current_user.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/realtime/polling_fallback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/chat_repository.dart';
import '../../domain/chat_rules.dart';
import '../../domain/entities/chat.dart';
import '../chat_labels.dart';

/// Which conversation a screen opens: one by id (the inbox, a push, a deep link), the direct conversation with a
/// player (opened or created on the way in), or a match's group conversation.
class ConversationTarget extends Equatable {
  const ConversationTarget.id(String this.conversationId) : playerId = null, playerName = null, matchId = null;

  const ConversationTarget.player(String this.playerId, {this.playerName}) : conversationId = null, matchId = null;

  const ConversationTarget.match(String this.matchId) : conversationId = null, playerId = null, playerName = null;

  final String? conversationId;
  final String? playerId;

  /// Shown as the title until the conversation loads.
  final String? playerName;
  final String? matchId;

  @override
  List<Object?> get props => [conversationId, playerId, playerName, matchId];
}

/// One conversation (spec chat, design D8): history newest first, 50 a page; sending with a client id, kept pending
/// or failed and retried with the same id; read receipts both ways; deleted messages; the request recipient's accept,
/// ignore and block; mute. Live changes come over the realtime hub; while it is down, the screen polls every 15 s.
@injectable
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(
    this._chat,
    this._profiles,
    this._realtime,
    this._currentUser,
    @factoryParam ConversationTarget target, {
    @ignoreParam DateTime Function()? clock,
    @ignoreParam String Function()? newClientMessageId,
  }) : _target = target,
       _clock = clock ?? DateTime.now,
       _newClientMessageId = newClientMessageId ?? ChatRules.newClientMessageId,
       super(ConversationState(title: target.playerName ?? ''));

  final ChatRepository _chat;
  final ProfileRepository _profiles;
  final RealtimeClient _realtime;
  final CurrentUser _currentUser;
  final ConversationTarget _target;
  final DateTime Function() _clock;
  final String Function() _newClientMessageId;

  StreamSubscription<ChatEvent>? _events;
  PollingFallback? _polling;
  String? _markedUpTo;

  DateTime get now => _clock().toUtc();

  Future<void> load() async {
    emit(ConversationState(title: state.title));
    final me = await _currentUser.id();
    final conversation = await _resolve();
    if (isClosed) return;
    final failure = conversation.fold((f) => f, (_) => null);
    final found = conversation.fold((_) => null, (c) => c);
    if (found == null) {
      final missingGroup = failure == null;
      emit(
        ConversationState(
          title: state.title,
          status: ViewStatus.error,
          notFound: missingGroup || failure is NotFoundFailure,
          noMatchChat: missingGroup,
          errorMessage: missingGroup ? AppStrings.matchChatMissing : ChatLabels.error(failure),
        ),
      );
      return;
    }
    final history = await _chat.getHistory(found.id);
    if (isClosed) return;
    history.fold(
      (f) => emit(
        ConversationState(
          title: found.title,
          status: ViewStatus.error,
          notFound: f is NotFoundFailure,
          errorMessage: ChatLabels.error(f),
        ),
      ),
      (page) {
        emit(
          ConversationState(
            title: found.title,
            status: ViewStatus.content,
            conversation: found,
            myId: me,
            messages: _sorted(page.items),
            nextCursor: page.nextCursor,
          ),
        );
        _listen();
        unawaited(_markRead());
      },
    );
  }

  /// The conversation the target names; a Right(null) when a match has no group conversation for this player (the
  /// server's CONVERSATION_NOT_FOUND).
  Future<Either<Failure, Conversation?>> _resolve() async {
    final id = _target.conversationId;
    if (id != null) return _chat.getConversation(id);
    final playerId = _target.playerId;
    if (playerId != null) return _chat.openDirect(playerId);
    final result = await _chat.getMatchConversation(_target.matchId ?? '');
    return result.fold(
      (failure) => failure.code == ChatErrorCodes.conversationNotFound ? const Right(null) : Left(failure),
      (conversation) => Right(conversation),
    );
  }

  void _listen() {
    _events ??= _chat.events.listen(_onEvent);
    _polling ??= PollingFallback(_realtime, interval: PollingFallback.chatInterval, onPoll: refresh)..start();
  }

  /// Fetches the conversation and its newest page again (the polling fallback, and catching up after reconnecting).
  /// Pending, failed and older messages stay.
  Future<void> refresh() async {
    final conversation = state.conversation;
    if (conversation == null) return;
    final summary = await _chat.getConversation(conversation.id);
    final page = await _chat.getHistory(conversation.id);
    if (isClosed) return;
    emit(
      state.copyWith(
        conversation: summary.fold((_) => null, (c) => c),
        messages: page.fold((_) => null, (p) => _merged(state.messages, p.items)),
      ),
    );
    await _markRead();
  }

  Future<void> loadOlder() async {
    final conversation = state.conversation;
    final cursor = state.nextCursor;
    if (conversation == null || cursor == null || state.loadingOlder) return;
    emit(state.copyWith(loadingOlder: true));
    final result = await _chat.getHistory(conversation.id, before: cursor);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(loadingOlder: false, feedback: ProfileFeedback(ChatLabels.error(failure), isError: true)),
      ),
      (page) => emit(
        state.copyWith(
          loadingOlder: false,
          messages: _merged(state.messages, page.items),
          nextCursor: () => page.nextCursor,
        ),
      ),
    );
  }

  /// Sends [text]. The message for what is wrong with it (the text stays in the field), or null once it is on its way:
  /// it shows at once as pending, and as failed (to retry) when the server does not take it.
  Future<String?> send(String text) async {
    final problem = checkMessage(text);
    if (problem != null) return problem;
    final conversation = state.conversation!;
    final message = ChatMessage(
      id: '',
      conversationId: conversation.id,
      senderId: state.myId ?? '',
      senderName: '',
      body: text.trim(),
      sentAt: now,
      clientMessageId: _newClientMessageId(),
      delivery: MessageDelivery.pending,
    );
    emit(state.copyWith(messages: _sorted([message, ...state.messages])));
    await _deliver(message);
    return null;
  }

  /// The message for what is wrong with sending [text] now, or null when it can go: not empty, at most 1000 characters
  /// (500 for a request's first message), and a conversation this player can still write in.
  String? checkMessage(String text) {
    final conversation = state.conversation;
    if (conversation == null) return AppStrings.genericError;
    if (!conversation.canSend) return AppStrings.chatCannotReply;
    final code = ChatRules.checkBody(text, asRequest: state.sendsRequest);
    return code == null ? null : ChatLabels.rule(code);
  }

  /// Sends a failed message again, under the same client id, so the server never stores it twice.
  Future<void> retry(ChatMessage message) async {
    if (message.delivery != MessageDelivery.failed) return;
    final pending = message.copyWith(delivery: MessageDelivery.pending, errorMessage: () => null);
    _replace(pending);
    await _deliver(pending);
  }

  /// Drops a failed message that will not be sent.
  void discard(ChatMessage message) {
    if (message.delivery != MessageDelivery.failed) return;
    emit(state.copyWith(messages: [...state.messages.where((m) => m.key != message.key)]));
  }

  Future<void> _deliver(ChatMessage message) async {
    final conversation = state.conversation!;
    final result = await _chat.send(
      conversation.id,
      clientMessageId: message.clientMessageId,
      body: message.body ?? '',
    );
    if (isClosed) return;
    await result.fold(
      (failure) async {
        // MESSAGE_TOO_LONG is 500 characters for a request's first message, 1000 otherwise.
        final words = failure.code == ChatErrorCodes.messageTooLong && state.sendsRequest
            ? AppStrings.chatRequestMessageTooLong
            : ChatLabels.error(failure);
        final closed = failure.code == ChatErrorCodes.cannotReply || failure.code == ChatErrorCodes.requestNotAccepted;
        _replace(message.copyWith(delivery: MessageDelivery.failed, errorMessage: () => words));
        emit(
          state.copyWith(
            conversation: closed ? state.conversation?.copyWith(canSend: false) : null,
            feedback: ProfileFeedback(words, isError: true, code: failure.code),
          ),
        );
      },
      (sent) async {
        emit(state.copyWith(messages: _merged(state.messages, [sent])));
        // A request's first message, or a recipient's reply, changes who can send next.
        if (conversation.isRequest) await _refreshSummary();
        await _markRead();
      },
    );
  }

  /// Deletes this player's own message for everyone; it then shows as «پیام حذف شد».
  Future<void> delete(ChatMessage message) async {
    final conversation = state.conversation;
    if (conversation == null || !message.isSent || message.deleted || message.senderId != state.myId) return;
    final result = await _chat.deleteMessage(conversation.id, message.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(feedback: ProfileFeedback(ChatLabels.error(failure), isError: true))),
      (_) {
        _markDeleted(message.id);
        emit(state.copyWith(feedback: const ProfileFeedback(AppStrings.messageDeleted)));
      },
    );
  }

  /// The request's recipient accepts: both can write freely from now on.
  Future<void> accept() => _answer(accept: true);

  /// The request's recipient ignores it, silently for the sender; the screen closes.
  Future<void> ignore() => _answer(accept: false);

  Future<void> _answer({required bool accept}) async {
    final conversation = state.conversation;
    if (conversation == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final result = await _chat.answerRequest(conversation.id, accept: accept);
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(state.copyWith(busy: false, feedback: ProfileFeedback(ChatLabels.error(failure), isError: true))),
      (updated) => emit(
        state.copyWith(
          busy: false,
          conversation: updated,
          left: !accept,
          feedback: ProfileFeedback(accept ? AppStrings.requestAcceptedDone : AppStrings.requestIgnoredDone),
        ),
      ),
    );
  }

  /// Blocks the other player of a direct conversation (`POST /blocks/{userId}`); the screen closes, and the
  /// conversation leaves this player's list.
  Future<void> blockOther() async {
    final conversation = state.conversation;
    final other = conversation?.otherUserId;
    if (conversation == null || other == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final result = await _profiles.blockPlayer(other);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(busy: false, feedback: ProfileFeedback(failure.message, isError: true))),
      (_) => emit(
        state.copyWith(busy: false, left: true, feedback: ProfileFeedback(AppStrings.blocked(conversation.title))),
      ),
    );
  }

  Future<void> toggleMute() async {
    final conversation = state.conversation;
    if (conversation == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final mute = !conversation.muted;
    final result = await _chat.setMuted(conversation.id, muted: mute);
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(state.copyWith(busy: false, feedback: ProfileFeedback(ChatLabels.error(failure), isError: true))),
      (updated) => emit(
        state.copyWith(
          busy: false,
          conversation: updated,
          feedback: ProfileFeedback(mute ? AppStrings.conversationMuted : AppStrings.conversationUnmuted),
        ),
      ),
    );
  }

  void _onEvent(ChatEvent event) {
    final conversation = state.conversation;
    if (conversation == null || event.conversationId != conversation.id) return;
    switch (event) {
      case MessageReceived(:final message):
        emit(state.copyWith(messages: _merged(state.messages, [message])));
        if (conversation.isRequest) unawaited(_refreshSummary());
        unawaited(_markRead());
      case MessageDeleted(:final messageId):
        _markDeleted(messageId);
      case ConversationRead(:final userId, :final upToMessageId):
        if (userId == state.myId) return;
        // In a group, one member reading is not everyone reading: the server works that out on the next page.
        if (conversation.isMatch || !_markReadByOthers(upToMessageId)) unawaited(refresh());
    }
  }

  /// Marks this player's messages up to [upToMessageId] as read; false when that message is not loaded.
  bool _markReadByOthers(String upToMessageId) {
    final messages = state.messages;
    final index = messages.indexWhere((m) => m.id == upToMessageId);
    if (index < 0) return false;
    emit(
      state.copyWith(
        messages: [
          for (var i = 0; i < messages.length; i++)
            i >= index && messages[i].isSent && messages[i].senderId == state.myId && !messages[i].readByOthers
                ? messages[i].copyWith(readByOthers: true)
                : messages[i],
        ],
      ),
    );
    return true;
  }

  void _markDeleted(String messageId) => emit(
    state.copyWith(
      messages: [for (final m in state.messages) m.id == messageId ? m.copyWith(deleted: true, clearBody: true) : m],
    ),
  );

  /// Moves the read cursor up to the newest message on the screen, once per message.
  Future<void> _markRead() async {
    final conversation = state.conversation;
    if (conversation == null) return;
    String? newest;
    for (final m in state.messages) {
      if (m.isSent && m.id.isNotEmpty) {
        newest = m.id;
        break;
      }
    }
    if (newest == null || newest == _markedUpTo) return;
    _markedUpTo = newest;
    final result = await _chat.markRead(conversation.id, newest);
    // Not marked: the next message or poll tries again.
    if (result.isLeft() && _markedUpTo == newest) _markedUpTo = null;
  }

  Future<void> _refreshSummary() async {
    final conversation = state.conversation;
    if (conversation == null) return;
    final result = await _chat.getConversation(conversation.id);
    if (isClosed) return;
    result.fold((_) {}, (updated) => emit(state.copyWith(conversation: updated)));
  }

  void _replace(ChatMessage message) =>
      emit(state.copyWith(messages: [for (final m in state.messages) m.key == message.key ? message : m]));

  /// [incoming] over [current]: the server's copy wins (a pending message becomes sent), nothing is repeated.
  static List<ChatMessage> _merged(List<ChatMessage> current, Iterable<ChatMessage> incoming) {
    final byKey = {for (final m in current) m.key: m};
    for (final m in incoming) {
      byKey[m.key] = m;
    }
    return _sorted(byKey.values);
  }

  /// Newest first: messages not yet on the server on top, then by send time.
  static List<ChatMessage> _sorted(Iterable<ChatMessage> messages) => [...messages]
    ..sort((a, b) {
      if (a.isSent != b.isSent) return a.isSent ? 1 : -1;
      final byTime = b.sentAt.compareTo(a.sentAt);
      return byTime != 0 ? byTime : b.key.compareTo(a.key);
    });

  @override
  Future<void> close() async {
    // The poll timer stops at once, before anything is awaited.
    final polling = _polling?.dispose();
    await _events?.cancel();
    await polling;
    return super.close();
  }
}

class ConversationState extends Equatable {
  const ConversationState({
    this.title = '',
    this.status = ViewStatus.loading,
    this.notFound = false,
    this.noMatchChat = false,
    this.errorMessage,
    this.conversation,
    this.myId,
    this.messages = const [],
    this.nextCursor,
    this.loadingOlder = false,
    this.busy = false,
    this.left = false,
    this.feedback,
  });

  final String title;
  final ViewStatus status;

  /// Not a member, or gone: retrying will not help.
  final bool notFound;

  /// The match has no group conversation (yet) for this player.
  final bool noMatchChat;
  final String? errorMessage;
  final Conversation? conversation;

  /// This player's user id, to tell their messages apart.
  final String? myId;

  /// Newest first; messages not yet on the server on top.
  final List<ChatMessage> messages;

  /// The cursor of the next older page; null when the oldest is loaded.
  final String? nextCursor;
  final bool loadingOlder;

  /// An accept, ignore, block or mute is on its way.
  final bool busy;

  /// The player ignored the request or blocked the sender: the screen closes.
  final bool left;
  final ProfileFeedback? feedback;

  bool isMine(ChatMessage message) => myId != null && message.senderId == myId;

  /// This player received the request and it is still pending, as the server says.
  bool get isRequestRecipient => conversation?.isRequestRecipient ?? false;

  /// This player's next message is a request's first message, limited to 500 characters.
  bool get sendsRequest => (conversation?.isRequest ?? false) && !isRequestRecipient;

  int get maxLength => sendsRequest ? ChatRules.requestMaxLength : ChatRules.maxLength;

  bool get canSend => conversation?.canSend ?? false;

  /// The safety notice goes above the messages of a request, and of a direct conversation where the two players have
  /// not both written yet (spec chat › Safety notice in new conversations).
  bool get showSafetyNotice {
    final c = conversation;
    if (c == null || c.isMatch) return false;
    if (c.isRequest) return true;
    if (nextCursor != null) return false;
    final sent = messages.where((m) => m.isSent);
    return !(sent.any(isMine) && sent.any((m) => !isMine(m)));
  }

  ConversationState copyWith({
    Conversation? conversation,
    List<ChatMessage>? messages,
    String? Function()? nextCursor,
    bool? loadingOlder,
    bool? busy,
    bool? left,
    ProfileFeedback? feedback,
  }) => ConversationState(
    title: conversation?.title ?? title,
    status: status,
    notFound: notFound,
    noMatchChat: noMatchChat,
    errorMessage: errorMessage,
    conversation: conversation ?? this.conversation,
    myId: myId,
    messages: messages ?? this.messages,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
    loadingOlder: loadingOlder ?? this.loadingOlder,
    busy: busy ?? this.busy,
    left: left ?? this.left,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [
    title,
    status,
    notFound,
    noMatchChat,
    errorMessage,
    conversation,
    myId,
    messages,
    nextCursor,
    loadingOlder,
    busy,
    left,
    feedback,
  ];
}
