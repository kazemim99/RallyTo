import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/jalali_date_text.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/search.dart';
import '../../domain/search_rules.dart';
import '../bloc/saved_searches_cubit.dart';
import '../search_labels.dart';

/// The player's saved searches, «۲ از ۵ جستجو» used: each a card with its filters, an alerts switch, run and delete;
/// tapping one runs it (the screen closes with its filters). Needs a loaded [SavedSearchesCubit] above it.
class SavedSearchesPage extends StatelessWidget {
  const SavedSearchesPage({super.key});

  static Key searchKey(String id) => Key('savedSearches.search.$id');

  static Key alertsKey(String id) => Key('savedSearches.alerts.$id');

  static Key deleteKey(String id) => Key('savedSearches.delete.$id');

  static const Key countKey = Key('savedSearches.count');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SavedSearchesCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.savedSearchesTitle)),
      body: BlocConsumer<SavedSearchesCubit, SavedSearchesState>(
        listenWhen: (previous, current) => current.feedback != null && !identical(previous.feedback, current.feedback),
        listener: (context, state) {
          final feedback = state.feedback!;
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        },
        builder: (context, state) => StateSwitcher(
          status: state.status,
          errorMessage: state.errorMessage,
          onRetry: cubit.load,
          loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines()),
          empty: const EmptyState(
            icon: Icons.bookmarks_outlined,
            title: AppStrings.savedSearchesEmptyTitle,
            subtitle: AppStrings.savedSearchesEmptySubtitle,
          ),
          contentBuilder: (context) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppChip(
                  key: countKey,
                  icon: Icons.bookmarks_outlined,
                  label: AppStrings.savedSearchCount(
                    PersianDigits.fromInt(state.searches.length),
                    PersianDigits.fromInt(SearchRules.maxSavedSearches),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final search in state.searches) _SavedSearchCard(search: search, state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSearchCard extends StatelessWidget {
  const _SavedSearchCard({required this.search, required this.state});

  final SavedSearch search;
  final SavedSearchesState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SavedSearchesCubit>();
    final theme = Theme.of(context);
    final palette = context.palette;
    final muted = theme.textTheme.bodySmall?.copyWith(color: palette.muted);
    final filters = search.filters;
    final sport = state.sportById(filters.sportId);
    final busy = state.busyId != null;
    final expires = search.expiresOn;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: AppCard(
        key: SavedSearchesPage.searchKey(search.id),
        onTap: () => context.pop(filters),
        semanticLabel: AppStrings.runSearch,
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(search.name, style: theme.textTheme.titleMedium)),
                if (search.pendingMatches > 0)
                  AppChip(
                    label: AppStrings.savedSearchPending(PersianDigits.fromInt(search.pendingMatches)),
                    tone: AppChipTone.orange,
                  ),
              ],
            ),
            Text(
              [
                sport?.nameFa ?? '',
                SearchLabels.when(filters),
                SearchLabels.time(filters),
                SearchLabels.levels(filters, sport),
              ].where((s) => s.isNotEmpty).joinDisplay(),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              [if (filters.cityName.isNotEmpty) filters.cityName, SearchLabels.venues(filters)].joinDisplay(),
              style: muted,
            ),
            if (expires != null) Text(AppStrings.savedSearchExpires(JalaliDateText.display(expires)), style: muted),
            const Divider(height: AppSpacing.lg),
            AppSwitchRow(
              key: SavedSearchesPage.alertsKey(search.id),
              title: AppStrings.alertsLabel,
              subtitle: AppStrings.savedSearchAlerts,
              value: search.alertsEnabled,
              onChanged: busy ? null : (_) => cubit.toggleAlerts(search),
            ),
            Row(
              children: [
                AppButton.ghost(
                  label: AppStrings.runSearch,
                  icon: Icons.search_rounded,
                  compact: true,
                  expanded: false,
                  onPressed: () => context.pop(filters),
                ),
                const Spacer(),
                IconButton(
                  key: SavedSearchesPage.deleteKey(search.id),
                  tooltip: AppStrings.remove,
                  icon: Icon(Icons.delete_outline_rounded, color: palette.error),
                  onPressed: busy ? null : () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<SavedSearchesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(AppStrings.savedSearchDeleteQuestion(search.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.delete(search);
  }
}
