import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/match.dart';
import '../../domain/match_rules.dart';
import '../bloc/my_matches_cubit.dart';
import '../widgets/match_card.dart';

/// Which of a tab's games are shown: the design's status chips.
enum MatchStatusFilter {
  all,
  confirmed,
  waiting,
  played,
  cancelled;

  bool admits(MatchStatus status) => switch (this) {
    all => true,
    confirmed => status == MatchStatus.confirmed,
    waiting => status == MatchStatus.open || status == MatchStatus.pending,
    played => status == MatchStatus.completed || status == MatchStatus.disputed || status == MatchStatus.unconfirmed,
    cancelled => status == MatchStatus.cancelled || status == MatchStatus.expired,
  };

  String get label => switch (this) {
    all => AppStrings.matchFilterAll,
    confirmed => AppStrings.matchFilterConfirmed,
    waiting => AppStrings.matchFilterWaiting,
    played => AppStrings.matchFilterPlayed,
    cancelled => AppStrings.matchFilterCancelled,
  };

  static const List<MatchStatusFilter> upcoming = [all, confirmed, waiting];
  static const List<MatchStatusFilter> past = [all, played, cancelled];
}

/// The player's games (design `Matches`): a segmented control for upcoming (with its count) and past games, status
/// chips, the game cards, and a dashed row to open a game from a share link; a new play post from the top bar. Needs
/// a loaded [MyMatchesCubit] above it; it reloads when the player comes back from a game.
class MyMatchesPage extends StatefulWidget {
  const MyMatchesPage({super.key});

  static const Key newPostKey = Key('myMatches.newPost');
  static const Key openLinkKey = Key('myMatches.openLink');
  static const Key linkFieldKey = Key('myMatches.linkField');
  static const Key openLinkConfirmKey = Key('myMatches.openLinkConfirm');
  static const Key upcomingTabKey = Key('myMatches.upcoming');
  static const Key pastTabKey = Key('myMatches.past');
  static const Key filterEmptyKey = Key('myMatches.filterEmpty');

  static Key matchKey(String id) => Key('myMatches.match.$id');

  static Key filterKey(MatchStatusFilter filter) => Key('myMatches.filter.${filter.name}');

  @override
  State<MyMatchesPage> createState() => _MyMatchesPageState();
}

class _MyMatchesPageState extends State<MyMatchesPage> {
  bool _past = false;
  MatchStatusFilter _filter = MatchStatusFilter.all;

  Future<void> _push(String location) async {
    final cubit = context.read<MyMatchesCubit>();
    await context.push(location);
    if (!cubit.isClosed) await cubit.load();
  }

  Future<void> _openLink() async {
    final token = await showDialog<String>(context: context, builder: (_) => const _OpenLinkDialog());
    if (token != null && mounted) await _push(Routes.sharedMatchPath(token));
  }

  void _showTab(bool past) => setState(() {
    _past = past;
    _filter = MatchStatusFilter.all;
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MyMatchesCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myMatchesTitle),
        actions: [
          IconButton(
            key: MyMatchesPage.newPostKey,
            tooltip: AppStrings.newPost,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _push(Routes.matchNew),
          ),
        ],
      ),
      body: BlocBuilder<MyMatchesCubit, MyMatchesState>(
        builder: (context, state) {
          final list = _past ? state.past : state.upcoming;
          final upcoming = state.upcoming;
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              children: [
                AppSegmented<bool>(
                  segments: [
                    AppSegment(
                      key: MyMatchesPage.upcomingTabKey,
                      value: false,
                      label: upcoming.status == ViewStatus.content
                          ? AppStrings.upcomingCount(PersianDigits.fromInt(upcoming.matches.length))
                          : AppStrings.upcomingMatches,
                    ),
                    const AppSegment(key: MyMatchesPage.pastTabKey, value: true, label: AppStrings.pastMatches),
                  ],
                  selected: _past,
                  onChanged: _showTab,
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._body(context, state, list),
                const SizedBox(height: AppSpacing.sm),
                _PasteLinkRow(onOpen: _openLink),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _body(BuildContext context, MyMatchesState state, MatchList list) {
    final cubit = context.read<MyMatchesCubit>();
    switch (list.status) {
      case ViewStatus.loading:
        return const [
          SkeletonBlock(height: 150, radius: AppRadius.card, pulse: true),
          SizedBox(height: AppSpacing.sm),
          SkeletonBlock(height: 150, radius: AppRadius.card, pulse: true),
        ];
      case ViewStatus.error:
        return [ErrorState(message: list.errorMessage, onRetry: cubit.load)];
      case ViewStatus.empty:
        return [
          _past
              ? const EmptyState(icon: Icons.history, title: AppStrings.pastEmptyTitle)
              : EmptyState(
                  icon: Icons.sports_tennis,
                  title: AppStrings.upcomingEmptyTitle,
                  subtitle: AppStrings.upcomingEmptySubtitle,
                  ctaLabel: AppStrings.searchTitle,
                  onCta: () => _push(Routes.search),
                ),
        ];
      case ViewStatus.content:
        final shown = [
          for (final match in list.matches)
            if (_filter.admits(match.status)) match,
        ];
        return [
          Wrap(
            spacing: AppSpacing.xs - 2,
            children: [
              for (final filter in _past ? MatchStatusFilter.past : MatchStatusFilter.upcoming)
                AppChip(
                  key: MyMatchesPage.filterKey(filter),
                  label: filter.label,
                  tone: filter == _filter ? AppChipTone.active : AppChipTone.neutral,
                  onTap: () => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (shown.isEmpty)
            EmptyState(
              key: MyMatchesPage.filterEmptyKey,
              icon: Icons.filter_alt_off_outlined,
              title: AppStrings.matchFilterEmpty,
              ctaLabel: AppStrings.matchFilterShowAll,
              onCta: () => setState(() => _filter = MatchStatusFilter.all),
            ),
          for (final match in shown)
            MatchCard(
              key: MyMatchesPage.matchKey(match.id),
              match: match,
              sport: state.sportById(match.sport.id),
              onTap: () => _push(Routes.matchPath(match.id)),
            ),
        ];
    }
  }
}

/// The design's `.paste-link`: a dashed row that opens a game from a share link someone sent.
class _PasteLinkRow extends StatelessWidget {
  const _PasteLinkRow({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return CustomPaint(
      painter: DashedBorderPainter(color: palette.line, radius: AppRadius.tile),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.md, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xxs),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: palette.primary, size: AppIconSize.md),
            const SizedBox(width: AppSpacing.sm - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.pasteLinkTitle, style: theme.textTheme.titleSmall),
                  Text(AppStrings.pasteLinkSubtitle, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
                ],
              ),
            ),
            AppButton.ghost(
              key: MyMatchesPage.openLinkKey,
              label: AppStrings.pasteLinkAction,
              expanded: false,
              compact: true,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a share link (or its token) and answers with the token, or nothing when it is not one.
class _OpenLinkDialog extends StatefulWidget {
  const _OpenLinkDialog();

  @override
  State<_OpenLinkDialog> createState() => _OpenLinkDialogState();
}

class _OpenLinkDialogState extends State<_OpenLinkDialog> {
  final TextEditingController _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _submit() {
    final token = ShareLinks.tokenOf(_link.text);
    if (token == null) {
      setState(() => _error = AppStrings.shareLinkNotRecognised);
      return;
    }
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.openShareLink),
      content: TextField(
        key: MyMatchesPage.linkFieldKey,
        controller: _link,
        autofocus: true,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: AppStrings.shareLinkLabel,
          hintText: AppStrings.shareLinkHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(AppStrings.cancel)),
        TextButton(key: MyMatchesPage.openLinkConfirmKey, onPressed: _submit, child: const Text(AppStrings.open)),
      ],
    );
  }
}
