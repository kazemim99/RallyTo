import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/auth/auth_session_cubit.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../account/presentation/pages/account_deletion_page.dart';
import '../../../ratings/presentation/widgets/reputation_widgets.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/entities/profile_enums.dart';
import '../../domain/profile_completion.dart';
import '../bloc/my_profile_cubit.dart';
import '../profile_labels.dart';
import '../widgets/my_profile_editing.dart';
import '../widgets/profile_widgets.dart';
import 'my_profile_sections.dart';

/// The player's own profile: a compact hero (photo, name, city and age range, the reliability badge) with «ویرایش»
/// for name, bio and city; how complete the profile is; a menu to reputation, sport profiles, home clubs,
/// availability and notification settings; who may see them, the players they blocked and the reports they filed;
/// and sign-out and account deletion. Needs a loaded [MyProfileCubit] above it.
class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  static const Key editBasicsKey = Key('myProfile.editBasics');
  static const Key addSportKey = Key('myProfile.addSport');
  static const Key homeVenuesKey = Key('myProfile.homeVenues');
  static const Key visibilityKey = Key('myProfile.visibility');
  static const Key blockedPlayersKey = Key('myProfile.blocked');
  static const Key myReportsKey = Key('myProfile.reports');
  static const Key avatarKey = Key('myProfile.avatar');
  static const Key photoKey = Key('myProfile.photo');
  static const Key completionKey = Key('myProfile.completion');
  static const Key reputationKey = Key('myProfile.reputation');
  static const Key sportsKey = Key('myProfile.sports');
  static const Key homeClubsKey = Key('myProfile.homeClubs');
  static const Key availabilityKey = Key('myProfile.availability');
  static const Key notificationSettingsKey = Key('myProfile.notificationSettings');
  static const Key signOutKey = Key('myProfile.signOut');
  static const Key deleteAccountKey = Key('myProfile.deleteAccount');

  static Key removeSportKey(String sportId) => Key('myProfile.removeSport.$sportId');

  static Key editSportKey(String sportId) => Key('myProfile.editSport.$sportId');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MyProfileCubit>();
    return BlocConsumer<MyProfileCubit, MyProfileState>(
      listenWhen: (previous, current) => current.feedback != null && !identical(previous.feedback, current.feedback),
      listener: (context, state) {
        final feedback = state.feedback!;
        feedback.isError
            ? AppSnackbar.error(context, feedback.message)
            : AppSnackbar.success(context, feedback.message);
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.myProfileTitle),
          actions: [
            if (state.profile != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xxs),
                child: TextButton(
                  key: editBasicsKey,
                  onPressed: state.busy ? null : () => MyProfileEditing.editBasics(context),
                  child: const Text(AppStrings.editProfile),
                ),
              ),
          ],
        ),
        body: StateSwitcher(
          status: state.status,
          errorMessage: state.errorMessage,
          onRetry: cubit.load,
          loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines(count: 6)),
          contentBuilder: (context) => _Content(state: state),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final MyProfileState state;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final cubit = context.read<MyProfileCubit>();
    final palette = context.palette;
    final completion = ProfileCompletion.of(profile);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
          children: [
            ProfileHero(
              avatar: _EditableAvatar(profile: profile, busy: state.busy),
              name: profile.displayName,
              lines: [
                [profile.city.name, ProfileLabels.ageRange(profile.ageRange)].joinDisplay(),
              ],
              badge: switch (profile.reputation?.reliability) {
                final tier? => ReliabilityBadge(tier: tier),
                null => null,
              },
            ),
            if (profile.bio case final bio? when bio.trim().isNotEmpty) ...[
              ProfileBio(text: bio),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (!completion.isComplete) ...[
              _CompletionCard(completion: completion, busy: state.busy),
              const SizedBox(height: AppSpacing.md),
            ],
            MenuList(
              items: [
                MenuItem(
                  key: MyProfilePage.reputationKey,
                  icon: Icons.star_outline_rounded,
                  label: AppStrings.myReputationTitle,
                  onTap: () => openMyProfileSection(context, const MyReputationPage()),
                ),
                MenuItem(
                  key: MyProfilePage.sportsKey,
                  icon: Icons.sports_tennis_rounded,
                  label: AppStrings.sportProfilesTitle,
                  trailing: _Count(profile.sports.length),
                  onTap: () => openMyProfileSection(context, const MySportsPage()),
                ),
                MenuItem(
                  key: MyProfilePage.homeClubsKey,
                  icon: Icons.place_outlined,
                  label: AppStrings.favoriteClubsTitle,
                  trailing: _Count(profile.homeVenues.length),
                  onTap: () => openMyProfileSection(context, const MyHomeVenuesPage()),
                ),
                MenuItem(
                  key: MyProfilePage.availabilityKey,
                  icon: Icons.event_available_outlined,
                  label: AppStrings.availabilityTitle,
                  onTap: () => context.push(Routes.availability),
                ),
                MenuItem(
                  key: MyProfilePage.notificationSettingsKey,
                  icon: Icons.notifications_none_rounded,
                  label: AppStrings.notificationSettingsTitle,
                  onTap: () => context.push(Routes.notificationSettings),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xxs, bottom: AppSpacing.xs),
              child: Semantics(
                header: true,
                child: Text(
                  AppStrings.privacySafetyTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: palette.muted),
                ),
              ),
            ),
            AppCard(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
              child: AppSwitchRow(
                key: MyProfilePage.visibilityKey,
                title: AppStrings.visibilitySameGender,
                subtitle: AppStrings.visibilityExplanation,
                value: profile.visibility == ProfileVisibility.sameGender,
                onChanged: state.busy ? null : cubit.setSameGenderOnly,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            MenuList(
              items: [
                MenuItem(
                  key: MyProfilePage.blockedPlayersKey,
                  icon: Icons.block_rounded,
                  label: AppStrings.blockedPlayersTitle,
                  onTap: () => context.push(Routes.blockedPlayers),
                ),
                MenuItem(
                  key: MyProfilePage.myReportsKey,
                  icon: Icons.flag_outlined,
                  label: AppStrings.myReportsTitle,
                  onTap: () => context.push(Routes.myReports),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            MenuList(
              items: [
                MenuItem(
                  key: MyProfilePage.signOutKey,
                  icon: Icons.logout_rounded,
                  label: AppStrings.signOut,
                  destructive: true,
                  // The app's one sign-out: it runs the before-sign-out hooks (unregistering this device's push token).
                  onTap: () => context.read<AuthSessionCubit>().signOut(),
                ),
                MenuItem(
                  key: MyProfilePage.deleteAccountKey,
                  icon: Icons.person_remove_outlined,
                  label: AppStrings.deleteAccount,
                  destructive: true,
                  // A sheet says what deletion does, then a fresh SMS code confirms it.
                  onTap: () => AccountDeletionPage.start(context),
                ),
              ],
            ),
          ],
        ),
        if (state.busy)
          const PositionedDirectional(top: 0, start: 0, end: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }
}

/// A muted count before a menu row's chevron; nothing at zero.
class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Text(
      PersianDigits.fromInt(count),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
    );
  }
}

/// The large avatar with a small camera button on its corner, for adding, changing or removing the photo.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({required this.profile, required this.busy});

  final MyProfile profile;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = AppAvatarSize.xlarge.dimension;
    return SizedBox(
      // Wide enough for the 48dp camera button to overhang the avatar.
      width: size + AppSpacing.lg,
      height: size + AppSpacing.sm,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          AppAvatar(
            key: MyProfilePage.avatarKey,
            name: profile.displayName,
            photoUrl: profile.photoUrl,
            size: AppAvatarSize.xlarge,
          ),
          PositionedDirectional(
            bottom: -AppSpacing.sm,
            end: -AppSpacing.sm,
            child: IconButton(
              key: MyProfilePage.photoKey,
              tooltip: profile.photoUrl == null ? AppStrings.photoAdd : AppStrings.photoChange,
              onPressed: busy ? null : () => MyProfileEditing.editPhoto(context),
              icon: Container(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xxs + 1),
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 2),
                ),
                child: Icon(Icons.photo_camera_outlined, size: AppIconSize.sm, color: palette.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's `.profile-completion`: how complete the profile is, on the dark green, with a hint for the next part
/// to fill in. Tapping it opens that part.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.completion, required this.busy});

  final ProfileCompletion completion;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final percent = PersianDigits.fromInt(completion.percent);
    final next = completion.next;
    return AppCard(
      key: MyProfilePage.completionKey,
      color: palette.primaryDark,
      borderColor: palette.primaryDark,
      onTap: busy || next == null ? null : () => _open(context, next),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.profileCompletionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(color: palette.onBrand),
                ),
              ),
              Text(
                AppStrings.percentLabel(percent),
                style: theme.textTheme.titleSmall?.copyWith(color: palette.onBrand),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Semantics(
            label: AppStrings.profileCompletionTitle,
            value: AppStrings.progressPercent(percent),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                height: AppSizes.progressBar,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: palette.onBrand.withValues(alpha: 0.2))),
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: completion.fraction,
                      heightFactor: 1,
                      child: ColoredBox(color: palette.onBrandMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Text(_hint(next), style: theme.textTheme.bodyMedium?.copyWith(color: palette.onBrandMuted)),
          ],
        ],
      ),
    );
  }

  static String _hint(ProfileCompletionItem item) => switch (item) {
    ProfileCompletionItem.photo => AppStrings.completionHintPhoto,
    ProfileCompletionItem.bio => AppStrings.completionHintBio,
    ProfileCompletionItem.sports => AppStrings.completionHintSports,
    ProfileCompletionItem.homeVenues => AppStrings.completionHintHomeVenues,
  };

  static Future<void> _open(BuildContext context, ProfileCompletionItem item) => switch (item) {
    ProfileCompletionItem.photo => MyProfileEditing.editPhoto(context),
    ProfileCompletionItem.bio => MyProfileEditing.editBasics(context),
    ProfileCompletionItem.sports => openMyProfileSection(context, const MySportsPage()),
    ProfileCompletionItem.homeVenues => openMyProfileSection(context, const MyHomeVenuesPage()),
  };
}
