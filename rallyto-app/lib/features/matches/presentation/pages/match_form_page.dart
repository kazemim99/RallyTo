import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/jalali_formatter.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../availability/presentation/availability_labels.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/presentation/widgets/venue_picker.dart';
import '../../../profile/domain/sport_rules.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../domain/entities/match.dart';
import '../../domain/match_rules.dart';
import '../bloc/match_form_cubit.dart';
import '../match_labels.dart';
import '../widgets/form_fields.dart';
import '../widgets/match_card.dart';

/// Creates a play post (design `Post`), or a direct invitation to one player (design `Invite`): the invitee card,
/// the host's open posts to invite them into as radio cards, or a new private game with a message. Needs a loaded
/// [MatchFormCubit] above it; once saved it moves on to the game.
class MatchFormPage extends StatelessWidget {
  const MatchFormPage({super.key});

  static const Key submitKey = Key('matchForm.submit');
  static const Key venueKey = Key('matchForm.venue');
  static const Key dateKey = Key('matchForm.date');
  static const Key startKey = Key('matchForm.start');
  static const Key durationKey = Key('matchForm.duration');
  static const Key playersBroughtKey = Key('matchForm.playersBrought');
  static const Key minLevelKey = Key('matchForm.minLevel');
  static const Key maxLevelKey = Key('matchForm.maxLevel');
  static const Key courtBookedKey = Key('matchForm.courtBooked');
  static const Key costNoteKey = Key('matchForm.costNote');
  static const Key descriptionKey = Key('matchForm.description');
  static const Key messageKey = Key('matchForm.message');
  static const Key serverErrorKey = Key('matchForm.serverError');
  static const Key levelsKey = Key('matchForm.levels');
  static const Key levelsDoneKey = Key('matchForm.levelsDone');
  static const Key openSpotsKey = Key('matchForm.openSpots');
  static const Key inviteeKey = Key('matchForm.invitee');
  static const Key newGameKey = Key('matchForm.newGame');
  static const Key contactNoteKey = Key('matchForm.contactNote');

  static Key sportKey(String code) => Key('matchForm.sport.$code');

  static Key formatKey(PlayFormat format) => Key('matchForm.format.${format.name}');

  static Key genderKey(PartnerGender gender) => Key('matchForm.gender.${gender.name}');

  static Key inviteIntoKey(String matchId) => Key('matchForm.inviteInto.$matchId');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(cubit.isInvitation ? AppStrings.newInvitationTitle : AppStrings.newPostTitle)),
      body: BlocConsumer<MatchFormCubit, MatchFormState>(
        listenWhen: (previous, current) => current.saved != null && previous.saved == null,
        listener: (context, state) {
          AppSnackbar.success(context, cubit.isInvitation ? AppStrings.invitationSent : AppStrings.postPublished);
          context.pushReplacement(Routes.matchPath(state.saved!.id));
        },
        builder: (context, state) => StateSwitcher(
          status: state.loadStatus,
          errorMessage: state.loadError,
          onRetry: cubit.load,
          loading: const Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.screen),
            child: SkeletonLines(count: 8, pulse: true),
          ),
          empty: EmptyState(
            icon: Icons.sports_tennis,
            title: AppStrings.noSportProfiles,
            ctaLabel: AppStrings.myProfileTitle,
            onCta: () => context.push(Routes.profile),
          ),
          contentBuilder: (context) => _Form(state: state),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.state});

  final MatchFormState state;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  /// The open post the invitee goes into; null for a new private game (and always for a play post).
  String? _postId;

  @override
  void initState() {
    super.initState();
    final posts = widget.state.invitablePosts;
    if (context.read<MatchFormCubit>().isInvitation && posts.isNotEmpty) _postId = posts.first.id;
  }

  MatchFormState get state => widget.state;

  Match? get _post {
    for (final post in state.invitablePosts) {
      if (post.id == _postId) return post;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    final invitation = cubit.isInvitation;
    final post = invitation ? _post : null;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.lg),
      children: [
        if (invitation) _InviteeCard(name: state.invitee?.displayName ?? '', sport: state.sport),
        if (invitation && state.invitablePosts.isNotEmpty) ..._postChoices(context),
        if (post == null) ...[
          ..._gameFields(context),
          if (invitation) ..._messageField(context) else ..._postFields(context),
          const SizedBox(height: AppSpacing.md),
          _OpenSpotsBox(count: state.openSpots, post: !invitation),
        ],
        if (invitation) ...[
          const SizedBox(height: AppSpacing.md),
          const NoticeBanner(
            key: MatchFormPage.contactNoteKey,
            tone: NoticeTone.info,
            icon: Icons.shield_outlined,
            body: AppStrings.inviteContactNote,
          ),
        ],
        if (state.serverError case final message?) ErrorBox(message, key: MatchFormPage.serverErrorKey),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: MatchFormPage.submitKey,
          label: invitation ? AppStrings.sendInvitation : AppStrings.publishPost,
          icon: invitation ? Icons.send_rounded : null,
          loading: state.submitting,
          onPressed: post == null ? cubit.submit : () => cubit.inviteInto(post),
        ),
      ],
    );
  }

  /// «انتخاب بازی»: the host's open posts as radio cards, and a dashed button for a new game instead.
  List<Widget> _postChoices(BuildContext context) {
    return [
      const FieldLabel(AppStrings.chooseGameLabel),
      for (final post in state.invitablePosts)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
          child: RadioCard(
            key: MatchFormPage.inviteIntoKey(post.id),
            title: MatchLabels.cardTitle(post),
            subtitle: MatchLabels.when(post),
            selected: post.id == _postId,
            onTap: state.submitting ? null : () => setState(() => _postId = post.id),
            trailing: MatchStatusChip(status: post.status),
          ),
        ),
      if (_postId != null)
        DashedButton(
          key: MatchFormPage.newGameKey,
          label: AppStrings.createNewGame,
          onPressed: state.submitting ? null : () => setState(() => _postId = null),
        )
      else
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          child: Text(AppStrings.newGameDetails, style: Theme.of(context).textTheme.titleMedium),
        ),
    ];
  }

  List<Widget> _gameFields(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    final errors = state.fieldErrors;
    final sport = state.sport;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: context.palette.muted);
    final formats = sport == null ? const <PlayFormat>[] : SportRules.allowedFormats(sport);
    return [
      const FieldLabel(AppStrings.sportLabel),
      Wrap(
        spacing: AppSpacing.xs - 2,
        children: [
          for (final s in state.sports)
            AppChip(
              key: MatchFormPage.sportKey(s.code),
              label: s.nameFa,
              tone: s.id == state.sportId ? AppChipTone.active : AppChipTone.neutral,
              onTap: () => cubit.sportSelected(s.id),
            ),
        ],
      ),
      FieldError(errors[MatchField.sport]),
      if (formats.isNotEmpty) ...[
        const FieldLabel(AppStrings.formatsTitle),
        AppSegmented<PlayFormat>(
          segments: [
            for (final format in formats)
              AppSegment(key: MatchFormPage.formatKey(format), value: format, label: ProfileLabels.format(format)),
          ],
          selected: state.format ?? formats.first,
          onChanged: cubit.formatSelected,
        ),
        FieldError(errors[MatchField.format]),
      ],
      const FieldLabel(AppStrings.venueLabel),
      _VenueField(state: state),
      FieldError(errors[MatchField.venue]),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel(AppStrings.dateLabel),
                DropdownField<Jalali>(
                  key: MatchFormPage.dateKey,
                  label: AppStrings.dateLabel,
                  floatingLabel: false,
                  value: state.date,
                  items: cubit.dateOptions,
                  labelOf: _dateLabel,
                  onChanged: cubit.dateSelected,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel(AppStrings.matchStartLabel),
                DropdownField<int>(
                  key: MatchFormPage.startKey,
                  label: AppStrings.matchStartLabel,
                  floatingLabel: false,
                  value: state.startMinute,
                  items: MatchRules.startOptions,
                  labelOf: AvailabilityLabels.minute,
                  onChanged: cubit.startSelected,
                ),
              ],
            ),
          ),
        ],
      ),
      FieldError(errors[MatchField.date]),
      Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
        child: Text(AppStrings.matchTimeHint, style: muted),
      ),
      FieldError(errors[MatchField.time]),
      const FieldLabel(AppStrings.durationLabel),
      DropdownField<int>(
        key: MatchFormPage.durationKey,
        label: AppStrings.durationLabel,
        floatingLabel: false,
        value: state.durationMinutes,
        items: MatchRules.durationOptions,
        labelOf: MatchLabels.duration,
        onChanged: cubit.durationSelected,
      ),
      FieldError(errors[MatchField.duration]),
      const FieldLabel(AppStrings.playersBroughtLabel),
      DropdownField<int>(
        key: MatchFormPage.playersBroughtKey,
        label: AppStrings.playersBroughtHint(PersianDigits.fromInt(state.maxPlayersBrought)),
        value: state.playersBrought,
        items: [for (var i = 0; i <= state.maxPlayersBrought; i++) i],
        labelOf: PersianDigits.fromInt,
        enabled: state.maxPlayersBrought > 0,
        onChanged: cubit.playersBroughtSelected,
      ),
      FieldError(errors[MatchField.playersBrought]),
    ];
  }

  List<Widget> _postFields(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    final errors = state.fieldErrors;
    final sport = state.sport;
    final theme = Theme.of(context);
    final min = state.minLevel;
    final max = state.maxLevel;
    return [
      const FieldLabel(AppStrings.levelsLabel),
      RangeDisplay(
        key: MatchFormPage.levelsKey,
        start: min == null ? AppStrings.levelUnknown : MatchLabels.level(min, sport),
        end: max == null ? AppStrings.levelUnknown : MatchLabels.level(max, sport),
        onTap: () => _pickLevels(context, sport),
      ),
      const FieldLabel(AppStrings.partnerGenderLabel),
      AppSegmented<PartnerGender>(
        segments: [
          for (final gender in PartnerGender.values)
            AppSegment(key: MatchFormPage.genderKey(gender), value: gender, label: MatchLabels.partnerGender(gender)),
        ],
        selected: state.partnerGender,
        onChanged: state.genderLocked ? null : cubit.partnerGenderSelected,
      ),
      if (state.genderLocked)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
          child: Text(
            AppStrings.genderLockedHint,
            style: theme.textTheme.bodySmall?.copyWith(color: context.palette.muted),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      AppSwitchRow(
        key: MatchFormPage.courtBookedKey,
        title: AppStrings.courtBookedLabel,
        subtitle: AppStrings.courtBookedHint,
        value: state.courtBooked,
        onChanged: cubit.courtBookedChanged,
      ),
      const FieldLabel(AppStrings.costNoteLabel),
      TextFormField(
        key: MatchFormPage.costNoteKey,
        initialValue: state.costNote,
        maxLength: MatchRules.maxCostNoteLength,
        onChanged: cubit.costNoteChanged,
        decoration: InputDecoration(hintText: AppStrings.costNoteHint, errorText: errors[MatchField.costNote]),
      ),
      const FieldLabel(AppStrings.descriptionLabel),
      TextFormField(
        key: MatchFormPage.descriptionKey,
        initialValue: state.description,
        maxLength: MatchRules.maxDescriptionLength,
        maxLines: 4,
        minLines: 2,
        onChanged: cubit.descriptionChanged,
        decoration: InputDecoration(errorText: errors[MatchField.description]),
      ),
    ];
  }

  /// The invitation's message, with a «۰ از ۲۰۰» counter.
  List<Widget> _messageField(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    final name = state.invitee?.displayName.trim() ?? '';
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.muted);
    return [
      const FieldLabel(AppStrings.inviteMessageLabel),
      TextFormField(
        key: MatchFormPage.messageKey,
        initialValue: state.message,
        maxLength: MatchRules.maxMessageLength,
        maxLines: 5,
        minLines: 3,
        onChanged: cubit.messageChanged,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Text(
          AppStrings.countOf(PersianDigits.fromInt(currentLength), PersianDigits.fromInt(maxLength ?? 0)),
          style: muted,
        ),
        decoration: InputDecoration(
          hintText: AppStrings.inviteMessageHint(name.isEmpty ? AppStrings.ratingDefaultName : name),
          errorText: state.fieldErrors[MatchField.message],
        ),
      ),
    ];
  }

  /// The level range picker, in a sheet over the whole screen; each choice applies at once.
  Future<void> _pickLevels(BuildContext context, Sport? sport) {
    final cubit = context.read<MatchFormCubit>();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _LevelSheet(sport: sport),
      ),
    );
  }

  static String _dateLabel(Jalali d) => PersianDigits.toPersian(
    '${JalaliFormatter.weekdayNames[d.weekDay - 1]} ${d.day} ${JalaliFormatter.monthNames[d.month - 1]} ${d.year}',
  );
}

/// The design's `.invitee`: who the invitation is for, on soft green.
class _InviteeCard extends StatelessWidget {
  const _InviteeCard({required this.name, this.sport});

  final String name;
  final Sport? sport;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final shown = name.trim().isEmpty ? AppStrings.ratingDefaultName : name.trim();
    return Container(
      key: MatchFormPage.inviteeKey,
      padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
      decoration: BoxDecoration(color: palette.primarySoft, borderRadius: BorderRadius.circular(AppRadius.tile)),
      child: Row(
        children: [
          AppAvatar(name: shown),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.inviteTo(shown), style: theme.textTheme.titleSmall),
                if (sport case final sport?)
                  Text(sport.nameFa, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The club, as a field that opens the club picker; a chosen club can be taken off.
class _VenueField extends StatelessWidget {
  const _VenueField({required this.state});

  final MatchFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    final sport = state.sport;
    final venue = state.venue;
    final enabled = sport != null && state.cityId != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: AppStrings.venueLabel,
      child: InkWell(
        key: MatchFormPage.venueKey,
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: !enabled
            ? null
            : () async {
                final venues = await VenuePicker.show(
                  context,
                  cityId: state.cityId!,
                  sportCode: sport.code,
                  initialSelection: [?venue],
                );
                if (venues != null) cubit.venueSelected(venues.isEmpty ? null : venues.first);
              },
        child: InputDecorator(
          isEmpty: venue == null,
          decoration: InputDecoration(
            enabled: enabled,
            hintText: AppStrings.chooseVenue,
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: venue == null
                ? const Icon(Icons.chevron_right_rounded)
                : IconButton(
                    tooltip: AppStrings.clearVenue,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => cubit.venueSelected(null),
                  ),
          ),
          child: Text(venue?.name ?? '', overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// The design's `.open-spots`: «این آگهی ۱ جای خالی خواهد داشت.», the count in bold, on soft green.
class _OpenSpotsBox extends StatelessWidget {
  const _OpenSpotsBox({required this.count, required this.post});

  final int count;

  /// A play post («این آگهی»), else a new private game («این بازی»).
  final bool post;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final digits = PersianDigits.fromInt(count);
    final sentence = post ? AppStrings.openSpotsPost(digits) : AppStrings.openSpotsGame(digits);
    final bold = AppStrings.openSpotsCount(digits);
    final at = sentence.indexOf(bold);
    final style = theme.textTheme.bodyMedium;
    return Container(
      key: MatchFormPage.openSpotsKey,
      padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
      decoration: BoxDecoration(color: palette.primarySoft, borderRadius: BorderRadius.circular(AppRadius.field)),
      child: Text.rich(
        at < 0
            ? TextSpan(text: sentence)
            : TextSpan(
                children: [
                  TextSpan(text: sentence.substring(0, at)),
                  TextSpan(
                    text: bold,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: sentence.substring(at + bold.length)),
                ],
              ),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// The level range: from and to, each applied as it is chosen.
class _LevelSheet extends StatelessWidget {
  const _LevelSheet({required this.sport});

  final Sport? sport;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchFormCubit>();
    return BlocBuilder<MatchFormCubit, MatchFormState>(
      builder: (context, state) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.levelsLabel, style: Theme.of(context).textTheme.titleLarge),
              const FieldLabel(AppStrings.levelFrom),
              DropdownField<LevelTier>(
                key: MatchFormPage.minLevelKey,
                label: AppStrings.levelFrom,
                floatingLabel: false,
                value: state.minLevel,
                items: LevelTier.values,
                labelOf: (t) => MatchLabels.level(t, sport),
                onChanged: cubit.minLevelSelected,
              ),
              const FieldLabel(AppStrings.levelTo),
              DropdownField<LevelTier>(
                key: MatchFormPage.maxLevelKey,
                label: AppStrings.levelTo,
                floatingLabel: false,
                value: state.maxLevel,
                items: LevelTier.values,
                labelOf: (t) => MatchLabels.level(t, sport),
                onChanged: cubit.maxLevelSelected,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                key: MatchFormPage.levelsDoneKey,
                label: AppStrings.levelsPickerDone,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
