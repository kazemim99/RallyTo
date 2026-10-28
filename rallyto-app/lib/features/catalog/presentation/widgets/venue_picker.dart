import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/venue.dart';
import '../bloc/catalog_load_status.dart';
import '../bloc/venue_picker_cubit.dart';
import 'catalog_search_field.dart';
import 'check_mark.dart';
import 'venue_sport_tags.dart';

/// Venue search in a city, with multi-select up to a limit: the selection shows as chips above the results, and
/// each result shows its sports as tags («تنیس ۶ زمین»). Needs a started [VenuePickerCubit] above it;
/// [VenuePicker.show] opens it as a full screen and returns the selection.
class VenuePicker extends StatefulWidget {
  const VenuePicker({super.key, required this.onConfirm});

  static const Key searchFieldKey = Key('venuePicker.search');
  static const Key confirmKey = Key('venuePicker.confirm');

  /// The key of [venue]'s row in the results.
  static Key resultKey(String venueId) => Key('venuePicker.result.$venueId');

  /// The key of [venue]'s chip in the selection.
  static Key chipKey(String venueId) => Key('venuePicker.chip.$venueId');

  final ValueChanged<List<Venue>> onConfirm;

  /// Opens the picker over the current screen; null when the player leaves without confirming.
  static Future<List<Venue>?> show(
    BuildContext context, {
    required int cityId,
    String? sportCode,
    int maxSelection = 1,
    List<Venue> initialSelection = const [],
  }) {
    final args = VenuePickerArgs(
      cityId: cityId,
      sportCode: sportCode,
      maxSelection: maxSelection,
      initialSelection: initialSelection,
    );
    return Navigator.of(context, rootNavigator: true).push<List<Venue>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => BlocProvider(
          create: (_) => getIt<VenuePickerCubit>(param1: args)..start(),
          child: Scaffold(
            appBar: AppBar(title: const Text(AppStrings.venuePickerTitle)),
            body: VenuePicker(onConfirm: (venues) => Navigator.of(context).pop(venues)),
          ),
        ),
      ),
    );
  }

  @override
  State<VenuePicker> createState() => _VenuePickerState();
}

class _VenuePickerState extends State<VenuePicker> {
  late final TextEditingController _search = TextEditingController(text: context.read<VenuePickerCubit>().state.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VenuePickerCubit>();
    return BlocConsumer<VenuePickerCubit, VenuePickerState>(
      listenWhen: (previous, current) => current.limitHits > previous.limitHits,
      listener: (context, state) =>
          AppSnackbar.info(context, AppStrings.venueSelectionLimit(PersianDigits.fromInt(state.maxSelection))),
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CatalogSearchField(
              key: VenuePicker.searchFieldKey,
              controller: _search,
              hint: AppStrings.venueSearchHint,
              onChanged: cubit.queryChanged,
            ),
            if (state.selected.isNotEmpty) _SelectedChips(selected: state.selected, onRemove: cubit.toggle),
            if (state.status == CatalogLoadStatus.loading && state.results.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _results(context, state)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screen,
                  AppSpacing.xs,
                  AppSpacing.screen,
                  AppSpacing.md,
                ),
                child: AppButton(
                  key: VenuePicker.confirmKey,
                  label: AppStrings.venueConfirm(
                    PersianDigits.fromInt(state.selected.length),
                    PersianDigits.fromInt(state.maxSelection),
                  ),
                  onPressed: () => widget.onConfirm(List.unmodifiable(state.selected)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _results(BuildContext context, VenuePickerState state) {
    final cubit = context.read<VenuePickerCubit>();
    if (state.status == CatalogLoadStatus.failure) {
      return ErrorState(message: state.errorMessage, onRetry: cubit.retry);
    }
    if (state.results.isEmpty) {
      return state.status == CatalogLoadStatus.loading
          ? const LoadingView()
          : const EmptyState(
              icon: Icons.search_off,
              title: AppStrings.venuesEmptyTitle,
              subtitle: AppStrings.venuesEmptySubtitle,
            );
    }
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final venue = state.results[index];
        return _VenueRow(
          key: VenuePicker.resultKey(venue.id),
          venue: venue,
          sportNames: state.sportNames,
          selected: state.isSelected(venue.id),
          onTap: () => cubit.toggle(venue),
        );
      },
    );
  }
}

/// One result: a check, the venue's name, address and sport tags, on a list-row card that turns soft green with a
/// 2dp green border when chosen (the design's selectable card). Read out as a checkbox.
class _VenueRow extends StatelessWidget {
  const _VenueRow({
    super.key,
    required this.venue,
    required this.sportNames,
    required this.selected,
    required this.onTap,
  });

  final Venue venue;
  final Map<String, String> sportNames;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      checked: selected,
      child: Material(
        color: selected ? palette.primarySoft : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          side: BorderSide(color: selected ? palette.primary : palette.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
            child: Padding(
              // One dp less when the border is 2dp, so the content does not shift.
              padding: EdgeInsetsDirectional.all(selected ? 12 : 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: CheckMark(checked: selected)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(venue.name, style: theme.textTheme.titleSmall),
                        Text(
                          venue.address ?? venue.cityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                        if (venue.sports.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          VenueSportTags(sports: venue.sports, sportNames: sportNames),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({required this.selected, required this.onRemove});

  final List<Venue> selected;
  final ValueChanged<Venue> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: [
          for (final venue in selected)
            InputChip(
              key: VenuePicker.chipKey(venue.id),
              label: Text(venue.name, overflow: TextOverflow.ellipsis),
              onDeleted: () => onRemove(venue),
            ),
        ],
      ),
    );
  }
}
