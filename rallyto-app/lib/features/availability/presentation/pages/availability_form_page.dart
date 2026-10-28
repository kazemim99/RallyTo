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
import '../../../catalog/presentation/widgets/venue_picker.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/domain/sport_rules.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../domain/availability_rules.dart';
import '../../domain/entities/availability_window.dart';
import '../availability_labels.dart';
import '../bloc/availability_form_cubit.dart';

/// Creates or edits an availability window: sport, weekly or one-off, weekdays from Saturday (or one Jalali date), the
/// hours, clubs, formats and a note, with the save button pinned at the bottom. Needs a loaded [AvailabilityFormCubit]
/// above it; closes with the saved window.
class AvailabilityFormPage extends StatelessWidget {
  const AvailabilityFormPage({super.key});

  static const Key saveKey = Key('availabilityForm.save');
  static const Key startKey = Key('availabilityForm.start');
  static const Key endKey = Key('availabilityForm.end');
  static const Key dateKey = Key('availabilityForm.date');
  static const Key venuesKey = Key('availabilityForm.venues');
  static const Key noteKey = Key('availabilityForm.note');
  static const Key serverErrorKey = Key('availabilityForm.serverError');

  static Key sportKey(String code) => Key('availabilityForm.sport.$code');

  static Key weekdayKey(Weekday day) => Key('availabilityForm.weekday.${day.name}');

  static Key kindKey(AvailabilityKind kind) => Key('availabilityForm.kind.${kind.name}');

  static Key formatKey(PlayFormat format) => Key('availabilityForm.format.${format.name}');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AvailabilityFormCubit>();
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(cubit.isEditing ? AppStrings.availabilityEditTitle : AppStrings.availabilityNewTitle)),
      bottomNavigationBar: BlocBuilder<AvailabilityFormCubit, AvailabilityFormState>(
        buildWhen: (previous, current) =>
            previous.loadStatus != current.loadStatus || previous.submitting != current.submitting,
        builder: (context, state) => state.loadStatus != ViewStatus.content
            ? const SizedBox.shrink()
            : StickyActions(
                primary: AppButton(
                  key: saveKey,
                  label: AppStrings.save,
                  loading: state.submitting,
                  onPressed: cubit.submit,
                ),
              ),
      ),
      body: BlocConsumer<AvailabilityFormCubit, AvailabilityFormState>(
        listenWhen: (previous, current) => current.saved != null && previous.saved == null,
        listener: (context, state) => context.pop(state.saved),
        builder: (context, state) => StateSwitcher(
          status: state.loadStatus,
          errorMessage: state.loadError,
          onRetry: cubit.load,
          loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines()),
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

class _Form extends StatelessWidget {
  const _Form({required this.state});

  final AvailabilityFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AvailabilityFormCubit>();
    final errors = state.fieldErrors;
    final sport = state.sport;
    final hint = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.muted);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        StickyActions.contentPadding,
      ),
      children: [
        const _Label(AppStrings.sportLabel),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final s in state.sports)
              AppChip(
                key: AvailabilityFormPage.sportKey(s.code),
                label: s.nameFa,
                tone: s.id == state.sportId ? AppChipTone.active : AppChipTone.neutral,
                onTap: () => cubit.sportSelected(s.id),
              ),
          ],
        ),
        _FieldError(errors[AvailabilityField.sport]),
        const _Label(AppStrings.kindLabel),
        AppSegmented<AvailabilityKind>(
          segments: [
            for (final kind in AvailabilityKind.values)
              AppSegment(value: kind, label: AvailabilityLabels.kind(kind), key: AvailabilityFormPage.kindKey(kind)),
          ],
          selected: state.kind,
          onChanged: cubit.kindSelected,
        ),
        if (state.kind == AvailabilityKind.recurring) ...[
          const _Label(AppStrings.weekdaysLabel),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final day in Weekday.values)
                AppChip(
                  key: AvailabilityFormPage.weekdayKey(day),
                  label: AvailabilityLabels.weekday(day),
                  tone: state.weekdays.contains(day) ? AppChipTone.active : AppChipTone.neutral,
                  onTap: () => cubit.weekdayToggled(day),
                ),
            ],
          ),
          _FieldError(errors[AvailabilityField.weekdays]),
          const _Label(AppStrings.validUntilLabel),
          JalaliDateSelector(
            firstYear: cubit.today.year,
            lastYear: cubit.today.year + 1,
            newestYearFirst: false,
            value: state.validUntil,
            errorText: errors[AvailabilityField.validUntil],
            onChanged: cubit.validUntilChanged,
          ),
          if (state.validUntil != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.ghost(
                label: AppStrings.validUntilClear,
                compact: true,
                expanded: false,
                onPressed: () => cubit.validUntilChanged(null),
              ),
            ),
        ] else ...[
          const _Label(AppStrings.dateLabel),
          _Dropdown<Jalali>(
            key: AvailabilityFormPage.dateKey,
            label: AppStrings.dateLabel,
            value: state.date,
            items: [for (var i = 0; i <= AvailabilityRules.maxDaysAhead; i++) cubit.today.addDays(i)],
            labelOf: _dateLabel,
            onChanged: cubit.dateSelected,
          ),
          _FieldError(errors[AvailabilityField.date]),
        ],
        const _Label(AppStrings.startTimeLabel),
        Row(
          children: [
            Expanded(
              child: _Dropdown<int>(
                key: AvailabilityFormPage.startKey,
                label: AppStrings.startTimeLabel,
                value: state.startMinute,
                items: AvailabilityRules.startOptions,
                labelOf: AvailabilityLabels.minute,
                onChanged: cubit.startSelected,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Dropdown<int>(
                key: AvailabilityFormPage.endKey,
                label: AppStrings.endTimeLabel,
                value: state.endMinute,
                items: AvailabilityRules.endOptions,
                labelOf: AvailabilityLabels.minute,
                onChanged: cubit.endSelected,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
          child: Text(AppStrings.timeHint, style: hint),
        ),
        _FieldError(errors[AvailabilityField.time]),
        const _Label(AppStrings.venuesLabel),
        Text(AppStrings.venuesHint(PersianDigits.fromInt(AvailabilityRules.maxVenues)), style: hint),
        if (state.venues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final venue in state.venues)
                InputChip(
                  label: Text(venue.name),
                  onDeleted: () => cubit.venuesChanged([...state.venues.where((v) => v.id != venue.id)]),
                ),
            ],
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.ghost(
            key: AvailabilityFormPage.venuesKey,
            label: AppStrings.chooseHomeVenues,
            icon: Icons.add_location_alt_outlined,
            expanded: false,
            onPressed: sport == null || state.cityId == null
                ? null
                : () async {
                    final venues = await VenuePicker.show(
                      context,
                      cityId: state.cityId!,
                      sportCode: sport.code,
                      maxSelection: AvailabilityRules.maxVenues,
                      initialSelection: state.venues,
                    );
                    if (venues != null) cubit.venuesChanged(venues);
                  },
          ),
        ),
        _FieldError(errors[AvailabilityField.venues]),
        if (sport != null) ...[
          const _Label(AppStrings.formatsTitle),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final format in SportRules.allowedFormats(sport))
                AppChip(
                  key: AvailabilityFormPage.formatKey(format),
                  label: ProfileLabels.format(format),
                  tone: state.formats.contains(format) ? AppChipTone.active : AppChipTone.neutral,
                  onTap: () => cubit.formatToggled(format),
                ),
            ],
          ),
          _FieldError(errors[AvailabilityField.formats]),
        ],
        const _Label(AppStrings.noteLabel),
        TextFormField(
          key: AvailabilityFormPage.noteKey,
          initialValue: state.note,
          maxLength: AvailabilityRules.maxNoteLength,
          maxLines: 3,
          minLines: 1,
          onChanged: cubit.noteChanged,
          decoration: InputDecoration(errorText: errors[AvailabilityField.note]),
        ),
        if (state.serverError case final message?)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: NoticeBanner(key: AvailabilityFormPage.serverErrorKey, tone: NoticeTone.error, body: message),
          ),
      ],
    );
  }

  static String _dateLabel(Jalali d) => PersianDigits.toPersian(
    '${JalaliFormatter.weekdayNames[d.weekDay - 1]} ${d.day} ${JalaliFormatter.monthNames[d.month - 1]} ${d.year}',
  );
}

/// A field's label, as the design's `.label`.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
    );
  }
}

/// A controlled dropdown in the app's field style.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          menuMaxHeight: 360,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ),
    );
  }
}
