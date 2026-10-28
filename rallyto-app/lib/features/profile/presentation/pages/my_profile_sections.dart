import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../ratings/presentation/widgets/reputation_widgets.dart';
import '../bloc/my_profile_cubit.dart';
import '../profile_labels.dart';
import '../widgets/my_profile_editing.dart';
import '../widgets/profile_widgets.dart';
import 'my_profile_page.dart';

/// Opens one section of the player's own profile over the profile tab, sharing its [MyProfileCubit]. The edits' feedback
/// is said by the profile page underneath, which stays mounted.
Future<void> openMyProfileSection(BuildContext context, Widget section) {
  final cubit = context.read<MyProfileCubit>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(value: cubit, child: section),
    ),
  );
}

/// A section's frame: the title, a thin progress line while an edit is out, and the body built from the loaded
/// profile.
class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({required this.title, required this.builder});

  final String title;
  final Widget Function(BuildContext context, MyProfileState state) builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: BlocBuilder<MyProfileCubit, MyProfileState>(
        builder: (context, state) {
          if (state.profile == null) {
            return StateSwitcher(
              status: state.status,
              errorMessage: state.errorMessage,
              onRetry: context.read<MyProfileCubit>().load,
              contentBuilder: (_) => const SizedBox.shrink(),
            );
          }
          return Stack(
            children: [
              builder(context, state),
              if (state.busy)
                const PositionedDirectional(top: 0, start: 0, end: 0, child: LinearProgressIndicator(minHeight: 2)),
            ],
          );
        },
      ),
    );
  }
}

/// «پروفایل‌های ورزشی»: one card per sport, each with edit and remove, and adding another sport.
class MySportsPage extends StatelessWidget {
  const MySportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppStrings.sportProfilesTitle,
      builder: (context, state) {
        final cubit = context.read<MyProfileCubit>();
        final profile = state.profile!;
        final names = state.sportNames;
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: [
            for (final sport in profile.sports) ...[
              SportProfileCard(
                sport: sport,
                sportName: ProfileLabels.sportName(sport.sportCode, names),
                footer: switch (profile.reputation?.forSport(sport.sportId)) {
                  final reputation? => SportReputationSummary(reputation: reputation),
                  null => null,
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: MyProfilePage.editSportKey(sport.sportId),
                      tooltip: AppStrings.editSport,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: state.busy || cubit.sportById(sport.sportId) == null
                          ? null
                          : () => MyProfileEditing.editSport(context, cubit.sportById(sport.sportId)!, sport.toDraft()),
                    ),
                    IconButton(
                      key: MyProfilePage.removeSportKey(sport.sportId),
                      tooltip: AppStrings.remove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: state.busy
                          ? null
                          : () => MyProfileEditing.removeSport(
                              context,
                              sport,
                              ProfileLabels.sportName(sport.sportCode, names),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            DashedButton(
              key: MyProfilePage.addSportKey,
              label: AppStrings.addSport,
              onPressed: state.busy ? null : () => MyProfileEditing.addSport(context),
            ),
          ],
        );
      },
    );
  }
}

/// «باشگاه‌های منتخب»: the home clubs as rows with a pin, and changing them.
class MyHomeVenuesPage extends StatelessWidget {
  const MyHomeVenuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppStrings.favoriteClubsTitle,
      builder: (context, state) {
        final profile = state.profile!;
        final edit = state.busy ? null : () => MyProfileEditing.editHomeVenues(context);
        if (profile.homeVenues.isEmpty) {
          return EmptyState(
            icon: Icons.place_outlined,
            title: AppStrings.noHomeVenues,
            subtitle: AppStrings.completionHintHomeVenues,
            ctaLabel: AppStrings.editHomeVenues,
            onCta: edit,
          );
        }
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: [
            for (final venue in profile.homeVenues) ...[
              HomeClubRow(venue: venue),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.xs),
            AppButton.secondary(
              key: MyProfilePage.homeVenuesKey,
              label: AppStrings.editHomeVenues,
              icon: Icons.edit_location_alt_outlined,
              onPressed: edit,
            ),
          ],
        );
      },
    );
  }
}

/// «اعتبار و امتیازهای من»: the reliability badge and the public reputation in each sport, as other players see them.
class MyReputationPage extends StatelessWidget {
  const MyReputationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppStrings.myReputationTitle,
      builder: (context, state) {
        final profile = state.profile!;
        final reputation = profile.reputation;
        if (reputation == null) {
          return const EmptyState(
            icon: Icons.star_outline_rounded,
            title: AppStrings.reputationEmptyTitle,
            subtitle: AppStrings.reputationEmptySubtitle,
          );
        }
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: [
            if (reputation.reliability case final tier?) ...[
              Center(child: ReliabilityBadge(tier: tier)),
              const SizedBox(height: AppSpacing.md),
            ],
            for (final sport in profile.sports)
              if (reputation.forSport(sport.sportId) case final perSport?) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ProfileLabels.sportName(sport.sportCode, state.sportNames),
                        style: theme.textTheme.titleMedium,
                      ),
                      SportReputationSummary(reputation: perSport),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        );
      },
    );
  }
}
