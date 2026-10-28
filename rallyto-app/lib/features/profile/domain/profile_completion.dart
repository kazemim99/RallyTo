import 'entities/player_profile.dart';

/// A part of the profile that makes it more complete when filled in, in the order the player is nudged to fill them.
enum ProfileCompletionItem { photo, bio, sports, homeVenues }

/// How complete the player's own profile is, worked out from what the profile already holds: the basics (name, city,
/// age, all required to have a profile at all) count as one part done, then a photo, a bio, at least one sport and at
/// least one home club.
class ProfileCompletion {
  const ProfileCompletion._(this.missing);

  factory ProfileCompletion.of(MyProfile profile) {
    final photo = profile.photoUrl;
    final bio = profile.bio;
    return ProfileCompletion._([
      if (photo == null || photo.isEmpty) ProfileCompletionItem.photo,
      if (bio == null || bio.trim().isEmpty) ProfileCompletionItem.bio,
      if (profile.sports.isEmpty) ProfileCompletionItem.sports,
      if (profile.homeVenues.isEmpty) ProfileCompletionItem.homeVenues,
    ]);
  }

  /// The basics and every [ProfileCompletionItem].
  static final int parts = 1 + ProfileCompletionItem.values.length;

  /// What is still missing, in nudging order.
  final List<ProfileCompletionItem> missing;

  bool get isComplete => missing.isEmpty;

  /// From 0.2 (only the basics) to 1.
  double get fraction => (parts - missing.length) / parts;

  /// [fraction] as a whole percentage.
  int get percent => (fraction * 100).round();

  /// The next part to suggest, or null when complete.
  ProfileCompletionItem? get next => missing.isEmpty ? null : missing.first;
}
