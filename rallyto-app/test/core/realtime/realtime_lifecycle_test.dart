import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/realtime/realtime_lifecycle.dart';

import '../../helpers/fake_realtime.dart';
import '../../helpers/memory_secure_storage.dart';

/// The hub is up exactly while the player is signed in and the app is in the foreground.
void main() {
  late AuthSessionCubit session;
  late FakeRealtimeClient realtime;
  late RealtimeLifecycle lifecycle;

  setUp(() {
    session = AuthSessionCubit(memoryTokenStorage(MemorySecureStorage(timers: false)));
    realtime = FakeRealtimeClient();
    lifecycle = RealtimeLifecycle(session, realtime);
  });

  tearDown(() async {
    await lifecycle.dispose();
    await session.close();
  });

  test('signed out, nothing connects; signing in connects; signing out tears it down', () async {
    lifecycle.start(observeApp: false);
    await pumpEventQueue();
    expect(realtime.running, isFalse);

    await session.signIn(testSession());
    await pumpEventQueue();
    expect(realtime.running, isTrue);

    await session.signOut();
    await pumpEventQueue();
    expect(realtime.running, isFalse);
  });

  test('the background disconnects and the foreground reconnects; a passing dialog changes nothing', () async {
    await session.signIn(testSession());
    lifecycle.start(observeApp: false);
    await pumpEventQueue();
    expect(realtime.running, isTrue);

    lifecycle.appLifecycleChanged(AppLifecycleState.inactive);
    expect(realtime.running, isTrue);

    lifecycle.appLifecycleChanged(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(realtime.running, isFalse);

    lifecycle.appLifecycleChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(realtime.running, isTrue);
  });

  test('signing in while in the background waits for the foreground', () async {
    lifecycle.start(observeApp: false);
    lifecycle.appLifecycleChanged(AppLifecycleState.hidden);

    await session.signIn(testSession());
    await pumpEventQueue();
    expect(realtime.running, isFalse);

    lifecycle.appLifecycleChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(realtime.running, isTrue);
  });
}
