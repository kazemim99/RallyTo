import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/routes/app_router.dart';
import 'package:rallyto_app/features/notifications/domain/entities/notification.dart';
import 'package:rallyto_app/features/notifications/domain/notification_rules.dart';
import 'package:rallyto_app/features/notifications/presentation/deep_links.dart';

/// Quiet hours (30-minute steps, may span midnight, default 23:00–08:00) and where deep links go.
void main() {
  group('quiet hours', () {
    test('default to 23:00–08:00, on', () {
      const defaults = NotificationPreferences();
      expect(defaults.quietHoursEnabled, isTrue);
      expect(defaults.quietStartMinute, 23 * 60);
      expect(defaults.quietEndMinute, 8 * 60);
    });

    test('a window across midnight covers the night and not the day', () {
      const night = NotificationPreferences();
      expect(QuietHoursRules.isQuiet(night, 23 * 60), isTrue);
      expect(QuietHoursRules.isQuiet(night, 1 * 60), isTrue, reason: '01:00');
      expect(QuietHoursRules.isQuiet(night, 7 * 60 + 59), isTrue);
      expect(QuietHoursRules.isQuiet(night, 8 * 60), isFalse, reason: 'the end is not quiet');
      expect(QuietHoursRules.isQuiet(night, 12 * 60), isFalse);
      expect(QuietHoursRules.isQuiet(night.copyWith(quietHoursEnabled: false), 1 * 60), isFalse);
    });

    test('a window within a day', () {
      const afternoon = NotificationPreferences(quietStartMinute: 13 * 60, quietEndMinute: 15 * 60 + 30);
      expect(QuietHoursRules.isQuiet(afternoon, 14 * 60), isTrue);
      expect(QuietHoursRules.isQuiet(afternoon, 16 * 60), isFalse);
      expect(QuietHoursRules.isQuiet(afternoon, 1 * 60), isFalse);
    });

    test('times are in 30-minute steps from 00:00 to 23:30', () {
      expect(QuietHoursRules.options.first, 0);
      expect(QuietHoursRules.options.last, 23 * 60 + 30);
      expect(QuietHoursRules.options, hasLength(48));
      expect(
        QuietHoursRules.check(const NotificationPreferences(quietStartMinute: 22 * 60 + 15)),
        NotificationErrorCodes.invalidQuietHours,
      );
    });

    test('the same start and end are refused while quiet hours are on', () {
      const same = NotificationPreferences(quietStartMinute: 8 * 60, quietEndMinute: 8 * 60);
      expect(QuietHoursRules.check(same), NotificationErrorCodes.quietHoursSame);
      expect(QuietHoursRules.check(same.copyWith(quietHoursEnabled: false)), isNull);
      expect(QuietHoursRules.check(const NotificationPreferences()), isNull);
    });
  });

  group('deep links', () {
    test("the server's links map onto the app's routes", () {
      expect(DeepLinks.locationFor('/matches/3fa85f64'), Routes.matchPath('3fa85f64'));
      expect(DeepLinks.locationFor('/chat/c-1'), Routes.chatPath('c-1'));
      expect(DeepLinks.locationFor('/saved-searches/ss-1'), Routes.savedSearches);
      expect(DeepLinks.locationFor('/availability'), Routes.availability);
      expect(DeepLinks.locationFor('/profile'), Routes.profile);
    });

    test('unknown, empty or malformed links go nowhere; a tapped push then opens the inbox', () {
      for (final link in [null, '', '/', '/admin/reports', '/matches', '/matches/a/b', 'not a link']) {
        expect(DeepLinks.locationFor(link), isNull, reason: '$link');
        expect(DeepLinks.targetFor(link), Routes.notifications, reason: '$link');
      }
      expect(DeepLinks.targetFor('/profile'), Routes.profile);
    });
  });
}
