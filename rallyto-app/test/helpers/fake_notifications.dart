import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/push/push_service.dart';
import 'package:rallyto_app/features/notifications/domain/entities/notification.dart';
import 'package:rallyto_app/features/notifications/domain/notification_repository.dart';

/// A [NotificationRepository] answering from what the test set, recording what it was asked. [emit] delivers a
/// realtime `notification.created`.
class FakeNotificationRepository implements NotificationRepository {
  /// Pages by number.
  Map<int, NotificationPage> pages = {
    1: NotificationPage(
      items: [
        testNotification(id: 'n-2', title: 'درخواست پیوستن', deepLink: '/matches/m-1', minute: 50),
        testNotification(id: 'n-1', title: 'جستجوی ذخیره‌شده', deepLink: '/saved-searches/ss-1', isRead: true),
      ],
      totalCount: 2,
    ),
  };
  int unreadCount = 1;
  NotificationPreferences preferences = const NotificationPreferences();

  /// When set, reads answer with it.
  Failure? loadFailure;

  /// When set, writes answer with it.
  Failure? actionFailure;

  final List<String> calls = [];
  final List<NotificationPreferences> saved = [];

  final StreamController<NotificationCreated> _created = StreamController<NotificationCreated>.broadcast(sync: true);

  void emit(NotificationCreated event) => _created.add(event);

  @override
  Stream<NotificationCreated> get created => _created.stream;

  @override
  Future<Either<Failure, NotificationPage>> getInbox({int page = 1, int pageSize = 20}) async {
    calls.add('inbox:$page');
    final failure = loadFailure;
    return failure == null ? Right(pages[page] ?? NotificationPage(page: page, pageSize: pageSize)) : Left(failure);
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    calls.add('unread');
    final failure = loadFailure;
    return failure == null ? Right(unreadCount) : Left(failure);
  }

  @override
  Future<Either<Failure, Unit>> markRead(String id) async {
    calls.add('read:$id');
    final failure = actionFailure;
    return failure == null ? const Right(unit) : Left(failure);
  }

  @override
  Future<Either<Failure, Unit>> markAllRead() async {
    calls.add('readAll');
    final failure = actionFailure;
    return failure == null ? const Right(unit) : Left(failure);
  }

  @override
  Future<Either<Failure, NotificationPreferences>> getPreferences() async {
    calls.add('preferences');
    final failure = loadFailure;
    return failure == null ? Right(preferences) : Left(failure);
  }

  @override
  Future<Either<Failure, NotificationPreferences>> updatePreferences(NotificationPreferences preferences) async {
    saved.add(preferences);
    final failure = actionFailure;
    if (failure != null) return Left(failure);
    this.preferences = preferences;
    return Right(preferences);
  }
}

/// A [DeviceTokenRepository] recording what it was asked.
class FakeDeviceTokenRepository implements DeviceTokenRepository {
  final List<(String token, String platform)> registered = [];
  final List<String> unregistered = [];

  /// When set, registering answers with it.
  Failure? failure;

  @override
  Future<Either<Failure, Unit>> register(String token, {required String platform}) async {
    registered.add((token, platform));
    final failure = this.failure;
    return failure == null ? const Right(unit) : Left(failure);
  }

  @override
  Future<Either<Failure, Unit>> unregister(String token) async {
    unregistered.add(token);
    return const Right(unit);
  }
}

/// A [PushService] the test drives: [available] decides whether it starts; [rotate] and [tap] act as FCM would.
class FakePushService implements PushService {
  FakePushService({this.available = true, this.token = 'fcm-1', this.initial});

  bool available;
  String? token;
  Map<String, String>? initial;
  int initializations = 0;

  final StreamController<String> _refreshes = StreamController<String>.broadcast(sync: true);
  final StreamController<Map<String, String>> _opened = StreamController<Map<String, String>>.broadcast(sync: true);

  void rotate(String next) {
    token = next;
    _refreshes.add(next);
  }

  void tap(Map<String, String> data) => _opened.add(data);

  @override
  Future<bool> initialize() async {
    initializations++;
    return available;
  }

  @override
  Future<String?> getToken() async => available ? token : null;

  @override
  String get platform => 'android';

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<Map<String, String>> get openedNotifications => _opened.stream;

  @override
  Future<Map<String, String>?> takeInitialNotification() async {
    final data = initial;
    initial = null;
    return data;
  }
}

/// A notification created at 07:[minute] UTC on 2026-10-23.
AppNotification testNotification({
  required String id,
  String title = 'درخواست پیوستن',
  String body = 'رضا می‌خواهد به بازی شما بپیوندد.',
  String? deepLink,
  bool isRead = false,
  int minute = 0,
  NotificationCategory category = NotificationCategory.matches,
}) => AppNotification(
  id: id,
  code: 'join-request.received',
  category: category,
  title: title,
  body: body,
  deepLink: deepLink,
  createdAt: DateTime.utc(2026, 10, 23, 7, minute),
  isRead: isRead,
);
