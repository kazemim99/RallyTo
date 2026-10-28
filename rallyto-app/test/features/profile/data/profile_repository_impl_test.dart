import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/config/api_config.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/data/profile_api.dart';
import 'package:rallyto_app/features/profile/data/profile_repository_impl.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';

import '../../../helpers/fake_server.dart';

/// The profile, player and block calls over the real client stack, against the backend's contract: string enums,
/// Jalali dates in ASCII digits, the error envelope, 204s without a body, multipart photos.
void main() {
  late FakeServer server;
  late ProfileRepositoryImpl repository;

  setUp(() {
    server = FakeServer();
    repository = ProfileRepositoryImpl(ProfileApi(server.dio()));
  });

  T valueOf<T>(Either<Failure, T> result) => result.fold((f) => fail('expected a value, got $f'), (v) => v);
  Failure failureOf<T>(Either<Failure, T> result) => result.fold((f) => f, (_) => fail('expected a failure'));

  const tennisDraft = SportProfileDraft(
    sportId: 's-tennis',
    level: LevelTier.intermediate,
    experience: ExperienceBand.oneToThreeYears,
    formats: {PlayFormat.doubles, PlayFormat.singles},
    goals: {PlayGoal.fitness, PlayGoal.friendlyMatch},
  );

  group('creating the profile', () {
    test('sends the contract shape and reads the 201', () async {
      server.routes['POST /api/v1/profile'] = (_) => okBody(_myProfileJson, status: 201);

      final profile = valueOf(
        await repository.createProfile(
          const NewProfile(
            displayName: 'سارا',
            gender: Gender.female,
            birthDate: '1375/05/10',
            cityId: 10,
            sports: [tennisDraft],
          ),
        ),
      );

      expect(server.lastJson, {
        'displayName': 'سارا',
        'gender': 'Female',
        'birthDate': '1375/05/10',
        'cityId': 10,
        'bio': null,
        'sports': [
          {
            'sportId': 's-tennis',
            'level': 'Intermediate',
            'experience': 'OneToThreeYears',
            'formats': ['Singles', 'Doubles'],
            'goals': ['FriendlyMatch', 'Fitness'],
          },
        ],
      });
      expect(profile.displayName, 'سارا');
      expect(profile.gender, Gender.female);
      expect(profile.city, const CityRef(id: 10, name: 'تهران'));
      expect(profile.visibility, ProfileVisibility.sameGender);
      expect(profile.photoUrl, '${ApiConfig.baseUrl}/media/avatars/x.jpg', reason: 'a path, from the API origin');
      expect(profile.homeVenues.single, const NamedRef(id: 'v-1', name: 'باشگاه انقلاب'));
      final sport = profile.sports.single;
      expect(sport.level, LevelTier.intermediate);
      expect(sport.levelName, 'متوسط');
      expect(sport.formats, [PlayFormat.singles, PlayFormat.doubles]);
      expect(sport.goals, [PlayGoal.friendlyMatch], reason: 'an unknown goal is dropped, not a crash');
    });

    test('UNDER_18 comes back with its code and the server\'s Persian message', () async {
      server.routes['POST /api/v1/profile'] = (_) => errorBody(422, 'UNDER_18', 'باید دست‌کم ۱۸ سال داشته باشید.');

      final failure = failureOf(
        await repository.createProfile(
          const NewProfile(
            displayName: 'سارا',
            gender: Gender.female,
            birthDate: '1390/01/01',
            cityId: 10,
            sports: [tennisDraft],
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'UNDER_18');
      expect(failure.message, 'باید دست‌کم ۱۸ سال داشته باشید.');
    });
  });

  group('editing', () {
    test('the last sport cannot be removed: 409 LAST_SPORT_PROFILE', () async {
      server.routes['DELETE /api/v1/profile/sports/s-tennis'] = (_) =>
          errorBody(409, 'LAST_SPORT_PROFILE', 'دست‌کم یک ورزش باید در پروفایل بماند.');

      final failure = failureOf(await repository.removeSportProfile('s-tennis'));

      expect(failure.code, 'LAST_SPORT_PROFILE');
      expect((failure as ServerFailure).statusCode, 409);
    });

    test('name, city and bio, with the gender that cannot change', () async {
      server.routes['PUT /api/v1/profile'] = (_) => okBody(_myProfileJson);

      await repository.updateProfile(displayName: ' سارا ', gender: Gender.female, cityId: 20, bio: '  ');

      expect(server.lastJson, {'displayName': 'سارا', 'gender': 'Female', 'cityId': 20, 'bio': null});
    });

    test('a sport profile goes to its own path', () async {
      server.routes['PUT /api/v1/profile/sports/s-tennis'] = (_) => okBody(_myProfileJson);

      valueOf(await repository.setSportProfile(tennisDraft));

      expect(server.lastJson['level'], 'Intermediate');
    });

    test('home clubs and visibility', () async {
      server.routes['PUT /api/v1/profile/home-venues'] = (_) => okBody(_myProfileJson);
      server.routes['PUT /api/v1/profile/visibility'] = (_) => okBody(_myProfileJson);

      await repository.setHomeVenues(['v-1', 'v-2']);
      expect(server.lastJson, {
        'venueIds': ['v-1', 'v-2'],
      });

      await repository.setVisibility(ProfileVisibility.sameGender);
      expect(server.lastJson, {'visibility': 'SameGender'});
    });

    test('a photo is sent as the multipart field «file» with its media type', () async {
      server.routes['PUT /api/v1/profile/photo'] = (_) => okBody(_myProfileJson);

      valueOf(await repository.uploadPhoto(const ProfilePhoto(bytes: [1, 2, 3], fileName: 'me.png')));

      final form = server.requests.single.data as FormData;
      final file = form.files.single;
      expect(file.key, 'file');
      expect(file.value.filename, 'me.png');
      expect(file.value.contentType?.mimeType, 'image/png');
      expect(file.value.length, 3);
    });

    test('a photo that is too large is said in the server\'s words', () async {
      server.routes['PUT /api/v1/profile/photo'] = (_) => errorBody(400, 'PHOTO_TOO_LARGE', 'حداکثر ۵ مگابایت');

      final failure = failureOf(await repository.uploadPhoto(const ProfilePhoto(bytes: [1], fileName: 'a.jpg')));

      expect(failure.code, 'PHOTO_TOO_LARGE');
      expect(failure.message, 'حداکثر ۵ مگابایت');
    });
  });

  group('players and blocks', () {
    test("another player's profile, with a coarse last activity and no birth date", () async {
      server.routes['GET /api/v1/players/u-2'] = (_) => okBody(_playerJson);

      final player = valueOf(await repository.getPlayer('u-2'));

      expect(player.ageRange, '35-44');
      expect(player.lastActive, LastActive.thisWeek);
      expect(player.memberSince, '1405/08');
      expect(player.photoUrl, isNull);
    });

    test('blocked, hidden or missing is one and the same 404', () async {
      server.routes['GET /api/v1/players/u-3'] = (_) => errorBody(404, 'PLAYER_NOT_FOUND', 'بازیکن پیدا نشد');

      final failure = failureOf(await repository.getPlayer('u-3'));

      expect(failure, isA<NotFoundFailure>());
      expect(failure.code, 'PLAYER_NOT_FOUND');
    });

    test('the block list, and blocking and unblocking (204, no body)', () async {
      server.routes['GET /api/v1/blocks'] = (_) => okBody([
        {'userId': 'u-9', 'displayName': 'مزاحم', 'blockedAt': '2026-10-01T08:30:00Z'},
      ]);
      server.routes['POST /api/v1/blocks/u-9'] = (_) => noContentBody();
      server.routes['DELETE /api/v1/blocks/u-9'] = (_) => noContentBody();

      final blocks = valueOf(await repository.getBlockedPlayers());
      expect(blocks.single.displayName, 'مزاحم');
      expect(blocks.single.blockedAt, DateTime.utc(2026, 10, 1, 8, 30));

      expect(valueOf(await repository.blockPlayer('u-9')), unit);
      expect(valueOf(await repository.unblockPlayer('u-9')), unit);
      expect(server.calls, ['GET /api/v1/blocks', 'POST /api/v1/blocks/u-9', 'DELETE /api/v1/blocks/u-9']);
    });

    test('a failed block is a failure, not a crash', () async {
      server.routes['POST /api/v1/blocks/u-9'] = (o) =>
          throw DioException.connectionError(requestOptions: o, reason: 'off');

      expect(failureOf(await repository.blockPlayer('u-9')), isA<NetworkFailure>());
    });
  });

  test('before onboarding every endpoint but POST /profile is 403 PROFILE_REQUIRED', () async {
    server.routes['GET /api/v1/profile/me'] = (_) => errorBody(403, 'PROFILE_REQUIRED', 'ابتدا پروفایل بسازید');

    final failure = failureOf(await repository.getMyProfile());

    expect(failure, isA<UnauthorizedFailure>());
    expect(failure.code, 'PROFILE_REQUIRED');
  });
}

const Map<String, Object?> _sportJson = {
  'sportId': 's-tennis',
  'sportCode': 'tennis',
  'level': 'Intermediate',
  'levelName': 'متوسط',
  'levelDescription': 'سرویس مطمئن',
  'experience': 'OneToThreeYears',
  'formats': ['Singles', 'Doubles'],
  'goals': ['FriendlyMatch', 'Unknown'],
};

const Map<String, Object?> _myProfileJson = {
  'userId': 'u-1',
  'displayName': 'سارا',
  'photoUrl': '/media/avatars/x.jpg',
  'gender': 'Female',
  'birthDate': '1375/05/10',
  'ageRange': '25-34',
  'city': {'id': 10, 'name': 'تهران'},
  'bio': null,
  'visibility': 'SameGender',
  'status': 'Active',
  'sports': [_sportJson],
  'homeVenues': [
    {'id': 'v-1', 'name': 'باشگاه انقلاب'},
  ],
};

const Map<String, Object?> _playerJson = {
  'userId': 'u-2',
  'displayName': 'علی',
  'photoUrl': null,
  'gender': 'Male',
  'ageRange': '35-44',
  'city': {'id': 10, 'name': 'تهران'},
  'bio': 'دنبال هم‌بازی',
  'sports': [_sportJson],
  'homeVenues': <Object>[],
  'memberSince': '1405/08',
  'lastActive': 'ThisWeek',
};
