import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/chat_badge_cubit.dart';
import 'package:rallyto_app/features/home/presentation/bloc/home_cubit.dart';
import 'package:rallyto_app/features/home/presentation/pages/home_page.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_badge_cubit.dart';

import 'fake_chat.dart';
import 'fake_matches.dart';
import 'fake_notifications.dart';
import 'fake_profile.dart';
import 'fake_realtime.dart';

/// [HomePage] with its badge cubits over fakes, started, as the home route builds it, and its [HomeCubit] over fake
/// profile, games and availability, loaded at [now] (the tests' "now" by default).
Widget homeWithBadges({
  FakeChatRepository? chat,
  FakeNotificationRepository? notifications,
  FakeRealtimeClient? realtime,
  FakeProfileRepository? profiles,
  FakeMatchRepository? matches,
  FakeAvailabilityRepository? availability,
  DateTime? now,
}) {
  final hub = realtime ?? FakeRealtimeClient();
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => ChatBadgeCubit(chat ?? FakeChatRepository(), hub)..start()),
      BlocProvider(create: (_) => NotificationBadgeCubit(notifications ?? FakeNotificationRepository(), hub)..start()),
      BlocProvider(
        create: (_) => HomeCubit(
          profiles ?? FakeProfileRepository(),
          matches ?? FakeMatchRepository(),
          availability ?? FakeAvailabilityRepository(),
          clock: () => now ?? testNow,
        )..load(),
      ),
    ],
    child: const HomePage(),
  );
}
