import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/auth_state.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/entities/place.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/onboarding/presentation/bloc/onboarding_cubit.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/profile/domain/sport_rules.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// Onboarding: each step is checked before moving on; the server's refusals land on the step they are about; a 201
/// tells the session, which takes the router home.
void main() {
  // 1 Aban 1405, 11:30 in Tehran.
  final now = DateTime.utc(2026, 10, 23, 8);
  late FakeProfileRepository profiles;
  late FakeCatalogRepository catalog;
  late TokenStorage tokens;
  late AuthSessionCubit session;
  late OnboardingCubit cubit;

  setUp(() async {
    profiles = FakeProfileRepository();
    catalog = FakeCatalogRepository();
    tokens = memoryTokenStorage();
    session = AuthSessionCubit(tokens);
    await session.signIn(testSession(profileCompleted: false));
    cubit = OnboardingCubit(profiles, catalog, session, clock: () => now);
    await cubit.start();
  });

  tearDown(() async {
    await cubit.close();
    await session.close();
  });

  /// Fills every step with valid answers, ending on the home-clubs step.
  Future<void> fillAll() async {
    cubit.displayNameChanged('سارا ۱۳۷۵');
    await cubit.next();
    cubit.genderSelected(Gender.female);
    await cubit.next();
    cubit.birthDateChanged(Jalali(1375, 5, 10));
    await cubit.next();
    cubit.citySelected(const CitySelection(cityId: 10, cityName: 'تهران'));
    await cubit.next();
    cubit.toggleSport(tennis());
    cubit.sportChanged(
      cubit.state.drafts.single.copyWith(
        level: LevelTier.intermediate,
        experience: ExperienceBand.oneToThreeYears,
        formats: {PlayFormat.singles},
        goals: {PlayGoal.friendlyMatch},
      ),
    );
    await cubit.next();
  }

  test('loads the active sports to choose from', () {
    expect(cubit.state.sports.map((s) => s.code), ['tennis', 'padel']);
  });

  group('step validation', () {
    test('a display name of letters, digits, spaces and ZWNJ, 2–30 long', () {
      expect(OnboardingCubit.validateDisplayName(''), AppStrings.displayNameRequired);
      expect(OnboardingCubit.validateDisplayName('س'), AppStrings.displayNameInvalid);
      expect(OnboardingCubit.validateDisplayName('سارا!'), AppStrings.displayNameInvalid);
      expect(OnboardingCubit.validateDisplayName('س' * 31), AppStrings.displayNameInvalid);
      expect(OnboardingCubit.validateDisplayName('مهدی‌رضا ۲'), isNull, reason: 'ZWNJ and Persian digits');
      expect(OnboardingCubit.validateDisplayName('  Ali 7  '), isNull, reason: 'trimmed');
    });

    test('an invalid name stays on the first step, with its message', () async {
      cubit.displayNameChanged('!');
      await cubit.next();

      expect(cubit.state.step, OnboardingStep.name);
      expect(cubit.state.error, AppStrings.displayNameInvalid);

      cubit.displayNameChanged('سارا');
      expect(cubit.state.error, isNull, reason: 'the message follows the typing');
      await cubit.next();
      expect(cubit.state.step, OnboardingStep.gender);
    });

    test('gender is required', () async {
      cubit.displayNameChanged('سارا');
      await cubit.next();
      await cubit.next();

      expect(cubit.state.step, OnboardingStep.gender);
      expect(cubit.state.error, AppStrings.genderRequired);
    });

    test('the birth date must make the player 18 or older on Tehran\'s today', () {
      final today = Jalali(1405, 8, 1);
      expect(OnboardingCubit.validateBirthDate(null, today), AppStrings.birthDateRequired);
      expect(
        OnboardingCubit.validateBirthDate(Jalali(1387, 8, 2), today),
        AppStrings.under18,
        reason: '17, a day short',
      );
      expect(OnboardingCubit.validateBirthDate(Jalali(1387, 8, 1), today), isNull, reason: '18 today');
      expect(OnboardingCubit.validateBirthDate(Jalali(1360, 1, 1), today), isNull);
    });

    test('city is required', () {
      expect(cubit.validateStep(OnboardingStep.city), AppStrings.cityRequired);
      cubit.citySelected(const CitySelection(cityId: 10, cityName: 'تهران'));
      expect(cubit.validateStep(OnboardingStep.city), isNull);
    });

    test('at least one sport, each with level, experience, a format and a goal', () {
      expect(cubit.validateStep(OnboardingStep.sports), AppStrings.sportsRequired);

      cubit.toggleSport(tennis());
      expect(cubit.validateStep(OnboardingStep.sports), AppStrings.sportLevelRequired('تنیس'));

      final draft = cubit.state.drafts.single;
      cubit.sportChanged(draft.copyWith(level: LevelTier.beginner));
      expect(cubit.validateStep(OnboardingStep.sports), AppStrings.sportExperienceRequired('تنیس'));

      cubit.sportChanged(cubit.state.drafts.single.copyWith(experience: ExperienceBand.underSixMonths));
      expect(cubit.validateStep(OnboardingStep.sports), AppStrings.sportFormatRequired('تنیس'));

      cubit.sportChanged(cubit.state.drafts.single.copyWith(formats: {PlayFormat.doubles}));
      expect(cubit.validateStep(OnboardingStep.sports), AppStrings.sportGoalRequired('تنیس'));

      cubit.sportChanged(cubit.state.drafts.single.copyWith(goals: {PlayGoal.fitness}));
      expect(cubit.validateStep(OnboardingStep.sports), isNull);
    });

    test('padel offers only Doubles, chosen from the start; singles is refused', () {
      expect(SportRules.allowedFormats(padel()), [PlayFormat.doubles]);

      cubit.toggleSport(padel());
      final draft = cubit.state.drafts.single;
      expect(draft.formats, {PlayFormat.doubles});

      cubit.sportChanged(
        draft.copyWith(
          level: LevelTier.beginner,
          experience: ExperienceBand.underSixMonths,
          formats: {PlayFormat.singles, PlayFormat.doubles},
          goals: {PlayGoal.fitness},
        ),
      );
      expect(cubit.validateStep(OnboardingStep.sports), AppStrings.sportFormatNotAllowed('پدل'));
    });

    test('squash offers only Singles; tennis both', () {
      final squash = Sport(
        id: 's-squash',
        code: 'squash',
        nameFa: 'اسکواش',
        nameEn: 'Squash',
        sortOrder: 4,
        isActive: true,
        defaultSessionMinutes: 60,
        formats: tennis().formats,
      );
      expect(SportRules.allowedFormats(squash), [PlayFormat.singles], reason: 'the rule wins over the catalog');
      expect(SportRules.allowedFormats(tennis()), [PlayFormat.singles, PlayFormat.doubles]);
    });

    test('back keeps the answers', () async {
      cubit.displayNameChanged('سارا');
      await cubit.next();
      cubit.back();

      expect(cubit.state.step, OnboardingStep.name);
      expect(cubit.state.displayName, 'سارا');
    });
  });

  group('submitting', () {
    test('creates the profile, saves the home clubs, then the session says the profile is complete', () async {
      await fillAll();
      expect(cubit.state.step, OnboardingStep.homeVenues);
      cubit.homeVenuesChanged([testVenues[0], testVenues[1]]);

      await cubit.next();

      final sent = profiles.created.single;
      expect(sent.displayName, 'سارا ۱۳۷۵');
      expect(sent.gender, Gender.female);
      expect(sent.birthDate, '1375/05/10', reason: 'Jalali, ASCII digits');
      expect(sent.cityId, 10);
      expect(sent.sports.single.formats, {PlayFormat.singles});
      expect(profiles.homeVenuesSet.single, ['v-1', 'v-2']);
      expect(cubit.state.status, OnboardingStatus.completed);
      expect(session.state, const Authenticated(profileCompleted: true, roles: ['Player']));
      expect((await tokens.readSession())?.profileCompleted, isTrue, reason: 'the next start opens on home');
    });

    test('without home clubs, nothing is sent for them', () async {
      await fillAll();
      await cubit.next();

      expect(profiles.homeVenuesSet, isEmpty);
      expect(cubit.state.status, OnboardingStatus.completed);
    });

    test("UNDER_18 from the server goes back to the birth date step, in the server's words", () async {
      const message = 'برای استفاده از رالیتو باید دست‌کم ۱۸ سال داشته باشید.';
      profiles.createFailure = const ValidationFailure(message, code: 'UNDER_18');
      await fillAll();

      await cubit.next();

      expect(cubit.state.step, OnboardingStep.birthDate);
      expect(cubit.state.error, message);
      expect(cubit.state.status, OnboardingStatus.editing);
      expect(session.state, const Authenticated(profileCompleted: false, roles: ['Player']));
    });

    test('FORMAT_NOT_ALLOWED goes back to the sports step', () async {
      profiles.createFailure = const ValidationFailure('قالب مجاز نیست', code: 'FORMAT_NOT_ALLOWED');
      await fillAll();

      await cubit.next();

      expect(cubit.state.step, OnboardingStep.sports);
      expect(cubit.state.error, 'قالب مجاز نیست');
    });

    test('an offline failure stays on the last step and can be retried', () async {
      profiles.createFailure = const NetworkFailure(AppStrings.offlineActionError);
      await fillAll();

      await cubit.next();
      expect(cubit.state.step, OnboardingStep.homeVenues);
      expect(cubit.state.error, AppStrings.offlineActionError);

      profiles.createFailure = null;
      await cubit.next();
      expect(cubit.state.status, OnboardingStatus.completed);
    });

    test('home clubs refused after the 201: a retry does not create the profile again; skipping finishes', () async {
      profiles.homeVenuesFailure = const ServerFailure('خطای سرور');
      await fillAll();
      cubit.homeVenuesChanged([testVenues[0]]);

      await cubit.next();
      expect(cubit.state.profileCreated, isTrue);
      expect(cubit.state.status, OnboardingStatus.editing);
      expect(cubit.state.error, contains('خطای سرور'));

      await cubit.next();
      expect(profiles.created, hasLength(1), reason: 'the profile exists already');
      expect(profiles.homeVenuesSet, hasLength(2));

      await cubit.skipHomeVenues();
      expect(cubit.state.status, OnboardingStatus.completed);
      expect(session.state, const Authenticated(profileCompleted: true, roles: ['Player']));
    });

    test('PROFILE_EXISTS (an earlier answer that was lost) counts as created', () async {
      profiles.createFailure = const ServerFailure('پروفایل وجود دارد', code: 'PROFILE_EXISTS', statusCode: 409);
      await fillAll();

      await cubit.next();

      expect(cubit.state.status, OnboardingStatus.completed);
    });

    test('a step left invalid is where submitting stops', () async {
      await fillAll();
      cubit.sportChanged(cubit.state.drafts.single.copyWith(goals: const {}));

      await cubit.submit();

      expect(profiles.created, isEmpty);
      expect(cubit.state.step, OnboardingStep.sports);
      expect(cubit.state.error, AppStrings.sportGoalRequired('تنیس'));
    });
  });
}
