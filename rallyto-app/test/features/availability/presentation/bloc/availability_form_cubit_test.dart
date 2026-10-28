import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/availability/domain/availability_rules.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/availability/presentation/bloc/availability_form_cubit.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';

/// The window form mirrors the server's rules (30-minute steps, at least 60 minutes, no crossing midnight, a one-off
/// date today to 60 days ahead) and shows what the server still refuses in its words.
void main() {
  group('the rules, as the server checks them', () {
    int at(int hour, [int minute = 0]) => hour * 60 + minute;

    test('times on the 30-minute grid, at least 60 minutes, ending by 24:00, never crossing midnight', () {
      expect(AvailabilityRules.checkTime(at(18), at(20)), isNull);
      expect(AvailabilityRules.checkTime(at(22, 30), at(24)), isNull, reason: '24:00 is a valid end');
      expect(AvailabilityRules.checkTime(at(18), at(18, 30)), AvailabilityErrorCodes.windowTooShort);
      expect(AvailabilityRules.checkTime(at(18, 15), at(20)), AvailabilityErrorCodes.invalidTimeStep);
      expect(AvailabilityRules.checkTime(at(18), at(19, 45)), AvailabilityErrorCodes.invalidTimeStep);
      expect(AvailabilityRules.checkTime(at(23), at(1)), AvailabilityErrorCodes.windowCrossesMidnight);
      expect(AvailabilityRules.checkTime(at(20), at(20)), AvailabilityErrorCodes.windowCrossesMidnight);
      expect(AvailabilityRules.checkTime(at(24), at(24)), AvailabilityErrorCodes.invalidTime, reason: 'no 24:00 start');
      expect(AvailabilityRules.checkTime(at(10), at(24, 30)), AvailabilityErrorCodes.invalidTime);
    });

    test('the selectors offer 00:00–23:30 to start and 00:30–24:00 to end', () {
      expect(AvailabilityRules.startOptions.first, 0);
      expect(AvailabilityRules.startOptions.last, at(23, 30));
      expect(AvailabilityRules.endOptions.first, 30);
      expect(AvailabilityRules.endOptions.last, at(24));
      expect(TimeOfDayText.toApi(at(24)), '24:00');
      expect(TimeOfDayText.tryParse('۲۴:۰۰'), at(24));
      expect(TimeOfDayText.tryParse('24:30'), isNull);
    });

    test('a one-off date is today to 60 days ahead, and not already over', () {
      final today = Jalali(1405, 8, 1);
      String? check(Jalali date, {int end = 20 * 60, int now = 12 * 60}) =>
          AvailabilityRules.checkDate(date, end, today: today, nowMinute: now);

      expect(check(today), isNull);
      expect(check(today.addDays(60)), isNull);
      expect(check(today.addDays(61)), AvailabilityErrorCodes.dateTooFar);
      expect(check(today.addDays(-1)), AvailabilityErrorCodes.windowInPast);
      expect(check(today, end: 12 * 60), AvailabilityErrorCodes.windowInPast, reason: 'today, already over');
    });
  });

  group('the form', () {
    // 1 Aban 1405, 11:30 in Tehran.
    final now = DateTime.utc(2026, 10, 23, 8);
    late FakeAvailabilityRepository availability;
    late FakeProfileRepository profiles;
    late FakeCatalogRepository catalog;

    setUp(() {
      availability = FakeAvailabilityRepository();
      profiles = FakeProfileRepository();
      catalog = FakeCatalogRepository();
    });

    Future<AvailabilityFormCubit> openForm({AvailabilityWindow? existing}) async {
      final cubit = AvailabilityFormCubit(availability, profiles, catalog, existing, clock: () => now);
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    /// A valid recurring window: tennis, Saturdays, 18:00–20:00, one club, singles.
    Future<AvailabilityFormCubit> validForm() async {
      final cubit = await openForm();
      cubit
        ..weekdayToggled(Weekday.saturday)
        ..venuesChanged([testVenues.first])
        ..formatToggled(PlayFormat.singles);
      return cubit;
    }

    test('offers only the sports in the player\'s profile; one sport is chosen for them', () async {
      final cubit = await openForm();

      expect(cubit.state.loadStatus, ViewStatus.content);
      expect(cubit.state.sports.map((s) => s.code), ['tennis']);
      expect(cubit.state.sportId, 's-tennis');
      expect(cubit.state.cityId, 10, reason: "clubs are searched in the player's city");
    });

    test('without any sport profile there is nothing to offer', () async {
      profiles.profile = testMyProfile(sports: const []);
      final cubit = await openForm();

      expect(cubit.state.loadStatus, ViewStatus.empty);
    });

    test('padel starts with Doubles, the only format it allows', () async {
      profiles.profile = testMyProfile(
        sports: const [
          testTennisProfile,
          SportProfile(sportId: 's-padel', sportCode: 'padel', level: LevelTier.beginner, levelName: 'مبتدی'),
        ],
      );
      final cubit = await openForm();

      cubit.sportSelected('s-padel');

      expect(cubit.state.formats, {PlayFormat.doubles});
    });

    test('a window shorter than 60 minutes is refused before sending', () async {
      final cubit = await validForm();
      cubit
        ..startSelected(18 * 60)
        ..endSelected(18 * 60 + 30);

      await cubit.submit();

      expect(cubit.state.fieldErrors[AvailabilityField.time], AppStrings.windowTooShort);
      expect(availability.createdDrafts, isEmpty);
    });

    test('a time off the 30-minute grid is refused', () async {
      final cubit = await validForm();
      cubit.startSelected(18 * 60 + 10);

      await cubit.submit();

      expect(cubit.state.fieldErrors[AvailabilityField.time], AppStrings.invalidTimeStep);
      expect(availability.createdDrafts, isEmpty);
    });

    test('a window crossing midnight is refused, with the advice to split it', () async {
      final cubit = await validForm();
      cubit
        ..startSelected(23 * 60)
        ..endSelected(60);

      await cubit.submit();

      expect(cubit.state.fieldErrors[AvailabilityField.time], AppStrings.windowCrossesMidnight);
      expect(availability.createdDrafts, isEmpty);
    });

    test('22:30–24:00 is sent, ending at «24:00»', () async {
      final cubit = await validForm();
      cubit
        ..startSelected(22 * 60 + 30)
        ..endSelected(24 * 60);

      await cubit.submit();

      expect(cubit.state.fieldErrors, isEmpty);
      expect(availability.createdDrafts.single.endMinute, 24 * 60);
      expect(cubit.state.saved?.id, 'w-new');
    });

    test('everything missing is marked at once', () async {
      profiles.profile = testMyProfile(
        sports: const [
          testTennisProfile,
          SportProfile(sportId: 's-padel', sportCode: 'padel', level: LevelTier.beginner, levelName: 'مبتدی'),
        ],
      );
      final cubit = await openForm();

      await cubit.submit();

      expect(cubit.state.fieldErrors.keys, {
        AvailabilityField.sport,
        AvailabilityField.weekdays,
        AvailabilityField.venues,
        AvailabilityField.formats,
      });
    });

    test('a one-off window needs a date within 60 days', () async {
      final cubit = await validForm();
      cubit.kindSelected(AvailabilityKind.oneOff);

      await cubit.submit();
      expect(cubit.state.fieldErrors[AvailabilityField.date], AppStrings.dateRequired);

      cubit.dateSelected(Jalali(1405, 8, 1).addDays(61));
      await cubit.submit();
      expect(cubit.state.fieldErrors[AvailabilityField.date], AppStrings.dateTooFar);

      cubit.dateSelected(Jalali(1405, 8, 8));
      await cubit.submit();
      expect(cubit.state.fieldErrors, isEmpty);
      final sent = availability.createdDrafts.single;
      expect(sent.kind, AvailabilityKind.oneOff);
      expect(sent.date, Jalali(1405, 8, 8));
    });

    test("the server's overlap conflict is shown in its words, and the form stays open", () async {
      const message = 'این بازه با یکی از زمان‌های آزاد دیگرتان هم‌پوشانی دارد.';
      availability.saveFailure = const ServerFailure(message, code: 'OVERLAPPING_WINDOW', statusCode: 409);
      final cubit = await validForm();

      await cubit.submit();

      expect(availability.createdDrafts, hasLength(1));
      expect(cubit.state.serverError, message);
      expect(cubit.state.saved, isNull);
      expect(cubit.state.submitting, isFalse);
    });

    test('a rule the server refuses is shown on the field it is about', () async {
      availability.saveFailure = const ValidationFailure(
        'باشگاه این ورزش را ندارد',
        code: 'VENUE_DOES_NOT_OFFER_SPORT',
      );
      final cubit = await validForm();

      await cubit.submit();

      expect(cubit.state.fieldErrors[AvailabilityField.venues], 'باشگاه این ورزش را ندارد');
    });

    test('editing starts from the window and updates it', () async {
      final cubit = await openForm(existing: testWindow(id: 'w-1'));

      expect(cubit.state.weekdays, {Weekday.saturday, Weekday.monday});
      expect(cubit.state.startMinute, 18 * 60);
      expect(cubit.state.venues.single.id, 'v-1');

      cubit.endSelected(21 * 60);
      await cubit.submit();

      final (id, draft) = availability.updatedDrafts.single;
      expect(id, 'w-1');
      expect(draft.endMinute, 21 * 60);
      expect(cubit.state.saved?.id, 'w-1');
    });

    test('a profile that cannot be loaded is an error with retry', () async {
      final failing = _FailingProfiles();
      final cubit = AvailabilityFormCubit(availability, failing, catalog, null, clock: () => now);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loadStatus, ViewStatus.error);
      expect(cubit.state.loadError, AppStrings.offlineActionError);
    });
  });
}

class _FailingProfiles extends FakeProfileRepository {
  @override
  Future<Either<Failure, MyProfile>> getMyProfile() async => const Left(NetworkFailure(AppStrings.offlineActionError));
}
