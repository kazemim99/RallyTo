import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/rating.dart';
import '../../domain/rating_rules.dart';
import '../bloc/rating_form_cubit.dart';
import '../rating_labels.dart';

/// Rating one other player of a Completed game: large stars, up to 3 tag chips, level accuracy as radio cards
/// (required) and a private note only admins see. Says up front that the rating is double-blind and final; the
/// submit button stays pinned at the bottom. Closes with `true` once stored. Needs a [RatingFormCubit] above it.
class RatingFormPage extends StatelessWidget {
  const RatingFormPage({super.key});

  static const Key noticeKey = Key('ratingForm.notice');
  static const Key noteKey = Key('ratingForm.note');
  static const Key submitKey = Key('ratingForm.submit');

  static Key starKey(int stars) => Key('ratingForm.star.$stars');

  static Key tagKey(RatingTag tag) => Key('ratingForm.tag.${tag.wire}');

  static Key levelKey(LevelAccuracy accuracy) => Key('ratingForm.level.${accuracy.wire}');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RatingFormCubit>();
    return BlocConsumer<RatingFormCubit, RatingFormState>(
      listenWhen: (previous, current) =>
          (current.feedback != null && !identical(previous.feedback, current.feedback)) ||
          (current.done && !previous.done),
      listener: (context, state) {
        final feedback = state.feedback;
        if (feedback != null) {
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        }
        if (state.done) {
          final navigator = Navigator.of(context);
          navigator.canPop() ? navigator.pop(true) : context.go(Routes.matchPath(state.target.matchId));
        }
      },
      builder: (context, state) => Scaffold(
        extendBody: true,
        appBar: AppBar(title: const Text(AppStrings.ratingFormTitle)),
        bottomNavigationBar: StickyActions(
          primary: AppButton(
            key: submitKey,
            label: AppStrings.submitRating,
            icon: Icons.send_rounded,
            loading: state.submitting,
            onPressed: state.done ? null : cubit.submit,
          ),
        ),
        body: _Form(state: state),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state});

  final RatingFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RatingFormCubit>();
    final theme = Theme.of(context);
    final palette = context.palette;
    final trimmed = state.target.rateeName?.trim();
    final name = trimmed == null || trimmed.isEmpty ? AppStrings.ratingDefaultName : trimmed;
    final locked = state.submitting;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        StickyActions.contentPadding,
      ),
      children: [
        Row(
          children: [
            AppAvatar(name: name, size: AppAvatarSize.large),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(AppStrings.ratePlayer(name), style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const NoticeBanner(
          key: RatingFormPage.noticeKey,
          tone: NoticeTone.info,
          icon: Icons.visibility_off_outlined,
          title: AppStrings.ratingBlindTitle,
          body: AppStrings.ratingBlindNotice,
        ),
        const SizedBox(height: AppSpacing.section),
        const SectionTitle(title: AppStrings.starsLabel),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var stars = RatingRules.minStars; stars <= RatingRules.maxStars; stars++)
              IconButton(
                key: RatingFormPage.starKey(stars),
                tooltip: AppStrings.starsTooltip(PersianDigits.fromInt(stars)),
                iconSize: AppIconSize.md * 2,
                isSelected: stars <= state.stars,
                color: stars <= state.stars ? palette.star : palette.muted,
                icon: Icon(stars <= state.stars ? Icons.star_rounded : Icons.star_outline_rounded),
                onPressed: locked ? null : () => cubit.setStars(stars),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        SectionTitle(
          title: AppStrings.tagsLabel,
          subtitle: AppStrings.countOf(
            PersianDigits.fromInt(state.tags.length),
            PersianDigits.fromInt(RatingRules.maxTags),
          ),
        ),
        Wrap(
          spacing: AppSpacing.xs - 2,
          children: [
            for (final tag in RatingTag.values)
              AppChip(
                key: RatingFormPage.tagKey(tag),
                label: RatingLabels.tag(tag),
                tone: state.tags.contains(tag) ? AppChipTone.active : AppChipTone.neutral,
                onTap: locked ? null : () => cubit.toggleTag(tag),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: Text(AppStrings.levelAccuracyLabel, style: theme.textTheme.titleMedium),
        ),
        for (final accuracy in LevelAccuracy.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: RadioCard(
              key: RatingFormPage.levelKey(accuracy),
              title: RatingLabels.levelAccuracy(accuracy),
              selected: state.levelAccuracy == accuracy,
              onTap: locked ? null : () => cubit.setLevelAccuracy(accuracy),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: Text(AppStrings.privateNoteLabel, style: theme.textTheme.labelMedium)),
            const AppChip(label: AppStrings.privateNoteAdminsOnly, tone: AppChipTone.blue, icon: Icons.lock_outline),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: RatingFormPage.noteKey,
          maxLength: RatingRules.maxNoteLength,
          minLines: 3,
          maxLines: 5,
          enabled: !locked,
          onChanged: cubit.setNote,
          decoration: const InputDecoration(helperText: AppStrings.privateNoteHint, helperMaxLines: 2),
        ),
      ],
    );
  }
}
