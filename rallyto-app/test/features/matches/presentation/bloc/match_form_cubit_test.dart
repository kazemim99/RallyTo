import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/state_switcher.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/matches/domain/entities/match.dart';
import 'package:rallyto_app/features/matches/domain/match_rules.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_form_cubit.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_matches.dart';
import '../../../../helpers/fake_profile.dart';

/// Creating a play post or a direct invitation: the defaults (the player's sport, its format and session length,
/// their level ± 1), the rules checked on the device, and the server's refusals mapped to their field.
void main() {
  late FakeMatchRepository matches;
  late FakeProfileRepository profiles;
  late FakeCatalogRepository catalog;

  const padelProfile = SportProfile(
    sportId: 's-padel',
    sportCode: 'padel',
    level: LevelTier.beginner,
    levelName: 'مبتدی',
    formats: [PlayFormat.doubles],
  );

  setUp(() {
    matches = FakeMatchRepository();
    profiles = FakeProfileRepository();
    catalog = FakeCatalogRepository();
  });

  Future<MatchFormCubit> open({MatchFormArgs args = const MatchFormArgs.post()}) async {
    final cubit = MatchFormCubit(matches, profiles, catalog, args, clock: () => testNow);
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  /// A valid tennis singles post: باشگاه انقلاب, Saturday 1405/08/02 at 19:00.
  Future<MatchFormCubit> validForm({MatchFormArgs args = const MatchFormArgs.post()}) async {
    final cubit = await open(args: args);
    cubit
      ..venueSelected(testVenue())
      ..dateSelected(Jalali(1405, 8, 2))
      ..startSelected(19 * 60);
    return cubit;
  }

  group('loading', () {
    test("a post starts on the player's sport, its first format, its session length and their level ± 1", () async {
      final cubit = await open();
      final state = cubit.state;

      expect(state.loadStatus, ViewStatus.content);
      expect(state.sports.map((s) => s.code), ['tennis'], reason: 'only sports the player has a profile for');
      expect(state.sportId, 's-tennis');
      expect(state.format, PlayFormat.singles);
      expect(state.durationMinutes, 90);
      expect(state.minLevel, LevelTier.lowerIntermediate);
      expect(state.maxLevel, LevelTier.advanced);
      expect(state.partnerGender, PartnerGender.any);
      expect(state.genderLocked, isFalse);
      expect(state.openSpots, 1);
      expect(state.cityId, 10);
      expect(cubit.dateOptions, hasLength(31));
      expect(cubit.dateOptions.first, Jalali(1405, 8, 1));
    });

    test('a same-gender-only host posts for her own gender only', () async {
      profiles.profile = testMyProfile(visibility: ProfileVisibility.sameGender);

      final cubit = await open();
      cubit.partnerGenderSelected(PartnerGender.any);

      expect(cubit.state.genderLocked, isTrue);
      expect(cubit.state.partnerGender, PartnerGender.female);
    });

    test('without a sport profile there is nothing to post', () async {
      profiles.profile = testMyProfile(sports: const []);

      expect((await open()).state.loadStatus, ViewStatus.empty);
    });

    test('an invitation also offers the open posts with room for the invitee', () async {
      matches.upcoming = [
        testHostedMatch(),
        testMatch(id: 'm-5', status: MatchStatus.confirmed, openSpots: 0, myState: ParticipantState.host),
        testMatch(id: 'm-6', myState: ParticipantState.accepted),
      ];

      final cubit = await open(
        args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2', displayName: 'علی')),
      );

      expect(cubit.isInvitation, isTrue);
      expect(cubit.state.invitee?.displayName, 'علی');
      expect(cubit.state.invitablePosts.map((m) => m.id), ['m-1']);
    });
  });

  group('editing', () {
    test('a new sport resets its format, club, duration, players brought and levels', () async {
      profiles.profile = testMyProfile(sports: const [testTennisProfile, padelProfile]);
      final cubit = await open();
      cubit
        ..venueSelected(testVenue())
        ..formatSelected(PlayFormat.doubles)
        ..playersBroughtSelected(2);

      cubit.sportSelected('s-padel');

      expect(cubit.state.format, PlayFormat.doubles, reason: 'padel is doubles only');
      expect(cubit.state.venue, isNull);
      expect(cubit.state.playersBrought, 0);
      expect(cubit.state.minLevel, LevelTier.beginner);
      expect(cubit.state.maxLevel, LevelTier.lowerIntermediate);
      expect(cubit.state.openSpots, 3);
    });

    test('singles allows bringing nobody; a smaller capacity pulls players brought back', () async {
      final cubit = await open();
      cubit
        ..formatSelected(PlayFormat.doubles)
        ..playersBroughtSelected(2);
      expect(cubit.state.openSpots, 1);

      cubit.formatSelected(PlayFormat.singles);

      expect(cubit.state.maxPlayersBrought, 0);
      expect(cubit.state.playersBrought, 0);
    });

    test('the level range stays ordered', () async {
      final cubit = await open();

      cubit.minLevelSelected(LevelTier.professional);
      expect(cubit.state.maxLevel, LevelTier.professional);
      cubit.maxLevelSelected(LevelTier.beginner);
      expect(cubit.state.minLevel, LevelTier.beginner);
    });
  });

  group('the rules, checked before sending', () {
    test('club and date are required', () async {
      final cubit = await open();

      await cubit.submit();

      expect(cubit.state.fieldErrors[MatchField.venue], AppStrings.venueRequired);
      expect(cubit.state.fieldErrors[MatchField.date], AppStrings.dateRequired);
      expect(matches.posts, isEmpty);
    });

    test('a start at least 30 minutes and at most 30 days ahead', () async {
      final cubit = await validForm();

      cubit
        ..dateSelected(Jalali(1405, 8, 1))
        ..startSelected(11 * 60 + 30);
      expect(cubit.validate()[MatchField.time], AppStrings.startTooSoon);

      cubit
        ..dateSelected(Jalali(1405, 9, 1))
        ..startSelected(23 * 60);
      expect(cubit.validate()[MatchField.time], AppStrings.startTooFar);
    });

    test('a cost note up to 200 and a description up to 500 characters; an invitation message up to 200', () async {
      final post = await validForm();
      post
        ..costNoteChanged('x' * 201)
        ..descriptionChanged('x' * 501);
      expect(post.validate()[MatchField.costNote], AppStrings.costNoteTooLong);
      expect(post.validate()[MatchField.description], AppStrings.descriptionTooLong);

      final invitation = await validForm(args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2')));
      invitation.messageChanged('x' * 201);
      expect(invitation.validate()[MatchField.message], AppStrings.messageTooLong);
    });

    test('changing a field clears its error', () async {
      final cubit = await open();
      await cubit.submit();

      cubit.venueSelected(testVenue());

      expect(cubit.state.fieldErrors.containsKey(MatchField.venue), isFalse);
      expect(cubit.state.fieldErrors.containsKey(MatchField.date), isTrue);
    });
  });

  group('sending', () {
    test('a post sends everything the host chose, and the screen moves on to the saved game', () async {
      final cubit = await validForm();
      cubit
        ..courtBookedChanged(true)
        ..costNoteChanged('نصف نصف')
        ..descriptionChanged('دوستانه');

      await cubit.submit();

      expect(
        matches.posts.single,
        MatchDraft(
          sportId: 's-tennis',
          venueId: 'v-1',
          format: PlayFormat.singles,
          date: Jalali(1405, 8, 2),
          startMinute: 19 * 60,
          durationMinutes: 90,
          playersBrought: 0,
          minLevel: LevelTier.lowerIntermediate,
          maxLevel: LevelTier.advanced,
          partnerGender: PartnerGender.any,
          courtBooked: true,
          costNote: 'نصف نصف',
          description: 'دوستانه',
        ),
      );
      expect(cubit.state.saved, matches.match);
      expect(cubit.state.submitting, isFalse);
    });

    test('an invitation goes to the invitee with the message', () async {
      final cubit = await validForm(args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2')));
      cubit.messageChanged('بیا بازی');

      await cubit.submit();

      final draft = matches.invitations.single;
      expect(draft.invitees, ['u-2']);
      expect(draft.message, 'بیا بازی');
      expect(draft.startMinute, 19 * 60);
      expect(matches.posts, isEmpty);
      expect(cubit.state.saved, isNotNull);
    });

    test('an invitation into an open post', () async {
      matches.upcoming = [testHostedMatch()];
      final cubit = await open(args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2')));

      await cubit.inviteInto(cubit.state.invitablePosts.single);

      expect(matches.calls.last, 'invite:m-1:u-2');
      expect(cubit.state.saved, isNotNull);
    });

    test('an invitation into a post the server refuses says why', () async {
      matches.upcoming = [testHostedMatch()];
      final cubit = await open(args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2')));
      matches.failure = const ServerFailure('x', code: MatchErrorCodes.inviteeDoesNotPlay);

      await cubit.inviteInto(cubit.state.invitablePosts.single);

      expect(cubit.state.serverError, AppStrings.inviteeDoesNotPlay);
      expect(cubit.state.saved, isNull);
    });

    const fieldCases = {
      MatchErrorCodes.noSportProfile: (MatchField.sport, AppStrings.noSportProfileForMatch),
      MatchErrorCodes.unknownSport: (MatchField.sport, AppStrings.unknownSport),
      MatchErrorCodes.formatNotAllowed: (MatchField.format, AppStrings.formatNotAllowed),
      MatchErrorCodes.unknownVenue: (MatchField.venue, AppStrings.unknownVenue),
      MatchErrorCodes.venueDoesNotOfferSport: (MatchField.venue, AppStrings.venueDoesNotOfferSport),
      MatchErrorCodes.invalidDate: (MatchField.date, AppStrings.invalidDate),
      MatchErrorCodes.invalidTime: (MatchField.time, AppStrings.invalidTime),
      MatchErrorCodes.startTooSoon: (MatchField.time, AppStrings.startTooSoon),
      MatchErrorCodes.startTooFar: (MatchField.time, AppStrings.startTooFar),
      MatchErrorCodes.invalidDuration: (MatchField.duration, AppStrings.invalidDuration),
      MatchErrorCodes.invalidPlayersBrought: (MatchField.playersBrought, AppStrings.invalidPlayersBrought),
      MatchErrorCodes.costNoteTooLong: (MatchField.costNote, AppStrings.costNoteTooLong),
      MatchErrorCodes.descriptionTooLong: (MatchField.description, AppStrings.descriptionTooLong),
    };

    for (final MapEntry(key: code, value: (field, message)) in fieldCases.entries) {
      test('$code is shown on its field', () async {
        final cubit = await validForm();
        matches.failure = ServerFailure('server words', code: code);

        await cubit.submit();

        expect(cubit.state.fieldErrors, {field: message});
        expect(cubit.state.serverError, message);
        expect(cubit.state.saved, isNull);
      });
    }

    const wholeCases = {
      MatchErrorCodes.tooManyOpenPosts: AppStrings.tooManyOpenPosts,
      MatchErrorCodes.playerNotFound: AppStrings.playerNotFound,
      MatchErrorCodes.inviteeDoesNotPlay: AppStrings.inviteeDoesNotPlay,
      MatchErrorCodes.tooManyRequests: AppStrings.tooManyRequestsError,
    };

    for (final MapEntry(key: code, value: message) in wholeCases.entries) {
      test('$code is about the whole game', () async {
        final cubit = await validForm(args: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2')));
        matches.failure = ServerFailure('server words', code: code);

        await cubit.submit();

        expect(cubit.state.fieldErrors, isEmpty);
        expect(cubit.state.serverError, message);
      });
    }

    test('offline is said as such', () async {
      final cubit = await validForm();
      matches.failure = const NetworkFailure(AppStrings.offlineActionError);

      await cubit.submit();

      expect(cubit.state.serverError, AppStrings.offlineActionError);
    });
  });

  test('a profile that cannot be loaded is an error to retry', () async {
    final failing = _FailingProfiles();
    final cubit = MatchFormCubit(matches, failing, catalog, const MatchFormArgs.post(), clock: () => testNow);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.loadStatus, ViewStatus.error);
    expect(cubit.state.loadError, AppStrings.offlineActionError);
  });
}

class _FailingProfiles extends FakeProfileRepository {
  @override
  Future<Either<Failure, MyProfile>> getMyProfile() async => const Left(NetworkFailure(AppStrings.offlineActionError));
}
