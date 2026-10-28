import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/realtime/polling_fallback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../domain/chat_repository.dart';
import '../../domain/entities/chat.dart';

/// The chat badge on the home screen: how many conversations and requests have unread messages. Every message event
/// re-reads the counts (the event alone cannot say whether a conversation was already unread); while the hub is down
/// it polls every 60 s.
@injectable
class ChatBadgeCubit extends Cubit<ChatUnreadCounts> {
  ChatBadgeCubit(this._chat, this._realtime) : super(const ChatUnreadCounts());

  final ChatRepository _chat;
  final RealtimeClient _realtime;
  StreamSubscription<ChatEvent>? _events;
  PollingFallback? _polling;

  Future<void> start() async {
    _events ??= _chat.events.listen((event) {
      if (event is MessageReceived) unawaited(refresh());
    });
    _polling ??= PollingFallback(_realtime, interval: PollingFallback.backgroundInterval, onPoll: refresh)..start();
    await refresh();
  }

  /// Reads the counts again; a failure keeps the last ones.
  Future<void> refresh() async {
    final result = await _chat.getUnreadCounts();
    if (isClosed) return;
    result.fold((_) {}, emit);
  }

  @override
  Future<void> close() async {
    // The poll timer stops at once, before anything is awaited.
    final polling = _polling?.dispose();
    await _events?.cancel();
    await polling;
    return super.close();
  }
}
