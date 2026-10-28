import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/jalali_formatter.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../availability/domain/entities/availability_window.dart';
import '../../../availability/presentation/availability_labels.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../catalog/domain/entities/venue.dart';
import '../../../catalog/presentation/widgets/city_picker.dart';
import '../../../catalog/presentation/widgets/venue_picker.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/presentation/match_labels.dart';
import '../../../matches/presentation/widgets/form_fields.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';
import '../../../profile/domain/sport_rules.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../domain/entities/search.dart';
import '../../domain/search_rules.dart';

/// The search filters in a sheet with a handle, edited as a draft and applied together: sport, city and clubs, weekdays
/// or one date, a time range, a level range, the partner's gender (fixed for a same-gender-only player) and the format.
/// «نمایش نتایج» stays pinned under the sections.
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({
    super.key,
    required this.initial,
    required this.sports,
    required this.dateOptions,
    required this.onSportChanged,
    required this.onApply,
    this.lockedGender,
  });

  static const Key applyKey = Key('searchFilters.apply');
  static const Key cityKey = Key('searchFilters.city');
  static const Key venuesKey = Key('searchFilters.venues');
  static const Key dateKey = Key('searchFilters.date');
  static const Key fromKey = Key('searchFilters.from');
  static const Key toKey = Key('searchFilters.to');
  static const Key minLevelKey = Key('searchFilters.minLevel');
  static const Key maxLevelKey = Key('searchFilters.maxLevel');
  static const Key errorKey = Key('searchFilters.error');
  static const Key byWeekdaysKey = Key('searchFilters.byWeekdays');
  static const Key byDateKey = Key('searchFilters.byDate');

  static Key sportKey(String code) => Key('searchFilters.sport.$code');

  static Key weekdayKey(Weekday day) => Key('searchFilters.weekday.${day.name}');

  static Key genderKey(PartnerGender gender) => Key('searchFilters.gender.${gender.name}');

  static Key formatKey(PlayFormat? format) => Key('searchFilters.format.${format?.name ?? 'any'}');

  final SearchFilters initial;
  final List<Sport> sports;
  final List<Jalali> dateOptions;
  final Gender? lockedGender;

  /// The draft for another sport (its level range, no club or format).
  final SearchFilters Function(SearchFilters current, String sportId) onSportChanged;

  /// Applies the draft: the message for what is wrong with it, or null once applied (the sheet closes).
  final String? Function(SearchFilters filters) onApply;

  /// Opens the sheet over the whole app, the bottom bar included.
  static Future<void> show(
    BuildContext context, {
    required SearchFilters initial,
    required List<Sport> sports,
    required List<Jalali> dateOptions,
    required SearchFilters Function(SearchFilters current, String sportId) onSportChanged,
    required String? Function(SearchFilters filters) onApply,
    Gender? lockedGender,
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SearchFilterSheet(
      initial: initial,
      sports: sports,
      dateOptions: dateOptions,
      lockedGender: lockedGender,
      onSportChanged: onSportChanged,
      onApply: onApply,
    ),
  );

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late SearchFilters _draft = widget.initial;
  late bool _byDate = widget.initial.date != null;
  String? _error;

  Sport? get _sport {
    for (final sport in widget.sports) {
      if (sport.id == _draft.sportId) return sport;
    }
    return null;
  }

  void _update(SearchFilters draft) => setState(() {
    _draft = draft;
    _error = null;
  });

  void _apply() {
    final draft = _byDate ? _draft : _draft.copyWith(date: () => null);
    if (_byDate && draft.date == null) {
      setState(() => _error = AppStrings.dateRequired);
      return;
    }
    final error = widget.onApply(draft);
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = error);
    }
  }

  Future<void> _chooseCity() async {
    final city = await CityPicker.show(context);
    if (city == null || !mounted) return;
    _update(_draft.copyWith(cityId: () => city.cityId, cityName: city.cityName, venues: const []));
  }

  Future<void> _chooseVenues() async {
    final sport = _sport;
    final cityId = _draft.cityId;
    if (sport == null || cityId == null) return;
    final venues = await VenuePicker.show(
      context,
      cityId: cityId,
      sportCode: sport.code,
      maxSelection: SearchRules.maxVenues,
      initialSelection: [
        for (final v in _draft.venues)
          if (v.name.isNotEmpty) Venue(id: v.id, name: v.name, cityId: cityId, cityName: _draft.cityName),
      ],
    );
    if (venues == null || !mounted) return;
    _update(
      _draft.copyWith(
        venues: [for (final v in venues) NamedRef(id: v.id, name: v.name)],
      ),
    );
  }

  void _toggleWeekday(Weekday day) {
    final days = _draft.weekdays.contains(day) ? ({..._draft.weekdays}..remove(day)) : {..._draft.weekdays, day};
    _update(_draft.copyWith(weekdays: days));
  }

  void _minLevelChosen(LevelTier tier) {
    final max = _draft.maxLevel;
    _update(_draft.copyWith(minLevel: () => tier, maxLevel: () => max != null && max.index < tier.index ? tier : max));
  }

  void _maxLevelChosen(LevelTier tier) {
    final min = _draft.minLevel;
    _update(_draft.copyWith(maxLevel: () => tier, minLevel: () => min != null && min.index > tier.index ? tier : min));
  }

  void _genderChosen(PartnerGender selected) => _update(
    _draft.copyWith(
      gender: () => switch (selected) {
        PartnerGender.any => null,
        PartnerGender.male => Gender.male,
        PartnerGender.female => Gender.female,
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: context.palette.muted);
    final sport = _sport;
    final locked = widget.lockedGender;
    final gender = _draft.gender == null ? PartnerGender.any : PartnerGender.of(_draft.gender!);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.screen),
            child: SectionTitle(
              title: AppStrings.searchFilters,
              actionLabel: AppStrings.dismiss,
              onAction: () => Navigator.of(context).pop(),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
              children: [
                const FieldLabel(AppStrings.sportLabel),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in widget.sports)
                      AppChip(
                        key: SearchFilterSheet.sportKey(s.code),
                        label: s.nameFa,
                        tone: s.id == _draft.sportId ? AppChipTone.active : AppChipTone.neutral,
                        onTap: () {
                          if (s.id != _draft.sportId) _update(widget.onSportChanged(_draft, s.id));
                        },
                      ),
                  ],
                ),
                const FieldLabel(AppStrings.cityLabel),
                ListRow(
                  key: SearchFilterSheet.cityKey,
                  leading: const Icon(Icons.location_city_outlined),
                  title: _draft.cityName.isEmpty ? AppStrings.chooseCity : _draft.cityName,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _chooseCity,
                ),
                const FieldLabel(AppStrings.venuesLabel),
                Text(AppStrings.allVenuesHint, style: hint),
                if (_draft.venues.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final venue in _draft.venues)
                        InputChip(
                          label: Text(venue.name.isEmpty ? AppStrings.venueLabel : venue.name),
                          onDeleted: () =>
                              _update(_draft.copyWith(venues: [..._draft.venues.where((v) => v != venue)])),
                        ),
                    ],
                  ),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton.ghost(
                    key: SearchFilterSheet.venuesKey,
                    label: AppStrings.chooseHomeVenues,
                    icon: Icons.add_location_alt_outlined,
                    expanded: false,
                    onPressed: sport == null || _draft.cityId == null ? null : _chooseVenues,
                  ),
                ),
                const FieldLabel(AppStrings.whenLabel),
                AppSegmented<bool>(
                  segments: const [
                    AppSegment(value: false, label: AppStrings.whenWeekdays, key: SearchFilterSheet.byWeekdaysKey),
                    AppSegment(value: true, label: AppStrings.whenDate, key: SearchFilterSheet.byDateKey),
                  ],
                  selected: _byDate,
                  onChanged: (byDate) => setState(() {
                    _byDate = byDate;
                    _error = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_byDate)
                  DropdownField<Jalali>(
                    key: SearchFilterSheet.dateKey,
                    label: AppStrings.dateLabel,
                    value: _draft.date,
                    items: widget.dateOptions,
                    labelOf: _dateLabel,
                    onChanged: (date) => _update(_draft.copyWith(date: () => date)),
                  )
                else ...[
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final day in Weekday.values)
                        AppChip(
                          key: SearchFilterSheet.weekdayKey(day),
                          label: AvailabilityLabels.weekday(day),
                          tone: _draft.weekdays.contains(day) ? AppChipTone.active : AppChipTone.neutral,
                          onTap: () => _toggleWeekday(day),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(AppStrings.anyDayHint, style: hint),
                ],
                const FieldLabel(AppStrings.startTimeLabel),
                Row(
                  children: [
                    Expanded(
                      child: DropdownField<int>(
                        key: SearchFilterSheet.fromKey,
                        label: AppStrings.startTimeLabel,
                        value: _draft.fromMinute,
                        items: SearchRules.fromOptions,
                        labelOf: AvailabilityLabels.minute,
                        onChanged: (m) => _update(_draft.copyWith(fromMinute: m)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownField<int>(
                        key: SearchFilterSheet.toKey,
                        label: AppStrings.endTimeLabel,
                        value: _draft.toMinute,
                        items: SearchRules.toOptions,
                        labelOf: AvailabilityLabels.minute,
                        onChanged: (m) => _update(_draft.copyWith(toMinute: m)),
                      ),
                    ),
                  ],
                ),
                const FieldLabel(AppStrings.levelsLabel),
                Row(
                  children: [
                    Expanded(
                      child: DropdownField<LevelTier>(
                        key: SearchFilterSheet.minLevelKey,
                        label: AppStrings.levelFrom,
                        value: _draft.minLevel,
                        items: LevelTier.values,
                        labelOf: (t) => MatchLabels.level(t, sport),
                        onChanged: _minLevelChosen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownField<LevelTier>(
                        key: SearchFilterSheet.maxLevelKey,
                        label: AppStrings.levelTo,
                        value: _draft.maxLevel,
                        items: LevelTier.values,
                        labelOf: (t) => MatchLabels.level(t, sport),
                        onChanged: _maxLevelChosen,
                      ),
                    ),
                  ],
                ),
                const FieldLabel(AppStrings.partnerGenderLabel),
                AppSegmented<PartnerGender>(
                  segments: [
                    for (final g in PartnerGender.values)
                      AppSegment(value: g, label: MatchLabels.partnerGender(g), key: SearchFilterSheet.genderKey(g)),
                  ],
                  selected: locked == null ? gender : PartnerGender.of(locked),
                  onChanged: locked != null ? null : _genderChosen,
                ),
                if (locked != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                    child: Text(AppStrings.genderLockedHint, style: hint),
                  ),
                if (sport != null) ...[
                  const FieldLabel(AppStrings.formatsTitle),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final format in <PlayFormat?>[null, ...SportRules.allowedFormats(sport)])
                        AppChip(
                          key: SearchFilterSheet.formatKey(format),
                          label: format == null ? AppStrings.formatAny : ProfileLabels.format(format),
                          tone: _draft.format == format ? AppChipTone.active : AppChipTone.neutral,
                          onTap: () => _update(_draft.copyWith(format: () => format)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screen,
              AppSpacing.xs,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Next to the button, so it is seen wherever the sections are scrolled to.
                if (_error case final error?) ...[
                  ErrorBox(error, key: SearchFilterSheet.errorKey),
                  const SizedBox(height: AppSpacing.xs),
                ],
                AppButton(key: SearchFilterSheet.applyKey, label: AppStrings.searchShowResults, onPressed: _apply),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(Jalali d) => PersianDigits.toPersian(
    '${JalaliFormatter.weekdayNames[d.weekDay - 1]} ${d.day} ${JalaliFormatter.monthNames[d.month - 1]} ${d.year}',
  );
}
