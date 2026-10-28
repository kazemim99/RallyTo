import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/availability/data/availability_api.dart';
import 'package:rallyto_app/features/availability/data/availability_repository_impl.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';

import '../../../helpers/fake_server.dart';

/// The availability calls over the real client stack, against the backend's contract: string enums, Saturday-first
/// weekdays, «HH:mm» times with «24:00», Jalali dates in ASCII digits, and only the members of the window's kind.
void main() {
  late FakeServer server;
  late AvailabilityRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = AvailabilityRepositoryImpl(AvailabilityApi(server.dio()));
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  test('reads my windows: enums, weekdays in Iranian order, venues and dates', () async {
    server.routes['GET /api/v1/availability'] = (_) => okBody([_recurringJson, _oneOffJson]);

    final windows = valueOf(await repository.getMine());

    final recurring = windows.first;
    expect(recurring.kind, AvailabilityKind.recurring);
    expect(recurring.weekdays, [Weekday.saturday, Weekday.monday], reason: 'Saturday first, whatever the order sent');
    expect(recurring.venues, const [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')]);
    expect(recurring.startTime, '22:30');
    expect(recurring.endTime, '24:00');
    expect(recurring.status, AvailabilityStatus.active);
    expect(recurring.validUntil, '1405/12/29');
    final oneOff = windows.last;
    expect(oneOff.kind, AvailabilityKind.oneOff);
    expect(oneOff.date, '1405/08/08');
    expect(oneOff.status, AvailabilityStatus.paused);
    expect(oneOff.formats, [PlayFormat.doubles]);
    expect(oneOff.note, isNull, reason: 'a blank note is no note');
  });

  test('reads whether a weekly window needs reconfirming and the day it pauses itself', () async {
    server.routes['GET /api/v1/availability'] = (_) => okBody([_recurringJson, _oneOffJson]);

    final windows = valueOf(await repository.getMine());

    expect(windows.first.needsReconfirmation, isTrue);
    expect(windows.first.pausesOn, '1405/08/30');
    expect(windows.last.needsReconfirmation, isFalse, reason: 'absent reads as false');
    expect(windows.last.pausesOn, isNull);
  });

  test("another player's active windows", () async {
    server.routes['GET /api/v1/players/u-2/availability'] = (_) => okBody([_recurringJson]);

    expect(valueOf(await repository.getForPlayer('u-2')), hasLength(1));
  });

  test('a recurring window sends its weekdays (Saturday first) and validUntil, and no date', () async {
    server.routes['POST /api/v1/availability'] = (_) => okBody(_recurringJson, status: 201);

    final window = valueOf(
      await repository.create(
        AvailabilityDraft(
          sportId: 's-tennis',
          venueIds: const ['v-1', 'v-2'],
          kind: AvailabilityKind.recurring,
          weekdays: const {Weekday.monday, Weekday.saturday},
          date: Jalali(1405, 8, 8),
          startMinute: 22 * 60 + 30,
          endMinute: 24 * 60,
          formats: const {PlayFormat.doubles, PlayFormat.singles},
          note: '  ',
          validUntil: Jalali(1405, 12, 29),
        ),
      ),
    );

    expect(server.lastJson, {
      'sportId': 's-tennis',
      'venueIds': ['v-1', 'v-2'],
      'kind': 'Recurring',
      'weekdays': ['Saturday', 'Monday'],
      'startTime': '22:30',
      'endTime': '24:00',
      'formats': ['Singles', 'Doubles'],
      'validUntil': '1405/12/29',
    });
    expect(window.id, 'w-1');
  });

  test('a one-off window sends its date, and no weekdays or validUntil', () async {
    server.routes['POST /api/v1/availability'] = (_) => okBody(_oneOffJson, status: 201);

    await repository.create(
      AvailabilityDraft(
        sportId: 's-padel',
        venueIds: const ['v-2'],
        kind: AvailabilityKind.oneOff,
        weekdays: const {Weekday.friday},
        date: Jalali(1405, 8, 8),
        startMinute: 9 * 60,
        endMinute: 10 * 60 + 30,
        formats: const {PlayFormat.doubles},
        note: 'بعد از کار',
        validUntil: Jalali(1405, 12, 29),
      ),
    );

    expect(server.lastJson, {
      'sportId': 's-padel',
      'venueIds': ['v-2'],
      'kind': 'OneOff',
      'date': '1405/08/08',
      'startTime': '09:00',
      'endTime': '10:30',
      'formats': ['Doubles'],
      'note': 'بعد از کار',
    });
  });

  test("an overlapping window is a 409 with the server's code and words", () async {
    server.routes['POST /api/v1/availability'] = (_) =>
        errorBody(409, 'OVERLAPPING_WINDOW', 'این بازه با زمان آزاد دیگرتان هم‌پوشانی دارد.');

    final failure = failureOf(
      await repository.create(
        const AvailabilityDraft(
          sportId: 's-tennis',
          venueIds: ['v-1'],
          kind: AvailabilityKind.recurring,
          weekdays: {Weekday.saturday},
          startMinute: 18 * 60,
          endMinute: 20 * 60,
          formats: {PlayFormat.singles},
        ),
      ),
    );

    expect(failure.code, 'OVERLAPPING_WINDOW');
    expect(failure.message, 'این بازه با زمان آزاد دیگرتان هم‌پوشانی دارد.');
    expect((failure as ServerFailure).statusCode, 409);
  });

  test('edit, pause, resume, confirm and delete go to their own paths', () async {
    server.routes['PUT /api/v1/availability/w-1'] = (_) => okBody(_recurringJson);
    server.routes['POST /api/v1/availability/w-1/pause'] = (_) => okBody({..._recurringJson, 'status': 'Paused'});
    server.routes['POST /api/v1/availability/w-1/resume'] = (_) => okBody(_recurringJson);
    server.routes['POST /api/v1/availability/w-1/confirm'] = (_) => okBody(_recurringJson);
    server.routes['DELETE /api/v1/availability/w-1'] = (_) => noContentBody();

    await repository.update(
      'w-1',
      const AvailabilityDraft(
        sportId: 's-tennis',
        venueIds: ['v-1'],
        kind: AvailabilityKind.recurring,
        weekdays: {Weekday.saturday},
        startMinute: 18 * 60,
        endMinute: 20 * 60,
        formats: {PlayFormat.singles},
      ),
    );
    expect(valueOf(await repository.pause('w-1')).status, AvailabilityStatus.paused);
    await repository.resume('w-1');
    await repository.confirm('w-1');
    expect(valueOf(await repository.delete('w-1')), unit);

    expect(server.calls, [
      'PUT /api/v1/availability/w-1',
      'POST /api/v1/availability/w-1/pause',
      'POST /api/v1/availability/w-1/resume',
      'POST /api/v1/availability/w-1/confirm',
      'DELETE /api/v1/availability/w-1',
    ]);
  });
}

const Map<String, Object?> _recurringJson = {
  'id': 'w-1',
  'sportId': 's-tennis',
  'sportCode': 'tennis',
  'venues': [
    {'id': 'v-1', 'name': 'باشگاه انقلاب'},
  ],
  'kind': 'Recurring',
  'weekdays': ['Monday', 'Saturday'],
  'date': null,
  'startTime': '22:30',
  'endTime': '24:00',
  'formats': ['Singles'],
  'note': 'فقط تمرینی',
  'status': 'Active',
  'validUntil': '1405/12/29',
  'needsReconfirmation': true,
  'pausesOn': '1405/08/30',
};

const Map<String, Object?> _oneOffJson = {
  'id': 'w-2',
  'sportId': 's-padel',
  'sportCode': 'padel',
  'venues': [
    {'id': 'v-2', 'name': 'مجموعه آزادی'},
  ],
  'kind': 'OneOff',
  'weekdays': <Object>[],
  'date': '1405/08/08',
  'startTime': '09:00',
  'endTime': '10:30',
  'formats': ['Doubles'],
  'note': ' ',
  'status': 'Paused',
  'validUntil': null,
};
