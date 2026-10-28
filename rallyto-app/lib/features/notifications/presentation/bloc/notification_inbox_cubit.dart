import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/realtime/polling_fallback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../profile/presentation/bloc/my_profile_cubit.dart';
import '../../domain/entities/notification.dart';
import '../../domain/notification_repository.dart';
import '../deep_links.dart';
import '../notification_labels.dart';

/// The notification inbox (spec notifications › In-app notification inbox): newest first, a page at a time, opened
/// entries marked read, everything marked read at once. New entries arrive live over the realtime hub; while it is
/// down the first page is re-read every 60 s.
@injectable
class NotificationInboxCubit extends Cubit<NotificationInboxState> {
  NotificationInboxCubit(this._notifications, this._realtime) : super(const NotificationInboxState());

  static const int pageSize = 20;

  final NotificationRepository _notifications;
  final RealtimeClient _realtime;
  StreamSubscription<NotificationCreated>? _created;
  PollingFallback? _polling;

  Future<void> load() async {
    emit(const NotificationInboxState());
    final result = await _notifications.getInbox(pageSize: pageSize);
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(NotificationInboxState(status: ViewStatus.error, errorMessage: NotificationLabels.error(failure))),
      (page) => emit(
        NotificationInboxState(
          status: page.items.isEmpty ? ViewStatus.empty : ViewStatus.content,
          items: page.items,
          page: 1,
          hasMore: page.hasMore,
        ),
      ),
    );
    _created ??= _notifications.created.listen((event) => _add([event.notification]));
    _polling ??= PollingFallback(_realtime, interval: PollingFallback.backgroundInterval, onPoll: refresh)..start();
  }

  /// Re-reads the first page and merges it in.
  Future<void> refresh() async {
    final result = await _notifications.getInbox(pageSize: pageSize);
    if (isClosed) return;
    result.fold((_) {}, (page) => _add(page.items));
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final next = state.page + 1;
    final result = await _notifications.getInbox(page: next, pageSize: pageSize);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(loadingMore: false, feedback: ProfileFeedback(NotificationLabels.error(failure), isError: true)),
      ),
      (page) {
        final shown = {for (final n in state.items) n.id};
        emit(
          state.copyWith(
            loadingMore: false,
            page: next,
            hasMore: page.hasMore,
            items: [
              ...state.items,
              for (final n in page.items)
                if (!shown.contains(n.id)) n,
            ],
          ),
        );
      },
    );
  }

  /// Marks [notification] read (at once on screen; the server is told) and answers where it leads, or null when its
  /// link names nothing the app knows.
  Future<String?> open(AppNotification notification) async {
    if (!notification.isRead) {
      emit(
        state.copyWith(items: [for (final n in state.items) n.id == notification.id ? n.copyWith(isRead: true) : n]),
      );
      unawaited(_notifications.markRead(notification.id));
    }
    return DeepLinks.locationFor(notification.deepLink);
  }

  Future<void> markAllRead() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    final result = await _notifications.markAllRead();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(busy: false, feedback: ProfileFeedback(NotificationLabels.error(failure), isError: true)),
      ),
      (_) => emit(
        state.copyWith(
          busy: false,
          items: [for (final n in state.items) n.copyWith(isRead: true)],
          feedback: const ProfileFeedback(AppStrings.allMarkedRead),
        ),
      ),
    );
  }

  /// [incoming] merged in, newest first, without repeats; the server's copy wins.
  void _add(List<AppNotification> incoming) {
    if (incoming.isEmpty || (state.status != ViewStatus.content && state.status != ViewStatus.empty)) return;
    final byId = {for (final n in state.items) n.id: n};
    for (final n in incoming) {
      byId[n.id] = n;
    }
    final items = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(status: ViewStatus.content, items: items));
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

class NotificationInboxState extends Equatable {
  const NotificationInboxState({
    this.status = ViewStatus.loading,
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
    this.busy = false,
    this.errorMessage,
    this.feedback,
  });

  final ViewStatus status;

  /// Newest first.
  final List<AppNotification> items;

  /// The last page loaded.
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Marking everything read is on its way.
  final bool busy;
  final String? errorMessage;
  final ProfileFeedback? feedback;

  bool get hasUnread => items.any((n) => !n.isRead);

  NotificationInboxState copyWith({
    ViewStatus? status,
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? busy,
    ProfileFeedback? feedback,
  }) => NotificationInboxState(
    status: status ?? this.status,
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    busy: busy ?? this.busy,
    errorMessage: errorMessage,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, items, page, hasMore, loadingMore, busy, errorMessage, feedback];
}
