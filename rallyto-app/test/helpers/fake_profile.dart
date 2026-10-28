import 'package:dartz/dartz.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/availability/domain/availability_repository.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/profile/domain/profile_repository.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';

/// A [ProfileRepository] answering from what the test set, recording what it was asked.
class FakeProfileRepository implements ProfileRepository {
  MyProfile profile = testMyProfile();

  /// When set, the next call of that kind answers with it instead of succeeding.
  Failure? createFailure;
  Failure? homeVenuesFailure;
  Failure? editFailure;
  Failure? playerFailure;
  Failure? blockFailure;

  /// Runs on each successful block, so a test can make the other fakes forget the blocked player.
  void Function(String userId)? onBlock;

  final List<NewProfile> created = [];
  final List<List<String>> homeVenuesSet = [];
  final List<SportProfileDraft> sportsSet = [];
  final List<String> sportsRemoved = [];
  final List<ProfileVisibility> visibilitySet = [];
  final List<String> blocked = [];
  final List<String> unblocked = [];
  List<BlockedPlayer> blockedPlayers = [
    BlockedPlayer(userId: 'u-9', displayName: 'مزاحم', blockedAt: DateTime.utc(2026, 10, 1)),
  ];
  PlayerProfile player = testPlayerProfile();

  @override
  Future<Either<Failure, MyProfile>> createProfile(NewProfile profile) async {
    created.add(profile);
    final failure = createFailure;
    if (failure != null) return Left(failure);
    return Right(this.profile);
  }

  @override
  Future<Either<Failure, MyProfile>> getMyProfile() async => Right(profile);

  @override
  Future<Either<Failure, MyProfile>> updateProfile({
    required String displayName,
    required Gender gender,
    required int cityId,
    String? bio,
  }) async => _edit();

  @override
  Future<Either<Failure, MyProfile>> setSportProfile(SportProfileDraft sport) async {
    sportsSet.add(sport);
    return _edit();
  }

  @override
  Future<Either<Failure, MyProfile>> removeSportProfile(String sportId) async {
    sportsRemoved.add(sportId);
    return _edit();
  }

  @override
  Future<Either<Failure, MyProfile>> setHomeVenues(List<String> venueIds) async {
    homeVenuesSet.add(venueIds);
    final failure = homeVenuesFailure;
    if (failure != null) return Left(failure);
    return Right(profile);
  }

  @override
  Future<Either<Failure, MyProfile>> setVisibility(ProfileVisibility visibility) async {
    visibilitySet.add(visibility);
    return _edit();
  }

  @override
  Future<Either<Failure, MyProfile>> uploadPhoto(ProfilePhoto photo) async => _edit();

  @override
  Future<Either<Failure, MyProfile>> removePhoto() async => _edit();

  @override
  Future<Either<Failure, PlayerProfile>> getPlayer(String userId) async {
    final failure = playerFailure;
    return failure == null ? Right(player) : Left(failure);
  }

  @override
  Future<Either<Failure, List<BlockedPlayer>>> getBlockedPlayers() async => Right(blockedPlayers);

  @override
  Future<Either<Failure, Unit>> blockPlayer(String userId) async {
    blocked.add(userId);
    final failure = blockFailure;
    if (failure != null) return Left(failure);
    onBlock?.call(userId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> unblockPlayer(String userId) async {
    unblocked.add(userId);
    return const Right(unit);
  }

  Either<Failure, MyProfile> _edit() {
    final failure = editFailure;
    return failure == null ? Right(profile) : Left(failure);
  }
}

/// An [AvailabilityRepository] answering from what the test set, recording what it was asked.
class FakeAvailabilityRepository implements AvailabilityRepository {
  List<AvailabilityWindow> mine = [testWindow(id: 'w-1'), testWindow(id: 'w-2', status: AvailabilityStatus.paused)];
  List<AvailabilityWindow> others = [testWindow(id: 'w-9')];

  /// When set, create and update answer with it.
  Failure? saveFailure;

  final List<AvailabilityDraft> createdDrafts = [];
  final List<(String, AvailabilityDraft)> updatedDrafts = [];
  final List<(String, String)> actions = [];

  @override
  Future<Either<Failure, List<AvailabilityWindow>>> getMine() async => Right(mine);

  @override
  Future<Either<Failure, List<AvailabilityWindow>>> getForPlayer(String userId) async => Right(others);

  @override
  Future<Either<Failure, AvailabilityWindow>> create(AvailabilityDraft draft) async {
    createdDrafts.add(draft);
    final failure = saveFailure;
    return failure == null ? Right(testWindow(id: 'w-new')) : Left(failure);
  }

  @override
  Future<Either<Failure, AvailabilityWindow>> update(String id, AvailabilityDraft draft) async {
    updatedDrafts.add((id, draft));
    final failure = saveFailure;
    return failure == null ? Right(testWindow(id: id)) : Left(failure);
  }

  @override
  Future<Either<Failure, AvailabilityWindow>> pause(String id) async {
    actions.add(('pause', id));
    return Right(testWindow(id: id, status: AvailabilityStatus.paused));
  }

  @override
  Future<Either<Failure, AvailabilityWindow>> resume(String id) async {
    actions.add(('resume', id));
    return Right(testWindow(id: id));
  }

  @override
  Future<Either<Failure, AvailabilityWindow>> confirm(String id) async {
    actions.add(('confirm', id));
    return Right(testWindow(id: id));
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    actions.add(('delete', id));
    return const Right(unit);
  }
}

const SportProfile testTennisProfile = SportProfile(
  sportId: 's-tennis',
  sportCode: 'tennis',
  level: LevelTier.intermediate,
  levelName: 'متوسط',
  levelDescription: 'سرویس و بک‌هند مطمئن دارید',
  experience: ExperienceBand.oneToThreeYears,
  formats: [PlayFormat.singles, PlayFormat.doubles],
  goals: [PlayGoal.friendlyMatch],
);

MyProfile testMyProfile({
  List<SportProfile> sports = const [testTennisProfile],
  ProfileVisibility visibility = ProfileVisibility.everyone,
  String? photoUrl,
  Reputation? reputation,
}) => MyProfile(
  userId: 'u-1',
  displayName: 'سارا',
  gender: Gender.female,
  birthDate: '1375/05/10',
  ageRange: '25-34',
  city: const CityRef(id: 10, name: 'تهران'),
  bio: 'صبح‌های جمعه بازی می‌کنم',
  visibility: visibility,
  status: 'Active',
  photoUrl: photoUrl,
  sports: sports,
  homeVenues: const [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')],
  reputation: reputation,
);

PlayerProfile testPlayerProfile({Reputation? reputation, String? photoUrl}) => PlayerProfile(
  userId: 'u-2',
  displayName: 'علی',
  gender: Gender.male,
  ageRange: '35-44',
  city: CityRef(id: 10, name: 'تهران'),
  bio: 'دنبال هم‌بازی دونفره',
  sports: const [testTennisProfile],
  homeVenues: const [NamedRef(id: 'v-2', name: 'مجموعه آزادی')],
  memberSince: '1405/08',
  lastActive: LastActive.thisWeek,
  reputation: reputation,
  photoUrl: photoUrl,
);

AvailabilityWindow testWindow({
  String id = 'w-1',
  AvailabilityStatus status = AvailabilityStatus.active,
  AvailabilityKind kind = AvailabilityKind.recurring,
  bool needsReconfirmation = false,
  String? pausesOn,
}) => AvailabilityWindow(
  id: id,
  sportId: 's-tennis',
  sportCode: 'tennis',
  venues: const [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')],
  kind: kind,
  weekdays: kind == AvailabilityKind.recurring ? const [Weekday.saturday, Weekday.monday] : const [],
  date: kind == AvailabilityKind.oneOff ? '1405/08/08' : null,
  startTime: '18:00',
  endTime: '20:00',
  formats: const [PlayFormat.singles],
  status: status,
  needsReconfirmation: needsReconfirmation,
  pausesOn: pausesOn,
);
