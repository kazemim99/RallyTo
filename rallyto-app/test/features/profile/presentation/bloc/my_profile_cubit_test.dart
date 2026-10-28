import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/my_profile_cubit.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';

/// The player's own profile: each edit replaces the profile shown and ends in feedback; refusals are said in the
/// server's words.
void main() {
  late FakeProfileRepository profiles;
  late MyProfileCubit cubit;

  setUp(() async {
    profiles = FakeProfileRepository();
    cubit = MyProfileCubit(profiles, FakeCatalogRepository());
    await cubit.load();
  });

  tearDown(() => cubit.close());

  test('loads the profile and the sports to edit it with', () {
    expect(cubit.state.status, ViewStatus.content);
    expect(cubit.state.profile?.displayName, 'سارا');
    expect(cubit.state.sportNames, {'tennis': 'تنیس', 'padel': 'پدل'});
    expect(cubit.state.addableSports.map((s) => s.code), ['padel'], reason: 'tennis is in the profile already');
  });

  test("removing the last sport is refused with LAST_SPORT_PROFILE, said in the server's words", () async {
    const message = 'دست‌کم یک ورزش باید در پروفایل بماند.';
    profiles.editFailure = const ServerFailure(message, code: 'LAST_SPORT_PROFILE', statusCode: 409);

    await cubit.removeSport('s-tennis');

    expect(profiles.sportsRemoved, ['s-tennis']);
    final feedback = cubit.state.feedback!;
    expect(feedback.isError, isTrue);
    expect(feedback.code, 'LAST_SPORT_PROFILE');
    expect(feedback.message, message);
    expect(cubit.state.profile?.sports, hasLength(1), reason: 'the profile shown is unchanged');
    expect(cubit.state.busy, isFalse);
  });

  test('a successful edit replaces the profile and says so', () async {
    profiles.profile = testMyProfile(visibility: ProfileVisibility.sameGender);

    await cubit.setSameGenderOnly(true);

    expect(profiles.visibilitySet, [ProfileVisibility.sameGender]);
    expect(cubit.state.profile?.visibility, ProfileVisibility.sameGender);
    expect(cubit.state.feedback?.message, AppStrings.saved);
    expect(cubit.state.feedback?.isError, isFalse);
  });

  test('a sport is checked before it is sent: padel singles is refused on the device', () async {
    final error = await cubit.saveSport(
      const SportProfileDraft(
        sportId: 's-padel',
        level: LevelTier.beginner,
        experience: ExperienceBand.underSixMonths,
        formats: {PlayFormat.singles},
        goals: {PlayGoal.fitness},
      ),
    );

    expect(error, AppStrings.sportFormatNotAllowed('پدل'));
    expect(profiles.sportsSet, isEmpty);
  });

  test('a complete sport is saved', () async {
    final error = await cubit.saveSport(
      const SportProfileDraft(
        sportId: 's-padel',
        level: LevelTier.beginner,
        experience: ExperienceBand.underSixMonths,
        formats: {PlayFormat.doubles},
        goals: {PlayGoal.fitness},
      ),
    );

    expect(error, isNull);
    expect(profiles.sportsSet.single.sportId, 's-padel');
  });

  test('name, city and bio: an invalid name is refused on the device', () async {
    expect(await cubit.updateBasics(displayName: '!', cityId: 10), AppStrings.displayNameInvalid);
    expect(await cubit.updateBasics(displayName: 'سارا', cityId: 10, bio: 'ب' * 301), AppStrings.bioTooLong);
    expect(await cubit.updateBasics(displayName: 'سارا', cityId: 20, bio: 'سلام'), isNull);
  });
}
