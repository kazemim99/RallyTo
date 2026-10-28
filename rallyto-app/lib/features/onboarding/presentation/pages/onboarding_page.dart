import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/auth/auth_session_cubit.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../catalog/presentation/bloc/catalog_load_status.dart';
import '../../../catalog/presentation/catalog_labels.dart';
import '../../../catalog/presentation/widgets/check_mark.dart';
import '../../../catalog/presentation/widgets/city_picker.dart';
import '../../../catalog/presentation/widgets/venue_picker.dart';
import '../../../profile/domain/entities/profile_enums.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../../profile/presentation/widgets/sport_profile_editor.dart';
import '../bloc/onboarding_cubit.dart';

/// Profile creation (the design's Onboarding): «مرحله ۲ از ۶» under a progress bar, one question per step with a bold
/// title and a muted line under it, and the step's action pinned at the bottom. Needs an [OnboardingCubit] above it
/// (started). When the profile is created the session changes and the router moves on to home by itself.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const Key nameFieldKey = Key('onboarding.name');
  static const Key nextKey = Key('onboarding.next');
  static const Key backKey = Key('onboarding.back');
  static const Key genderNoticeKey = Key('onboarding.genderNotice');
  static const Key provinceFieldKey = Key('onboarding.province');
  static const Key cityButtonKey = Key('onboarding.city');
  static const Key homeVenuesButtonKey = Key('onboarding.homeVenues');
  static const Key skipKey = Key('onboarding.skip');
  static const Key errorKey = Key('onboarding.error');

  static Key genderKey(Gender gender) => Key('onboarding.gender.${gender.name}');

  static Key sportKey(String code) => Key('onboarding.sport.$code');

  /// The row of a chosen home club.
  static Key homeVenueKey(String venueId) => Key('onboarding.homeVenue.$venueId');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        return PopScope(
          canPop: state.step.index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cubit.back();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text(AppStrings.onboardingTitle),
              actions: [
                IconButton(
                  tooltip: AppStrings.signOut,
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => context.read<AuthSessionCubit>().signOut(),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.screen),
                    child: StepHeader(step: state.stepNumber, total: OnboardingState.stepCount),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.screen,
                        AppSpacing.lg,
                        AppSpacing.screen,
                        AppSpacing.lg,
                      ),
                      child: switch (state.step) {
                        OnboardingStep.name => _NameStep(state: state),
                        OnboardingStep.gender => _GenderStep(state: state),
                        OnboardingStep.birthDate => _BirthDateStep(state: state, cubit: cubit),
                        OnboardingStep.city => _CityStep(state: state),
                        OnboardingStep.sports => _SportsStep(state: state),
                        OnboardingStep.homeVenues => _HomeVenuesStep(state: state),
                      },
                    ),
                  ),
                  _Actions(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A step: its bold title (design `.onboarding h1`), a muted line under it, then its [children].
class _Step extends StatelessWidget {
  const _Step({required this.title, this.hint = AppStrings.onboardingStepHint, required this.children});

  final String title;
  final String hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: theme.textTheme.headlineMedium)),
        const SizedBox(height: AppSpacing.xxs),
        Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted)),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

/// The step's message (a broken rule or the server's refusal), under its fields.
class _StepError extends StatelessWidget {
  const _StepError(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: NoticeBanner(key: OnboardingPage.errorKey, tone: NoticeTone.error, body: text),
      ),
    );
  }
}

/// A field-label (design `.label`) above its control.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _NameStep extends StatefulWidget {
  const _NameStep({required this.state});

  final OnboardingState state;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _controller = TextEditingController(text: widget.state.displayName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    return _Step(
      title: AppStrings.nameStepTitle,
      hint: AppStrings.nameStepHint,
      children: [
        TextField(
          key: OnboardingPage.nameFieldKey,
          controller: _controller,
          maxLength: 30,
          textInputAction: TextInputAction.next,
          onChanged: cubit.displayNameChanged,
          onSubmitted: (_) => cubit.next(),
          decoration: InputDecoration(
            labelText: AppStrings.displayNameLabel,
            errorText: widget.state.error,
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _GenderStep extends StatelessWidget {
  const _GenderStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    return _Step(
      title: AppStrings.genderStepTitle,
      children: [
        AppSegmented<Gender?>(
          segments: [
            for (final gender in Gender.values)
              AppSegment(value: gender, label: ProfileLabels.gender(gender), key: OnboardingPage.genderKey(gender)),
          ],
          selected: state.gender,
          onChanged: (gender) {
            if (gender != null) cubit.genderSelected(gender);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const NoticeBanner(
          key: OnboardingPage.genderNoticeKey,
          tone: NoticeTone.info,
          icon: Icons.lock_outline,
          title: AppStrings.genderLockedTitle,
          body: AppStrings.genderLockedNotice,
        ),
        _StepError(state.error),
      ],
    );
  }
}

class _BirthDateStep extends StatelessWidget {
  const _BirthDateStep({required this.state, required this.cubit});

  final OnboardingState state;
  final OnboardingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final thisYear = cubit.today.year;
    return _Step(
      title: AppStrings.birthDateStepTitle,
      hint: AppStrings.birthDateHint,
      children: [
        // Day, month and year side by side (design `.three-col`).
        JalaliDateSelector(
          firstYear: thisYear - OnboardingCubit.oldestAge,
          lastYear: thisYear - OnboardingCubit.minimumAge,
          value: state.birthDate,
          onChanged: cubit.birthDateChanged,
        ),
        _StepError(state.error),
      ],
    );
  }
}

class _CityStep extends StatelessWidget {
  const _CityStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final city = state.city;
    Future<void> pick() async {
      final selection = await CityPicker.show(context);
      if (selection != null) cubit.citySelected(selection);
    }

    return _Step(
      title: AppStrings.cityStepTitle,
      hint: AppStrings.cityStepHint,
      children: [
        _PickerField(
          key: OnboardingPage.provinceFieldKey,
          label: AppStrings.provinceLabel,
          value: city?.provinceName,
          placeholder: AppStrings.chooseProvince,
          icon: Icons.map_outlined,
          onTap: pick,
        ),
        const SizedBox(height: AppSpacing.md),
        _PickerField(
          key: OnboardingPage.cityButtonKey,
          label: AppStrings.cityLabel,
          value: city?.cityName,
          placeholder: AppStrings.chooseCity,
          icon: Icons.location_city_outlined,
          onTap: pick,
        ),
        _StepError(state.error),
      ],
    );
  }
}

/// A labelled field that opens a picker: the choice (or a muted placeholder) in an input-styled box with a chevron.
class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final chosen = value;
    final radius = BorderRadius.circular(AppRadius.field);
    return _Labelled(
      label: label,
      child: Semantics(
        button: true,
        label: '$label: ${chosen ?? placeholder}',
        excludeSemantics: true,
        child: Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: palette.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.control),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: AppIconSize.action, color: palette.muted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        chosen ?? placeholder,
                        style: theme.textTheme.bodyLarge?.copyWith(color: chosen == null ? palette.muted : null),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: palette.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SportsStep extends StatelessWidget {
  const _SportsStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    if (state.sportsStatus == CatalogLoadStatus.loading) return const LoadingView();
    if (state.sportsStatus == CatalogLoadStatus.failure) return ErrorState(onRetry: cubit.start);
    final theme = Theme.of(context);
    return _Step(
      title: AppStrings.sportsStepTitle,
      hint: AppStrings.sportsStepHint,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final sport in state.sports)
              AppChip(
                key: OnboardingPage.sportKey(sport.code),
                label: sport.nameFa,
                tone: state.isChosen(sport.id) ? AppChipTone.active : AppChipTone.neutral,
                icon: state.isChosen(sport.id) ? Icons.check_rounded : null,
                onTap: () => cubit.toggleSport(sport),
              ),
          ],
        ),
        for (final draft in state.drafts)
          if (state.sportOf(draft) case final sport?)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SportBall(
                          label: sport.code.isEmpty ? '' : sport.code.substring(0, 1).toUpperCase(),
                          semanticLabel: sport.nameFa,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(sport.nameFa, style: theme.textTheme.titleMedium)),
                      ],
                    ),
                    SportProfileEditor(sport: sport, draft: draft, onChanged: cubit.sportChanged),
                  ],
                ),
              ),
            ),
        _StepError(state.error),
      ],
    );
  }
}

class _HomeVenuesStep extends StatelessWidget {
  const _HomeVenuesStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final city = state.city;
    final sportNames = {for (final sport in state.sports) sport.code: sport.nameFa};
    return _Step(
      title: AppStrings.homeVenuesStepTitle,
      hint: AppStrings.homeVenuesStepHint,
      children: [
        for (final venue in state.homeVenues) ...[
          ListRow(
            key: OnboardingPage.homeVenueKey(venue.id),
            leading: const Icon(Icons.place_outlined),
            title: venue.name,
            subtitle: _sportsOf(venue, sportNames),
            trailing: const ExcludeSemantics(child: CheckMark(checked: true)),
            semanticLabel: AppStrings.homeVenueChosen(venue.name),
            onTap: state.isSubmitting
                ? null
                : () => cubit.homeVenuesChanged([...state.homeVenues.where((v) => v.id != venue.id)]),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        DashedButton(
          key: OnboardingPage.homeVenuesButtonKey,
          label: AppStrings.chooseHomeVenues,
          icon: Icons.add_rounded,
          onPressed: city == null || state.isSubmitting
              ? null
              : () async {
                  final venues = await VenuePicker.show(
                    context,
                    cityId: city.cityId,
                    maxSelection: OnboardingCubit.maxHomeVenues,
                    initialSelection: state.homeVenues,
                  );
                  if (venues != null) cubit.homeVenuesChanged(venues);
                },
        ),
        _StepError(state.error),
      ],
    );
  }

  /// «تنیس، پدل», or the venue's city when its sports are not known.
  static String _sportsOf(Venue venue, Map<String, String> sportNames) {
    if (venue.sports.isEmpty) return venue.cityName;
    return venue.sports.map((s) => CatalogLabels.sportName(s.sportCode, sportNames)).join('، ');
  }
}

/// The step's actions, pinned at the bottom: back and the primary action (1 : 1.5), and «فعلاً نه» as a ghost
/// button on the last step once there is something to skip.
class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final last = state.isLastStep;
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (state.step.index > 0 && !state.profileCreated) ...[
                  Expanded(
                    flex: 2,
                    child: AppButton.secondary(
                      key: OnboardingPage.backKey,
                      label: AppStrings.back,
                      onPressed: state.isSubmitting ? null : cubit.back,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  flex: 3,
                  child: AppButton(
                    key: OnboardingPage.nextKey,
                    label: last ? AppStrings.createProfile : AppStrings.next,
                    loading: state.isSubmitting,
                    onPressed: cubit.next,
                  ),
                ),
              ],
            ),
            if (last && (state.homeVenues.isNotEmpty || state.profileCreated))
              AppButton.ghost(
                key: OnboardingPage.skipKey,
                label: AppStrings.skip,
                onPressed: state.isSubmitting ? null : cubit.skipHomeVenues,
              ),
          ],
        ),
      ),
    );
  }
}
