import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/catalog/domain/entities/place.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/onboarding/presentation/bloc/onboarding_cubit.dart';
import 'package:rallyto_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/profile/presentation/widgets/sport_profile_editor.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/memory_secure_storage.dart';

/// The onboarding screens: progress, the notice that gender is set once, the sports step offering only the formats a
/// sport allows, and the server's refusals shown inline.
void main() {
  const tehran = CitySelection(cityId: 10, cityName: 'تهران');
  late OnboardingCubit cubit;

  Future<void> showOnboarding(WidgetTester tester, {FakeProfileRepository? profiles}) async {
    final session = AuthSessionCubit(memoryTokenStorage(MemorySecureStorage(timers: false)));
    addTearDown(session.close);
    cubit = OnboardingCubit(
      profiles ?? FakeProfileRepository(),
      FakeCatalogRepository(),
      session,
      clock: () => DateTime.utc(2026, 10, 23, 8),
    );
    addTearDown(cubit.close);
    await cubit.start();
    await pumpInShell(tester, BlocProvider.value(value: cubit, child: const OnboardingPage()));
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingPage.nextKey));
    await tester.pumpAndSettle();
  }

  testWidgets('the gender step says clearly that gender cannot be changed later', (tester) async {
    await showOnboarding(tester);
    expect(find.text(AppStrings.onboardingProgress('۱', '۶')), findsOneWidget);

    await tester.enterText(find.byKey(OnboardingPage.nameFieldKey), 'سارا');
    await tapNext(tester);

    expect(find.text(AppStrings.onboardingProgress('۲', '۶')), findsOneWidget);
    expect(find.text(AppStrings.genderStepTitle), findsOneWidget);
    final notice = find.byKey(OnboardingPage.genderNoticeKey);
    expect(notice, findsOneWidget);
    expect(find.descendant(of: notice, matching: find.text(AppStrings.genderLockedNotice)), findsOneWidget);
    expect(find.descendant(of: notice, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);

    await tapNext(tester);
    expect(find.text(AppStrings.genderRequired), findsOneWidget, reason: 'a choice is required');

    await tester.tap(find.byKey(OnboardingPage.genderKey(Gender.female)));
    await tester.pumpAndSettle();
    expect(cubit.state.gender, Gender.female);
    expect(tester.getSemantics(find.byKey(OnboardingPage.genderKey(Gender.female))), isSemantics(isSelected: true));
    expect(tester.getSemantics(find.byKey(OnboardingPage.genderKey(Gender.male))), isSemantics(isSelected: false));
    expect(find.text(AppStrings.genderRequired), findsNothing);
  });

  testWidgets('each step has a bold title with a muted line under it, under the step header', (tester) async {
    await showOnboarding(tester);

    expect(find.byType(StepHeader), findsOneWidget);
    expect(find.text(AppStrings.nameStepTitle), findsOneWidget);
    expect(find.text(AppStrings.nameStepHint), findsOneWidget);

    await tester.enterText(find.byKey(OnboardingPage.nameFieldKey), 'سارا');
    await tapNext(tester);
    expect(find.text(AppStrings.onboardingStepHint), findsOneWidget, reason: 'a step without its own hint');
    expect(find.byKey(OnboardingPage.backKey), findsOneWidget);
  });

  testWidgets('the city step shows the province and city chosen in their fields', (tester) async {
    await showOnboarding(tester);
    cubit
      ..displayNameChanged('سارا')
      ..genderSelected(Gender.female)
      ..birthDateChanged(Jalali(1375, 5, 10));
    for (var i = 0; i < 3; i++) {
      await cubit.next();
    }
    await tester.pumpAndSettle();
    expect(cubit.state.step, OnboardingStep.city);

    final province = find.byKey(OnboardingPage.provinceFieldKey);
    final city = find.byKey(OnboardingPage.cityButtonKey);
    expect(find.descendant(of: province, matching: find.text(AppStrings.chooseProvince)), findsOneWidget);
    expect(find.descendant(of: city, matching: find.text(AppStrings.chooseCity)), findsOneWidget);

    await tapNext(tester);
    expect(find.byKey(OnboardingPage.errorKey), findsOneWidget);
    expect(find.text(AppStrings.cityRequired), findsOneWidget);

    cubit.citySelected(const CitySelection(cityId: 11, cityName: 'شهریار', provinceName: 'تهران'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: province, matching: find.text('تهران')), findsOneWidget);
    expect(find.descendant(of: city, matching: find.text('شهریار')), findsOneWidget);
    expect(find.byKey(OnboardingPage.errorKey), findsNothing);
  });

  testWidgets('chosen home clubs show as rows with a check; tapping one takes it off, and «فعلاً نه» skips', (
    tester,
  ) async {
    await showOnboarding(tester);
    cubit
      ..displayNameChanged('سارا')
      ..genderSelected(Gender.female)
      ..birthDateChanged(Jalali(1375, 5, 10))
      ..citySelected(tehran)
      ..toggleSport(tennis());
    cubit.sportChanged(
      cubit.state.drafts.single.copyWith(
        level: LevelTier.beginner,
        experience: ExperienceBand.underSixMonths,
        formats: {PlayFormat.singles},
        goals: {PlayGoal.fitness},
      ),
    );
    for (var i = 0; i < 5; i++) {
      await cubit.next();
    }
    await tester.pumpAndSettle();
    expect(cubit.state.step, OnboardingStep.homeVenues);
    expect(find.byKey(OnboardingPage.skipKey), findsNothing, reason: 'nothing to skip yet');
    expect(find.byKey(OnboardingPage.homeVenuesButtonKey), findsOneWidget);

    cubit.homeVenuesChanged([testVenue(id: 'v-1'), testVenue(id: 'v-2', name: 'مجموعه ورزشی آزادی')]);
    await tester.pumpAndSettle();

    final first = find.byKey(OnboardingPage.homeVenueKey('v-1'));
    expect(find.descendant(of: first, matching: find.text('باشگاه انقلاب')), findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.text('تنیس')),
      findsOneWidget,
      reason: "the club's sports",
    );
    expect(find.descendant(of: first, matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    expect(find.byKey(OnboardingPage.homeVenueKey('v-2')), findsOneWidget);
    expect(find.byKey(OnboardingPage.skipKey), findsOneWidget);

    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(cubit.state.homeVenues.map((v) => v.id), ['v-2']);
    expect(find.byKey(OnboardingPage.homeVenueKey('v-1')), findsNothing);
  });

  testWidgets('an invalid name is said under the field', (tester) async {
    await showOnboarding(tester);

    await tester.enterText(find.byKey(OnboardingPage.nameFieldKey), 'سارا!');
    await tapNext(tester);

    expect(find.text(AppStrings.displayNameInvalid), findsOneWidget);
    expect(cubit.state.step, OnboardingStep.name);
  });

  testWidgets('padel shows only the Doubles chip', (tester) async {
    await showOnboarding(tester);
    cubit
      ..displayNameChanged('سارا')
      ..genderSelected(Gender.female)
      ..birthDateChanged(Jalali(1375, 5, 10))
      ..citySelected(tehran);
    for (var i = 0; i < 4; i++) {
      await cubit.next();
    }
    await tester.pumpAndSettle();
    expect(cubit.state.step, OnboardingStep.sports);

    await tester.tap(find.byKey(OnboardingPage.sportKey('padel')));
    await tester.pumpAndSettle();

    expect(find.byKey(SportProfileEditor.formatKey('padel', PlayFormat.doubles)), findsOneWidget);
    expect(find.byKey(SportProfileEditor.formatKey('padel', PlayFormat.singles)), findsNothing);
  });

  testWidgets('UNDER_18 from the server is shown inline on the birth date step', (tester) async {
    const message = 'برای استفاده از رالیتو باید دست‌کم ۱۸ سال داشته باشید.';
    final profiles = FakeProfileRepository()..createFailure = const ValidationFailure(message, code: 'UNDER_18');
    await showOnboarding(tester, profiles: profiles);
    cubit
      ..displayNameChanged('سارا')
      ..genderSelected(Gender.female)
      ..birthDateChanged(Jalali(1387, 1, 1))
      ..citySelected(tehran)
      ..toggleSport(tennis());
    cubit.sportChanged(
      cubit.state.drafts.single.copyWith(
        level: LevelTier.beginner,
        experience: ExperienceBand.underSixMonths,
        formats: {PlayFormat.singles},
        goals: {PlayGoal.fitness},
      ),
    );

    await cubit.submit();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.birthDateStepTitle), findsOneWidget);
    expect(find.byKey(OnboardingPage.errorKey), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  });
}
