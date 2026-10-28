import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/utils/persian_digits.dart';
import '../../../../core/utils/tehran_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../availability/domain/availability_rules.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../reports/domain/entities/report.dart';
import '../../../search/domain/entities/search.dart';
import '../../domain/entities/match.dart';
import '../../domain/match_rules.dart';
import '../bloc/match_detail_cubit.dart';
import '../match_labels.dart';
import '../widgets/match_card.dart';

/// One game (design `Match`): a dark cover with the sport and format, the status, a title, the club, the day and
/// time and this player's place; a stat grid (duration, level, court); the players with the host's mini actions on
/// join requests (out-of-range ones marked); the «درباره بازی» card with the cost and a cancelled game's reason; the
/// share link; and the actions this player's place allows, the two main ones pinned at the bottom. Once the game
/// ended: the attendance question (played, did not happen, no-shows), its outcome, and the players still to rate.
/// The overflow menu holds a new share link (host) and reporting the post (others). Needs a loaded
/// [MatchDetailCubit] above it.
class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({super.key});

  static const Key joinKey = Key('matchDetail.join');
  static const Key withdrawKey = Key('matchDetail.withdraw');
  static const Key acceptInvitationKey = Key('matchDetail.acceptInvitation');
  static const Key declineInvitationKey = Key('matchDetail.declineInvitation');
  static const Key confirmEarlyKey = Key('matchDetail.confirmEarly');
  static const Key leaveKey = Key('matchDetail.leave');
  static const Key cancelKey = Key('matchDetail.cancel');
  static const Key inviteKey = Key('matchDetail.invite');
  static const Key copyLinkKey = Key('matchDetail.copyLink');
  static const Key regenerateKey = Key('matchDetail.regenerate');
  static const Key dialogTextKey = Key('matchDetail.dialogText');
  static const Key dialogConfirmKey = Key('matchDetail.dialogConfirm');
  static const Key lateWarningKey = Key('matchDetail.lateWarning');
  static const Key cancelReasonKey = Key('matchDetail.cancelReason');
  static const Key groupChatKey = Key('matchDetail.groupChat');
  static const Key messageKey = Key('matchDetail.message');
  static const Key shareKey = Key('matchDetail.share');
  static const Key reportPostKey = Key('matchDetail.reportPost');
  static const Key attendanceKey = Key('matchDetail.attendance');
  static const Key attendancePlayedKey = Key('matchDetail.attendancePlayed');
  static const Key attendanceDidNotHappenKey = Key('matchDetail.attendanceDidNotHappen');
  static const Key submitAttendanceKey = Key('matchDetail.submitAttendance');
  static const Key attendanceAnswerKey = Key('matchDetail.attendanceAnswer');
  static const Key attendanceOutcomeKey = Key('matchDetail.attendanceOutcome');
  static const Key resolutionKey = Key('matchDetail.resolution');
  static const Key rateSectionKey = Key('matchDetail.rateSection');
  static const Key coverKey = Key('matchDetail.cover');
  static const Key overflowKey = Key('matchDetail.overflow');
  static const Key confirmedBannerKey = Key('matchDetail.confirmedBanner');
  static const Key lateNoticeKey = Key('matchDetail.lateNotice');
  static const Key policyNoticeKey = Key('matchDetail.policyNotice');
  static const Key stickyActionsKey = Key('matchDetail.stickyActions');

  static Key noShowKey(String userId) => Key('matchDetail.noShow.$userId');

  static Key rateKey(String userId) => Key('matchDetail.rate.$userId');

  static Key acceptRequestKey(String userId) => Key('matchDetail.acceptRequest.$userId');

  static Key declineRequestKey(String userId) => Key('matchDetail.declineRequest.$userId');

  static Key removeKey(String userId) => Key('matchDetail.remove.$userId');

  static Key participantKey(String userId) => Key('matchDetail.participant.$userId');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchDetailCubit>();
    return BlocConsumer<MatchDetailCubit, MatchDetailState>(
      listenWhen: (previous, current) => current.feedback != null && !identical(previous.feedback, current.feedback),
      listener: (context, state) {
        final feedback = state.feedback!;
        feedback.isError
            ? AppSnackbar.error(context, feedback.message)
            : AppSnackbar.success(context, feedback.message);
      },
      builder: (context, state) {
        final match = state.status == ViewStatus.content ? state.match : null;
        final plan = match == null ? null : _ActionPlan.of(context, state);
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: const Text(AppStrings.matchTitle),
            actions: [if (match != null) _OverflowMenu(match: match, busy: state.busy)],
          ),
          bottomNavigationBar: plan == null || plan.pinned.isEmpty
              ? null
              : StickyActions(
                  key: stickyActionsKey,
                  primary: plan.pinned.first,
                  secondary: plan.pinned.length > 1 ? plan.pinned[1] : null,
                ),
          body: state.status == ViewStatus.error && state.notFound
              ? EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: state.errorMessage ?? AppStrings.matchNotAvailable,
                  ctaLabel: AppStrings.backToHome,
                  onCta: () => context.go(Routes.home),
                )
              : StateSwitcher(
                  status: state.status,
                  errorMessage: state.errorMessage,
                  onRetry: cubit.load,
                  loading: const Padding(
                    padding: EdgeInsetsDirectional.all(AppSpacing.screen),
                    child: SkeletonLines(count: 6, pulse: true),
                  ),
                  contentBuilder: (context) => _Content(state: state, plan: plan!),
                ),
        );
      },
    );
  }

  /// Opens the search with this game's sport, day, time, club and levels, to find someone to invite.
  static Future<void> _invite(BuildContext context, Match match) async {
    final cubit = context.read<MatchDetailCubit>();
    final from = TimeOfDayText.tryParse(match.startTime) ?? 0;
    final to = TimeOfDayText.tryParse(match.endTime) ?? SearchFilters.endOfDay;
    final filters = SearchFilters(
      sportId: match.sport.id,
      venues: [NamedRef(id: match.venue.id, name: match.venue.name)],
      date: match.jalaliDate,
      fromMinute: from,
      toMinute: to > from ? to : SearchFilters.endOfDay,
      minLevel: match.minLevel,
      maxLevel: match.maxLevel,
      format: match.format,
    );
    await context.push(Routes.search, extra: filters);
    if (!cubit.isClosed) await cubit.load();
  }

  static Future<void> _join(BuildContext context) async {
    final cubit = context.read<MatchDetailCubit>();
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _TextDialog(
        title: AppStrings.joinTitle,
        label: AppStrings.joinMessageLabel,
        confirm: AppStrings.send,
        maxLength: MatchRules.maxMessageLength,
      ),
    );
    if (message != null) await cubit.join(message: message);
  }

  static Future<void> _leave(BuildContext context) async {
    final cubit = context.read<MatchDetailCubit>();
    await _confirm(context, AppStrings.leaveQuestion, AppStrings.leave, cubit.leave, late: cubit.isLateCancellation);
  }

  static Future<void> _cancel(BuildContext context) async {
    final cubit = context.read<MatchDetailCubit>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: AppStrings.cancelMatchQuestion,
        label: AppStrings.cancelReasonLabel,
        confirm: AppStrings.cancelMatch,
        warning: cubit.isLateCancellation,
      ),
    );
    if (reason != null) await cubit.cancel(reason: reason);
  }

  static Future<void> _remove(BuildContext context, MatchParticipant p) async {
    final cubit = context.read<MatchDetailCubit>();
    await _confirm(
      context,
      AppStrings.removeParticipantQuestion(p.displayName),
      AppStrings.remove,
      () => cubit.removeParticipant(p.userId),
    );
  }

  /// Reports the post; when its host was blocked too, the game is loaded again (it may no longer be visible).
  static Future<void> _reportPost(BuildContext context, Match match) async {
    final cubit = context.read<MatchDetailCubit>();
    final blocked = await context.push<bool>(
      Routes.report,
      extra: ReportTarget.post(match.id, hostName: match.host.displayName),
    );
    if (blocked == true && !cubit.isClosed) await cubit.load();
  }

  static Future<void> _confirm(
    BuildContext context,
    String question,
    String confirm,
    Future<void> Function() action, {
    bool late = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(question),
            if (late) ...[const SizedBox(height: AppSpacing.sm), const _LateWarning()],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.keep)),
          TextButton(
            key: dialogConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }
}

/// The actions this player's place allows, most important first: the first two are pinned at the bottom
/// ([pinned]), the rest sit in the page ([inline]), and leaving or cancelling stays in the page, away from the thumb
/// ([destructive]).
class _ActionPlan {
  const _ActionPlan({required this.pinned, required this.inline, required this.destructive});

  final List<Widget> pinned;
  final List<Widget> inline;
  final List<Widget> destructive;

  static _ActionPlan of(BuildContext context, MatchDetailState state) {
    final cubit = context.read<MatchDetailCubit>();
    final match = state.match!;
    final now = cubit.now;
    final busy = state.busy;
    final partner = directPartner(match);
    final groupChatId = state.groupChatId;
    final ranked = <Widget>[
      if (match.canAnswerInvitation(now)) ...[
        AppButton(
          key: MatchDetailPage.acceptInvitationKey,
          label: AppStrings.acceptInvitation,
          loading: busy,
          onPressed: cubit.acceptInvitation,
        ),
        AppButton.ghost(
          key: MatchDetailPage.declineInvitationKey,
          label: AppStrings.declineInvitation,
          onPressed: busy ? null : cubit.declineInvitation,
        ),
      ],
      if (match.canJoin(now))
        AppButton(
          key: MatchDetailPage.joinKey,
          label: AppStrings.join,
          icon: Icons.how_to_reg_outlined,
          loading: busy,
          onPressed: () => MatchDetailPage._join(context),
        ),
      if (match.canWithdraw)
        AppButton.secondary(
          key: MatchDetailPage.withdrawKey,
          label: AppStrings.withdraw,
          loading: busy,
          onPressed: cubit.withdraw,
        ),
      if (match.canConfirmEarly(now) && match.openSpots > 0)
        AppButton(
          key: MatchDetailPage.confirmEarlyKey,
          label: AppStrings.confirmEarly,
          icon: Icons.verified_outlined,
          onPressed: busy
              ? null
              : () => MatchDetailPage._confirm(
                  context,
                  AppStrings.confirmEarlyQuestion,
                  AppStrings.confirmEarly,
                  cubit.confirmEarly,
                ),
        ),
      if (match.canInvite(now))
        AppButton.secondary(
          key: MatchDetailPage.inviteKey,
          label: AppStrings.invitePlayers,
          icon: Icons.person_add_alt,
          onPressed: busy ? null : () => MatchDetailPage._invite(context, match),
        ),
      if (groupChatId != null)
        AppButton.secondary(
          key: MatchDetailPage.groupChatKey,
          label: AppStrings.matchGroupChat,
          icon: Icons.forum_outlined,
          onPressed: () => context.push(Routes.chatPath(groupChatId)),
        ),
      if (partner != null)
        AppButton.secondary(
          key: MatchDetailPage.messageKey,
          // Short, as in the design: a pinned half-width button has no room for the name, which the page already shows.
          label: AppStrings.messageShort,
          icon: Icons.chat_bubble_outline,
          onPressed: () => context.push(Routes.playerChatPath(partner.userId), extra: partner.displayName),
        ),
    ];
    return _ActionPlan(
      pinned: ranked.take(2).toList(),
      inline: ranked.skip(2).toList(),
      destructive: [
        if (match.canLeave(now))
          AppButton.danger(
            key: MatchDetailPage.leaveKey,
            label: AppStrings.leave,
            onPressed: busy ? null : () => MatchDetailPage._leave(context),
          ),
        if (match.canCancel(now))
          AppButton.danger(
            key: MatchDetailPage.cancelKey,
            label: AppStrings.cancelMatch,
            onPressed: busy ? null : () => MatchDetailPage._cancel(context),
          ),
      ],
    );
  }

  /// Who this player can message about the game in a direct conversation: the host, for anyone else; for the host
  /// of a two-player game, the other player. Null when there is no one.
  static ({String userId, String displayName})? directPartner(Match match) {
    if (!match.isHost) return (userId: match.host.userId, displayName: match.host.displayName);
    if (match.capacity != 2) return null;
    final others = [
      for (final p in match.players)
        if (p.state != ParticipantState.host) p,
    ];
    return others.length == 1 ? (userId: others.single.userId, displayName: others.single.displayName) : null;
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.plan});

  final MatchDetailState state;
  final _ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchDetailCubit>();
    final match = state.match!;
    final sport = state.sport;
    final now = cubit.now;
    final busy = state.busy;
    final levels = MatchLabels.levelRange(match.minLevel, match.maxLevel, sport);
    final hostLevel = match.host.level;
    final late = cubit.isLateCancellation && (match.canLeave(now) || match.canCancel(now));
    final confirmed =
        match.status == MatchStatus.confirmed && (match.myState?.plays ?? false) && match.attendance == null;

    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        plan.pinned.isEmpty ? AppSpacing.lg : StickyActions.contentPadding,
      ),
      children: [
        _Cover(match: match),
        const SizedBox(height: AppSpacing.sm),
        StatGrid(
          items: [
            StatItem(label: AppStrings.statDuration, value: MatchLabels.duration(match.durationMinutes)),
            StatItem(
              label: AppStrings.statLevel,
              value: levels.isNotEmpty
                  ? levels
                  : hostLevel != null
                  ? MatchLabels.level(hostLevel, sport)
                  : AppStrings.levelUnknown,
            ),
            StatItem(
              label: AppStrings.statCourt,
              value: match.courtBooked ? AppStrings.courtBookedShort : AppStrings.courtNotBookedShort,
            ),
          ],
        ),
        if (confirmed) ...[
          const SizedBox(height: AppSpacing.sm),
          const NoticeBanner(
            key: MatchDetailPage.confirmedBannerKey,
            tone: NoticeTone.success,
            title: AppStrings.confirmedBannerTitle,
            body: AppStrings.confirmedBannerBody,
          ),
        ],
        if (match.attendance != null) ...[const SizedBox(height: AppSpacing.sm), _AttendanceCard(state: state)],
        if (match.rateablePlayers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          _RateSection(match: match),
        ],
        const SizedBox(height: AppSpacing.section),
        ..._players(context, match, now, sport, busy: busy),
        if (plan.inline.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          for (final button in plan.inline)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: button,
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _DetailsCard(match: match),
        if (match.canShareLink(now)) ...[const SizedBox(height: AppSpacing.sm), _ShareCard(match: match)],
        if (match.canAnswerInvitation(now) || match.canJoin(now)) ...[
          const SizedBox(height: AppSpacing.sm),
          const NoticeBanner(
            key: MatchDetailPage.policyNoticeKey,
            tone: NoticeTone.warning,
            body: AppStrings.lateCancellationPolicy,
          ),
        ],
        if (late) ...[
          const SizedBox(height: AppSpacing.sm),
          const NoticeBanner(
            key: MatchDetailPage.lateNoticeKey,
            tone: NoticeTone.warning,
            body: AppStrings.lateCancellationWarning,
          ),
        ],
        if (plan.destructive.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final button in plan.destructive)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: button,
            ),
        ],
      ],
    );
  }

  /// «بازیکن‌ها • ۲ از ۲»: the players (host first, with the host chip), then invited players; for the host, the
  /// join requests with accept and decline. A player who is not involved sees only the host.
  List<Widget> _players(BuildContext context, Match match, DateTime now, Sport? sport, {required bool busy}) {
    final participants = match.participants;
    return [
      SectionTitle(
        title: AppStrings.playersCount(PersianDigits.fromInt(match.playerCount), PersianDigits.fromInt(match.capacity)),
        subtitle: match.status.isActive ? MatchLabels.spots(match) : null,
      ),
      if (participants == null)
        _gap(
          ListRow(
            key: MatchDetailPage.participantKey(match.host.userId),
            leading: AppAvatar(name: match.host.displayName),
            title: match.host.displayName,
            titleTrailing: const AppChip(label: AppStrings.participantHost),
            subtitle: match.host.level == null ? null : MatchLabels.level(match.host.level!, sport),
            onTap: () => context.push(Routes.playerPath(match.host.userId)),
          ),
        )
      else ...[
        for (final p in [...match.players, ...match.invited])
          _gap(_participantRow(context, match, p, now, sport, busy)),
        if (match.playersBrought > 0)
          _gap(
            ListRow(
              leading: const Icon(Icons.group_add_outlined),
              title: AppStrings.playersBroughtLabel,
              trailing: Text(PersianDigits.fromInt(match.playersBrought)),
            ),
          ),
        if (match.isHost && match.pendingRequests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const SectionTitle(title: AppStrings.requestsLabel),
          for (final p in match.pendingRequests) _gap(_requestRow(context, match, p, now, busy)),
        ],
      ],
    ];
  }

  static Widget _gap(Widget row) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
    child: row,
  );

  Widget _participantRow(BuildContext context, Match match, MatchParticipant p, DateTime now, Sport? sport, bool busy) {
    final isHost = p.state == ParticipantState.host;
    final canRemove = !isHost && match.canRemove(p, now);
    final hostLevel = match.host.level;
    final outcome = p.outcome;
    final subtitle = isHost
        ? [
            if (hostLevel != null) MatchLabels.level(hostLevel, sport),
            if (outcome != null) MatchLabels.outcome(outcome),
          ].joinDisplay()
        : MatchLabels.participantLine(p);
    return ListRow(
      key: MatchDetailPage.participantKey(p.userId),
      leading: AppAvatar(name: p.displayName),
      title: p.displayName,
      titleTrailing: isHost ? const AppChip(label: AppStrings.participantHost) : null,
      subtitle: subtitle.isEmpty ? null : subtitle,
      onTap: isHost && match.isHost ? null : () => context.push(Routes.playerPath(p.userId)),
      trailing: canRemove
          ? IconButton(
              key: MatchDetailPage.removeKey(p.userId),
              tooltip: AppStrings.remove,
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: busy ? null : () => MatchDetailPage._remove(context, p),
            )
          : null,
    );
  }

  /// A join request: the player's message (or «درخواست داده»), the out-of-range note, and the host's mini actions.
  Widget _requestRow(BuildContext context, Match match, MatchParticipant p, DateTime now, bool busy) {
    final cubit = context.read<MatchDetailCubit>();
    final canAnswer = match.canAnswerRequests(now);
    return ListRow(
      key: MatchDetailPage.participantKey(p.userId),
      leading: AppAvatar(name: p.displayName),
      title: p.displayName,
      subtitle: [p.message ?? MatchLabels.participant(p.state), if (p.outOfRange) AppStrings.outOfRange].joinDisplay(),
      onTap: () => context.push(Routes.playerPath(p.userId)),
      trailing: canAnswer
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton.ghost(
                  key: MatchDetailPage.declineRequestKey(p.userId),
                  label: AppStrings.declineShort,
                  compact: true,
                  expanded: false,
                  onPressed: busy ? null : () => cubit.declineRequest(p.userId),
                ),
                const SizedBox(width: AppSpacing.xxs),
                AppButton.secondary(
                  key: MatchDetailPage.acceptRequestKey(p.userId),
                  label: AppStrings.acceptShort,
                  compact: true,
                  expanded: false,
                  onPressed: busy ? null : () => cubit.acceptRequest(p.userId),
                ),
              ],
            )
          : null,
    );
  }
}

/// The design's `match-cover`: the sport and format with the status chip, a title, the club (opening it), the day and
/// time, and this player's place in the game, in white on the dark green.
class _Cover extends StatelessWidget {
  const _Cover({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final mine = MatchLabels.myState(match.myState);
    return Container(
      key: MatchDetailPage.coverKey,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md + AppSpacing.xxs),
      decoration: BoxDecoration(color: palette.primaryDark, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  MatchLabels.title(match),
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.onBrandMuted),
                ),
              ),
              MatchStatusChip(status: match.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(MatchLabels.coverTitle(match), style: theme.textTheme.headlineMedium?.copyWith(color: palette.onBrand)),
          const SizedBox(height: AppSpacing.sm),
          _CoverLine(
            icon: Icons.place_outlined,
            text: match.venue.name,
            onTap: () => context.push(Routes.venuePath(match.venue.id)),
          ),
          _CoverLine(icon: Icons.schedule_rounded, text: MatchLabels.when(match)),
          if (mine != null) _CoverLine(icon: Icons.person_outline_rounded, text: mine),
        ],
      ),
    );
  }
}

class _CoverLine extends StatelessWidget {
  const _CoverLine({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: onTap == null ? 0 : AppTouchTarget.min),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.sm, color: palette.onBrandMuted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.onBrand)),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, size: AppIconSize.action, color: palette.onBrandMuted),
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// «درباره بازی»: the host's description, who the game is for, whether it is a public post or an invitation, the cost
/// line, and a cancelled game's reason.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = match.cancelReason;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.aboutMatchTitle, style: theme.textTheme.titleMedium),
          if (match.description case final description?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted)),
          ],
          _DetailLine(label: AppStrings.partnerGenderLabel, value: MatchLabels.partnerGender(match.partnerGender)),
          _DetailLine(label: AppStrings.matchTypeLabel, value: MatchLabels.visibility(match.visibility)),
          if (match.costNote case final note?) _DetailLine(label: AppStrings.costLabel, value: note),
          if (match.status == MatchStatus.cancelled && reason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            NoticeBanner(
              key: MatchDetailPage.cancelReasonKey,
              tone: NoticeTone.error,
              body: AppStrings.cancelReason(reason),
            ),
          ],
        ],
      ),
    );
  }
}

/// The design's `.cost` line: a muted label and a bold value, under a line.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: theme.textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

/// A public post's link: shown so it can be read, copied, or sent through the share sheet.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchDetailCubit>();
    final palette = context.palette;
    final theme = Theme.of(context);
    final url = match.shareUrl!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.shareTitle, style: theme.textTheme.titleMedium),
          Text(
            match.isHost ? AppStrings.shareHint : AppStrings.shareHintPublic,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(color: palette.track, borderRadius: BorderRadius.circular(AppRadius.field)),
            child: SelectableText(url, textDirection: TextDirection.ltr, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  key: MatchDetailPage.copyLinkKey,
                  label: AppStrings.copyLink,
                  icon: Icons.copy_rounded,
                  compact: true,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    cubit.linkCopied();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  key: MatchDetailPage.shareKey,
                  label: AppStrings.shareMatch,
                  icon: Icons.share_outlined,
                  compact: true,
                  onPressed: cubit.share,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { regenerate, report }

/// The top bar's «•••»: a new share link for the host, reporting the post for others. Hidden when it would be empty.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.match, required this.busy});

  final Match match;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchDetailCubit>();
    final actions = [if (match.canShare) _MenuAction.regenerate, if (match.canReportPost) _MenuAction.report];
    if (actions.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<_MenuAction>(
      key: MatchDetailPage.overflowKey,
      tooltip: AppStrings.matchMoreActions,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (action) => switch (action) {
        _MenuAction.regenerate => MatchDetailPage._confirm(
          context,
          AppStrings.regenerateLinkQuestion,
          AppStrings.regenerateLink,
          cubit.regenerateShareToken,
        ),
        _MenuAction.report => MatchDetailPage._reportPost(context, match),
      },
      itemBuilder: (_) => [
        for (final action in actions)
          switch (action) {
            _MenuAction.regenerate => PopupMenuItem(
              key: MatchDetailPage.regenerateKey,
              value: action,
              enabled: !busy,
              child: const _MenuLabel(icon: Icons.refresh_rounded, label: AppStrings.regenerateLink),
            ),
            _MenuAction.report => PopupMenuItem(
              key: MatchDetailPage.reportPostKey,
              value: action,
              child: const _MenuLabel(icon: Icons.flag_outlined, label: AppStrings.reportPost),
            ),
          },
      ],
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: AppIconSize.action, color: context.palette.muted),
      const SizedBox(width: AppSpacing.sm),
      Text(label),
    ],
  );
}

/// «امتیاز به هم‌بازی‌ها»: the players this player may still rate, each opening the rating form; the game reloads
/// after a rating.
class _RateSection extends StatelessWidget {
  const _RateSection({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchDetailCubit>();
    final palette = context.palette;
    return Column(
      key: MatchDetailPage.rateSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: AppStrings.rateTitle, subtitle: AppStrings.rateHint),
        for (final p in match.rateablePlayers)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: ListRow(
              key: MatchDetailPage.rateKey(p.userId),
              leading: AppAvatar(name: p.displayName),
              title: AppStrings.ratePlayer(p.displayName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: palette.star, size: AppIconSize.md),
                  Icon(Icons.chevron_right_rounded, color: palette.muted, size: AppIconSize.action),
                ],
              ),
              onTap: () async {
                final rated = await context.push<bool>(
                  Routes.rateMatchPlayerPath(match.id, p.userId),
                  extra: p.displayName,
                );
                if (rated == true && !cubit.isClosed) await cubit.load();
              },
            ),
          ),
      ],
    );
  }
}

/// The attendance card once the game ended: «بازی انجام شد» (with optional no-shows among the other players) or
/// «بازی انجام نشد». Once answered, the answer; once resolved, the game's outcome and this player's.
class _AttendanceCard extends StatefulWidget {
  const _AttendanceCard({required this.state});

  final MatchDetailState state;

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  AttendanceAnswer? _answer;
  final Set<String> _noShows = {};

  @override
  Widget build(BuildContext context) {
    final match = widget.state.match!;
    return AppCard(
      key: MatchDetailPage.attendanceKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.attendanceTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          if (match.canAnswerAttendance) ..._question(context, match) else ..._status(context, match),
        ],
      ),
    );
  }

  List<Widget> _question(BuildContext context, Match match) {
    final cubit = context.read<MatchDetailCubit>();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: context.palette.muted);
    final others = match.otherPlayers(widget.state.myId);
    final busy = widget.state.busy;
    final deadline = tehranWallClock(match.attendance!.closesAt).formatPersianDateTime();
    return [
      Text(AppStrings.attendanceDeadline(deadline), style: muted),
      const SizedBox(height: AppSpacing.sm),
      RadioCard(
        key: MatchDetailPage.attendancePlayedKey,
        title: AppStrings.attendancePlayed,
        selected: _answer == AttendanceAnswer.played,
        onTap: busy ? null : () => setState(() => _answer = AttendanceAnswer.played),
      ),
      const SizedBox(height: AppSpacing.xs),
      RadioCard(
        key: MatchDetailPage.attendanceDidNotHappenKey,
        title: AppStrings.attendanceDidNotHappen,
        selected: _answer == AttendanceAnswer.didNotHappen,
        onTap: busy ? null : () => setState(() => _answer = AttendanceAnswer.didNotHappen),
      ),
      if (_answer == AttendanceAnswer.played && others.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.noShowTitle, style: theme.textTheme.titleSmall),
        Text(AppStrings.noShowHint, style: muted),
        const SizedBox(height: AppSpacing.xs),
        for (final p in others)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: ListRow(
              key: MatchDetailPage.noShowKey(p.userId),
              leading: AppAvatar(name: p.displayName, size: AppAvatarSize.small),
              title: p.displayName,
              trailing: ExcludeSemantics(
                child: Checkbox(value: _noShows.contains(p.userId), onChanged: busy ? null : (_) => _toggle(p)),
              ),
              semanticLabel: p.displayName,
              onTap: busy ? null : () => _toggle(p),
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        key: MatchDetailPage.submitAttendanceKey,
        label: AppStrings.submitAttendance,
        loading: busy,
        onPressed: _answer == null
            ? null
            : () => cubit.answerAttendance(
                _answer!,
                noShows: _answer == AttendanceAnswer.played ? {..._noShows} : const {},
              ),
      ),
    ];
  }

  void _toggle(MatchParticipant p) =>
      setState(() => _noShows.contains(p.userId) ? _noShows.remove(p.userId) : _noShows.add(p.userId));

  List<Widget> _status(BuildContext context, Match match) {
    final attendance = match.attendance!;
    final answer = attendance.myAnswer;
    final outcome = attendance.myOutcome;
    final resolution = MatchLabels.resolution(match.status);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted);
    return [
      if (answer != null)
        Text(AppStrings.myAttendanceAnswer(MatchLabels.answer(answer)), key: MatchDetailPage.attendanceAnswerKey),
      if (resolution != null) ...[
        const SizedBox(height: AppSpacing.xs),
        NoticeBanner(
          key: MatchDetailPage.resolutionKey,
          tone: match.status == MatchStatus.completed ? NoticeTone.success : NoticeTone.warning,
          body: resolution,
        ),
      ] else if (answer != null && attendance.open)
        Text(AppStrings.attendanceWaiting, style: muted)
      else if (!attendance.open)
        Text(AppStrings.attendanceWindowOver, style: muted),
      if (outcome != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.myAttendanceOutcome(MatchLabels.outcome(outcome)),
          key: MatchDetailPage.attendanceOutcomeKey,
          style: theme.textTheme.titleSmall,
        ),
      ],
    ];
  }
}

/// The late-cancellation warning in a confirmation dialog.
class _LateWarning extends StatelessWidget {
  const _LateWarning();

  @override
  Widget build(BuildContext context) => const NoticeBanner(
    key: MatchDetailPage.lateWarningKey,
    tone: NoticeTone.warning,
    body: AppStrings.lateCancellationWarning,
  );
}

/// Asks for an optional text (a join message, a cancel reason) and answers with it ('' for none), or null when the
/// player backs out. [warning] adds the late-cancellation warning.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.confirm,
    this.maxLength,
    this.warning = false,
  });

  final String title;
  final String label;
  final String confirm;
  final int? maxLength;
  final bool warning;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.warning) ...[const _LateWarning(), const SizedBox(height: AppSpacing.sm)],
          TextField(
            key: MatchDetailPage.dialogTextKey,
            controller: _text,
            maxLength: widget.maxLength,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(AppStrings.keep)),
        TextButton(
          key: MatchDetailPage.dialogConfirmKey,
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
