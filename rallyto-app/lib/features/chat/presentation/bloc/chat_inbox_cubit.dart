import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/realtime/polling_fallback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/chat_repository.dart';
import '../../domain/entities/chat.dart';
import '../chat_labels.dart';

/// The chat inbox: conversations and message requests in two tabs, each with its unread badge
/// (`GET /conversations/unread`). Any chat event reloads it; while the hub is down it polls every 15 s. A request can
/// be accepted, ignored, or its sender blocked (through [ProfileRepository], as on the conversation screen).
@injectable
class ChatInboxCubit extends Cubit<ChatInboxState> {
  ChatInboxCubit(this._chat, this._realtime, this._profiles) : super(const ChatInboxState());

  final ChatRepository _chat;
  final RealtimeClient _realtime;
  final ProfileRepository _profiles;
  StreamSubscription<ChatEvent>? _events;
  PollingFallback? _polling;
  bool _reloading = false;
  bool _again = false;

  Future<void> load() async {
    emit(const ChatInboxState());
    await _fetch();
    _events ??= _chat.events.listen((_) => unawaited(refresh()));
    _polling ??= PollingFallback(_realtime, interval: PollingFallback.chatInterval, onPoll: refresh)..start();
  }

  /// Reloads both lists and the badges without showing a spinner. Events arriving meanwhile cause one more reload.
  Future<void> refresh() async {
    if (_reloading) {
      _again = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _again = false;
        await _fetch();
      } while (_again && !isClosed);
    } finally {
      _reloading = false;
    }
  }

  /// The recipient accepts or ignores a message request from its card in the inbox, then both lists reload. True once
  /// the server took the answer; a refusal is said as feedback. One answer at a time.
  Future<bool> answerRequest(Conversation request, {required bool accept}) async {
    if (state.answeringId != null) return false;
    emit(state.copyWith(answeringId: () => request.id));
    final result = await _chat.answerRequest(request.id, accept: accept);
    if (isClosed) return false;
    final answered = result.fold(
      (failure) {
        emit(
          state.copyWith(
            answeringId: () => null,
            feedback: ProfileFeedback(ChatLabels.error(failure), isError: true, code: failure.code),
          ),
        );
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            answeringId: () => null,
            feedback: ProfileFeedback(accept ? AppStrings.requestAcceptedDone : AppStrings.requestIgnoredDone),
          ),
        );
        return true;
      },
    );
    await refresh();
    return answered;
  }

  /// The recipient blocks a request's sender from its card (`POST /blocks/{userId}`, the conversation screen's path):
  /// the request leaves the list at once, then both lists reload. True once blocked; a refusal is said as feedback.
  /// Shares the one-answer-at-a-time slot with [answerRequest].
  Future<bool> blockSender(Conversation request) async {
    final sender = request.otherUserId;
    if (state.answeringId != null || sender == null) return false;
    emit(state.copyWith(answeringId: () => request.id));
    final result = await _profiles.blockPlayer(sender);
    if (isClosed) return false;
    final blocked = result.fold(
      (failure) {
        emit(
          state.copyWith(
            answeringId: () => null,
            feedback: ProfileFeedback(ChatLabels.error(failure), isError: true, code: failure.code),
          ),
        );
        return false;
      },
      (_) {
        final left = [
          for (final r in state.requests.items)
            if (r.id != request.id) r,
        ];
        emit(
          state.copyWith(
            answeringId: () => null,
            requests: ConversationList(status: left.isEmpty ? ViewStatus.empty : ViewStatus.content, items: left),
            feedback: ProfileFeedback(AppStrings.blocked(request.title)),
          ),
        );
        return true;
      },
    );
    await refresh();
    return blocked;
  }

  Future<void> _fetch() async {
    final inbox = _chat.getConversations();
    final requests = _chat.getConversations(requests: true);
    final unread = _chat.getUnreadCounts();
    final inboxResult = await inbox;
    final requestsResult = await requests;
    final unreadResult = await unread;
    if (isClosed) return;
    emit(
      ChatInboxState(
        conversations: _listOf(inboxResult, state.conversations),
        requests: _listOf(requestsResult, state.requests),
        unread: unreadResult.fold((_) => state.unread, (u) => u),
        answeringId: state.answeringId,
        feedback: state.feedback,
      ),
    );
  }

  /// A failed reload keeps what was shown; a failed first load is an error to retry.
  static ConversationList _listOf(Either<Failure, List<Conversation>> result, ConversationList shown) => result.fold(
    (failure) => shown.status == ViewStatus.content || shown.status == ViewStatus.empty
        ? shown
        : ConversationList(status: ViewStatus.error, errorMessage: ChatLabels.error(failure)),
    (list) => ConversationList(status: list.isEmpty ? ViewStatus.empty : ViewStatus.content, items: list),
  );

  @override
  Future<void> close() async {
    // The poll timer stops at once, before anything is awaited.
    final polling = _polling?.dispose();
    await _events?.cancel();
    await polling;
    return super.close();
  }
}

/// One tab's conversations.
class ConversationList extends Equatable {
  const ConversationList({this.status = ViewStatus.loading, this.items = const [], this.errorMessage});

  final ViewStatus status;
  final List<Conversation> items;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, items, errorMessage];
}

class ChatInboxState extends Equatable {
  const ChatInboxState({
    this.conversations = const ConversationList(),
    this.requests = const ConversationList(),
    this.unread = const ChatUnreadCounts(),
    this.answeringId,
    this.feedback,
  });

  final ConversationList conversations;
  final ConversationList requests;
  final ChatUnreadCounts unread;

  /// The request whose answer (accept, ignore or block) is on its way.
  final String? answeringId;

  /// The latest answer's outcome.
  final ProfileFeedback? feedback;

  ChatInboxState copyWith({ConversationList? requests, String? Function()? answeringId, ProfileFeedback? feedback}) =>
      ChatInboxState(
        conversations: conversations,
        requests: requests ?? this.requests,
        unread: unread,
        answeringId: answeringId == null ? this.answeringId : answeringId(),
        feedback: feedback ?? this.feedback,
      );

  @override
  List<Object?> get props => [conversations, requests, unread, answeringId, feedback];
}
