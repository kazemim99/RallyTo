import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/realtime/polling_fallback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../domain/entities/notification.dart';
import '../../domain/notification_repository.dart';

/// The notification badge on the home screen: the inbox's unread count, updated live from `notification.created`
/// (which carries the new count) and re-read every 60 s while the hub is down.
@injectable
class NotificationBadgeCubit extends Cubit<int> {
  NotificationBadgeCubit(this._notifications, this._realtime) : super(0);

  final NotificationRepository _notifications;
  final RealtimeClient _realtime;
  StreamSubscription<NotificationCreated>? _created;
  PollingFallback? _polling;

  Future<void> start() async {
    _created ??= _notifications.created.listen((event) {
      if (!isClosed) emit(event.unreadCount);
    });
    _polling ??= PollingFallback(_realtime, interval: PollingFallback.backgroundInterval, onPoll: refresh)..start();
    await refresh();
  }

  /// Reads the count again; a failure keeps the last one.
  Future<void> refresh() async {
    final result = await _notifications.getUnreadCount();
    if (isClosed) return;
    result.fold((_) {}, emit);
  }

  @override
  Future<void> close() async {
    // The poll timer stops at once, before anything is awaited.
    final polling = _polling?.dispose();
    await _created?.cancel();
    await polling;
    return super.close();
  }
}
