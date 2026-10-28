import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/realtime/polling_fallback.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';

import '../../helpers/fake_realtime.dart';

/// Polling is the fallback for a hub that cannot connect: on while it is down, off once it is up, with one catch-up
/// read when it comes back.
void main() {
  test('polls every interval while the hub is down, and not at all while it is up', () {
    fakeAsync((async) {
      final realtime = FakeRealtimeClient(status: RealtimeStatus.disconnected);
      var polls = 0;
      final polling = PollingFallback(realtime, interval: PollingFallback.chatInterval, onPoll: () => polls++)..start();

      async.elapse(const Duration(seconds: 14));
      expect(polls, 0);
      async.elapse(const Duration(seconds: 1));
      expect(polls, 1, reason: 'every 15 s on a chat screen');
      async.elapse(const Duration(seconds: 30));
      expect(polls, 3);
      expect(polling.isPolling, isTrue);

      polling.dispose();
      async.elapse(const Duration(minutes: 5));
      expect(polls, 3, reason: 'disposed');
    });
  });

  test('a connected hub means no polling; dropping starts it, reconnecting stops it after one catch-up read', () {
    fakeAsync((async) {
      final realtime = FakeRealtimeClient();
      var polls = 0;
      final polling = PollingFallback(realtime, interval: PollingFallback.backgroundInterval, onPoll: () => polls++)
        ..start();

      async.elapse(const Duration(minutes: 3));
      expect(polls, 0);
      expect(polling.isPolling, isFalse);

      realtime.setStatus(RealtimeStatus.connecting);
      async.elapse(const Duration(seconds: 60));
      expect(polls, 1, reason: 'every 60 s elsewhere');

      realtime.setStatus(RealtimeStatus.connected);
      expect(polls, 2, reason: 'one read for what was missed');
      async.elapse(const Duration(minutes: 5));
      expect(polls, 2);
      polling.dispose();
    });
  });

  test('a failing poll does not stop the next one', () {
    fakeAsync((async) {
      final realtime = FakeRealtimeClient(status: RealtimeStatus.disconnected);
      var polls = 0;
      final polling = PollingFallback(
        realtime,
        interval: const Duration(seconds: 15),
        onPoll: () async {
          polls++;
          throw StateError('offline');
        },
      )..start();

      async.elapse(const Duration(seconds: 45));
      expect(polls, 3);
      polling.dispose();
    });
  });

  test('reconnects back off: 0, 2, 5, 10, 30 seconds, then every minute', () {
    expect([for (var i = 0; i < 8; i++) RealtimeBackoff.delayFor(i).inSeconds], [0, 2, 5, 10, 30, 60, 60, 60]);
  });
}
