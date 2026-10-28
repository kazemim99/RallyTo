import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/features/profile/domain/entities/player_profile.dart';
import 'package:rallyto_app/features/profile/domain/entities/profile_enums.dart';
import 'package:rallyto_app/features/profile/domain/profile_completion.dart';

import '../../../helpers/fake_profile.dart';

/// How complete the player's own profile is: the basics count as one part of five, then a photo, a bio, a sport and
/// a home club; the next nudge is the first part missing.
void main() {
  MyProfile profile({String? photoUrl, String? bio, bool sports = true, bool homeVenues = true}) => MyProfile(
    userId: 'u-1',
    displayName: 'سارا',
    gender: Gender.female,
    ageRange: '25-34',
    city: const CityRef(id: 10, name: 'تهران'),
    visibility: ProfileVisibility.everyone,
    photoUrl: photoUrl,
    bio: bio,
    sports: sports ? const [testTennisProfile] : const [],
    homeVenues: homeVenues ? const [NamedRef(id: 'v-1', name: 'باشگاه انقلاب')] : const [],
  );

  test('everything filled in: complete, 100%, nothing to suggest', () {
    final completion = ProfileCompletion.of(profile(photoUrl: 'https://x/p.jpg', bio: 'صبح‌ها'));

    expect(completion.isComplete, isTrue);
    expect(completion.percent, 100);
    expect(completion.next, isNull);
  });

  test('only the photo missing: 80%, and the photo is suggested', () {
    final completion = ProfileCompletion.of(profile(bio: 'صبح‌ها'));

    expect(completion.percent, 80);
    expect(completion.missing, [ProfileCompletionItem.photo]);
    expect(completion.next, ProfileCompletionItem.photo);
  });

  test('only the basics: 20%, with every part missing in nudging order', () {
    final completion = ProfileCompletion.of(profile(sports: false, homeVenues: false));

    expect(completion.percent, 20);
    expect(completion.missing, ProfileCompletionItem.values);
  });

  test('a blank bio counts as missing', () {
    final completion = ProfileCompletion.of(profile(photoUrl: 'https://x/p.jpg', bio: '   '));

    expect(completion.next, ProfileCompletionItem.bio);
    expect(completion.percent, 80);
  });

  test('filling a part never lowers the percentage', () {
    final before = ProfileCompletion.of(profile(homeVenues: false));
    final after = ProfileCompletion.of(profile(homeVenues: true));

    expect(after.percent, greaterThan(before.percent));
  });
}
