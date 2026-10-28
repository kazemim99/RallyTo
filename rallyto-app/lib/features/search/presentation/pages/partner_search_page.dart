import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/presentation/profile_labels.dart';
import '../../domain/entities/search.dart';
import '../../domain/search_rules.dart';
import '../bloc/partner_search_cubit.dart';
import '../search_labels.dart';
import '../widgets/open_post_card.dart';
import '../widgets/partner_result_card.dart';
import '../widgets/search_filter_sheet.dart';

/// Partner search: the filter button (a sheet), the active filters as chips (each opens the sheet), the result type,
/// open posts (first page) and ranked player cards with their overlapping window, and more players page by page.
/// Saving the current filters and the saved searches are in the app bar. Needs a [PartnerSearchCubit] above it
/// (loaded).
class PartnerSearchPage extends StatelessWidget {
  const PartnerSearchPage({super.key});

  static const Key filtersKey = Key('partnerSearch.filters');
  static const Key saveKey = Key('partnerSearch.save');
  static const Key savedSearchesKey = Key('partnerSearch.saved');
  static const Key loadMoreKey = Key('partnerSearch.loadMore');
  static const Key saveNameKey = Key('partnerSearch.saveName');
  static const Key saveAlertsKey = Key('partnerSearch.saveAlerts');
  static const Key saveConfirmKey = Key('partnerSearch.saveConfirm');
  static const Key summaryKey = Key('partnerSearch.summary');

  /// The profile tab, where a sport profile is added.
  static const int profileTab = 4;

  static Key playerKey(String userId) => Key('partnerSearch.player.$userId');

  static Key postKey(String id) => Key('partnerSearch.post.$id');

  static Key resultTypeKey(SearchResultType type) => Key('partnerSearch.resultType.${type.name}');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PartnerSearchCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.searchTitle),
        actions: [
          IconButton(
            key: savedSearchesKey,
            tooltip: AppStrings.savedSearchesTitle,
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => _openSaved(context),
          ),
          BlocBuilder<PartnerSearchCubit, PartnerSearchState>(
            buildWhen: (previous, current) => previous.filters != current.filters,
            builder: (context, state) => IconButton(
              key: saveKey,
              tooltip: AppStrings.saveSearch,
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: state.filters == null ? null : () => _save(context),
            ),
          ),
          BlocBuilder<PartnerSearchCubit, PartnerSearchState>(
            buildWhen: (previous, current) => previous.filters != current.filters,
            builder: (context, state) => IconButton(
              key: filtersKey,
              tooltip: AppStrings.searchFilters,
              icon: const Icon(Icons.tune_rounded),
              onPressed: state.filters == null ? null : () => openFilters(context),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: BlocConsumer<PartnerSearchCubit, PartnerSearchState>(
        listenWhen: (previous, current) => current.feedback != null && !identical(previous.feedback, current.feedback),
        listener: (context, state) {
          final feedback = state.feedback!;
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        },
        builder: (context, state) => StateSwitcher(
          status: state.setupStatus,
          errorMessage: state.setupError,
          onRetry: cubit.load,
          loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines()),
          empty: EmptyState(
            icon: Icons.sports_tennis,
            title: AppStrings.noSportProfiles,
            ctaLabel: AppStrings.myProfileTitle,
            onCta: () => _openProfile(context),
          ),
          contentBuilder: (context) => _Results(state: state),
        ),
      ),
    );
  }

  static void openFilters(BuildContext context) {
    final cubit = context.read<PartnerSearchCubit>();
    final state = cubit.state;
    final filters = state.filters;
    if (filters == null) return;
    SearchFilterSheet.show(
      context,
      initial: filters,
      sports: state.sports,
      dateOptions: cubit.dateOptions,
      lockedGender: state.lockedGender,
      onSportChanged: cubit.filtersForSport,
      onApply: cubit.applyFilters,
    );
  }

  static void _openProfile(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(profileTab);
    } else {
      context.push(Routes.profile);
    }
  }

  Future<void> _openSaved(BuildContext context) async {
    final cubit = context.read<PartnerSearchCubit>();
    final filters = await context.push<SearchFilters>(Routes.savedSearches);
    if (filters != null && !cubit.isClosed) cubit.applyFilters(filters);
  }

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<PartnerSearchCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => _SaveDialog(onSave: cubit.saveSearch),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state});

  final PartnerSearchState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PartnerSearchCubit>();
    final players = state.players;
    final posts = state.posts;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
      children: [
        _ActiveFilters(state: state),
        const SizedBox(height: AppSpacing.sm),
        AppSegmented<SearchResultType>(
          segments: [
            for (final type in SearchResultType.values)
              AppSegment(value: type, label: _typeLabel(type), key: PartnerSearchPage.resultTypeKey(type)),
          ],
          selected: state.resultType,
          onChanged: cubit.resultTypeSelected,
        ),
        switch (state.resultsStatus) {
          ViewStatus.loading => const _ResultsSkeleton(),
          ViewStatus.error => Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
            child: ErrorState(message: state.resultsError, onRetry: cubit.search),
          ),
          ViewStatus.empty => _empty(context),
          ViewStatus.content =>
            players.isEmpty && posts.isEmpty
                ? _empty(context)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (posts.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.section),
                        const SectionTitle(
                          title: AppStrings.searchOpenPostsTitle,
                          subtitle: AppStrings.searchOpenPostsSubtitle,
                        ),
                        for (final post in posts)
                          OpenPostCard(
                            key: PartnerSearchPage.postKey(post.id),
                            match: post,
                            sport: state.sport,
                            now: cubit.now,
                            onTap: () => context.push(Routes.matchPath(post.id)),
                          ),
                      ],
                      if (players.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.section),
                        const SectionTitle(
                          title: AppStrings.searchPlayersTitle,
                          subtitle: AppStrings.searchPlayersSubtitle,
                        ),
                        for (final player in players)
                          PartnerResultCard(
                            key: PartnerSearchPage.playerKey(player.userId),
                            result: player,
                            onTap: () => context.push(Routes.playerPath(player.userId)),
                            onInvite: () =>
                                context.push(Routes.invitePlayerPath(player.userId), extra: player.displayName),
                            onMessage: () =>
                                context.push(Routes.playerChatPath(player.userId), extra: player.displayName),
                          ),
                        if (state.hasMore && state.resultType != SearchResultType.posts)
                          AppButton.secondary(
                            key: PartnerSearchPage.loadMoreKey,
                            label: AppStrings.loadMore,
                            loading: state.loadingMore,
                            onPressed: cubit.loadMore,
                          ),
                      ],
                    ],
                  ),
        },
      ],
    );
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xl),
    child: EmptyState(
      icon: Icons.person_search_outlined,
      title: AppStrings.searchEmptyTitle,
      subtitle: AppStrings.searchEmptySubtitle,
      ctaLabel: AppStrings.searchFilters,
      onCta: () => PartnerSearchPage.openFilters(context),
    ),
  );

  static String _typeLabel(SearchResultType type) => switch (type) {
    SearchResultType.both => AppStrings.resultTypeBoth,
    SearchResultType.players => AppStrings.resultTypePlayers,
    SearchResultType.posts => AppStrings.resultTypePosts,
  };
}

/// The filters in force as a row of chips: the sport, when, the levels, where, and the format when one is chosen. The
/// ones narrowed from the defaults are filled. Each chip opens the filter sheet.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.state});

  final PartnerSearchState state;

  @override
  Widget build(BuildContext context) {
    final filters = state.filters!;
    final sport = state.sport;
    final narrowedWhen = filters.date != null || filters.weekdays.isNotEmpty || !filters.isWholeDay;
    final levels = SearchLabels.levels(filters, sport);
    final where = [if (filters.cityName.isNotEmpty) filters.cityName, SearchLabels.venues(filters)].joinDisplay();
    final chips = [
      if (sport != null) (sport.nameFa, true),
      ([SearchLabels.when(filters), SearchLabels.time(filters)].joinDisplay(), narrowedWhen),
      if (levels.isNotEmpty) (levels, false),
      (where, filters.venues.isNotEmpty),
      if (filters.format case final format?) (ProfileLabels.format(format), true),
    ];
    void open() => PartnerSearchPage.openFilters(context);
    return SingleChildScrollView(
      key: PartnerSearchPage.summaryKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          for (final (label, active) in chips) ...[
            AppChip(label: label, tone: active ? AppChipTone.active : AppChipTone.neutral, onTap: open),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Two card-shaped placeholders while the results load.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: AppSpacing.section),
        AppCard(child: SkeletonLines(count: 4)),
        SizedBox(height: AppSpacing.sm),
        AppCard(child: SkeletonLines(count: 4)),
      ],
    );
  }
}

/// Names the current search and saves it, with alerts on by default.
class _SaveDialog extends StatefulWidget {
  const _SaveDialog({required this.onSave});

  final Future<String?> Function(String name, {bool alertsEnabled}) onSave;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  final TextEditingController _name = TextEditingController();
  bool _alerts = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final error = await widget.onSave(_name.text, alertsEnabled: _alerts);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.saveSearchTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: PartnerSearchPage.saveNameKey,
            controller: _name,
            autofocus: true,
            maxLength: SearchRules.maxNameLength,
            decoration: InputDecoration(labelText: AppStrings.savedSearchNameLabel, errorText: _error),
          ),
          AppSwitchRow(
            key: PartnerSearchPage.saveAlertsKey,
            title: AppStrings.savedSearchAlerts,
            value: _alerts,
            onChanged: (value) => setState(() => _alerts = value),
          ),
        ],
      ),
      actions: [
        AppButton.ghost(label: AppStrings.cancel, expanded: false, onPressed: () => Navigator.of(context).pop()),
        AppButton(
          key: PartnerSearchPage.saveConfirmKey,
          label: AppStrings.save,
          expanded: false,
          loading: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
