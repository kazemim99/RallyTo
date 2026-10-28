import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/player_profile.dart';
import '../profile_labels.dart';

/// A player's photo in a circle, or the first letter of their name when there is none (or it cannot be loaded).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.photoUrl, this.radius = 40});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
    final url = photoUrl;
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// The design's `.profile-hero`: a large avatar, the name, muted facts under it and a status badge, all centred.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, required this.avatar, required this.name, this.lines = const [], this.badge});

  final Widget avatar;
  final String name;

  /// Muted lines under the name: «۲۵ تا ۳۴ سال • تهران • امروز فعال بوده», «عضو از آبان ۱۴۰۵».
  final List<String> lines;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          avatar,
          const SizedBox(height: AppSpacing.sm - 2),
          Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          for (final line in lines)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 3),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
            ),
          if (badge != null) ...[const SizedBox(height: AppSpacing.sm - 2), badge!],
        ],
      ),
    );
  }
}

/// The design's `.bio`: the player's own words in a white rounded box.
class ProfileBio extends StatelessWidget {
  const ProfileBio({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: palette.line),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.9)),
    );
  }
}

/// One sport of a profile, as the design's sport card: the sport's name (with [trailing] actions), the level in a
/// soft green box with the sport's own description, facts rows (experience, formats, goals), and below a line an
/// optional [footer] (the player's reputation in the sport).
class SportProfileCard extends StatelessWidget {
  const SportProfileCard({super.key, required this.sport, required this.sportName, this.trailing, this.footer});

  final SportProfile sport;
  final String sportName;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final experience = sport.experience;
    final description = sport.levelDescription;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(sportName, style: theme.textTheme.titleLarge)),
              ?trailing,
            ],
          ),
          Container(
            margin: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            decoration: BoxDecoration(color: palette.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.levelNamed(sport.levelName),
                  style: theme.textTheme.titleSmall?.copyWith(color: palette.onPrimarySoft),
                ),
                if (description != null && description.isNotEmpty)
                  Text(description, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
              ],
            ),
          ),
          if (experience != null) _Fact(label: AppStrings.factExperience, value: ProfileLabels.experience(experience)),
          if (sport.formats.isNotEmpty)
            _Fact(label: AppStrings.factFormat, value: sport.formats.map(ProfileLabels.format).join('، ')),
          if (sport.goals.isNotEmpty)
            _Fact(label: AppStrings.factGoal, value: sport.goals.map(ProfileLabels.goal).join('، ')),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Divider(height: 1, thickness: 1, color: palette.line),
            const SizedBox(height: AppSpacing.xs),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// One `.facts` row: a muted label at the start, the bold value at the end.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xxs + 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: context.palette.muted)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A home club as a row with a pin.
class HomeClubRow extends StatelessWidget {
  const HomeClubRow({super.key, required this.venue});

  final NamedRef venue;

  @override
  Widget build(BuildContext context) {
    return ListRow(leading: const Icon(Icons.place_outlined), title: venue.name);
  }
}
