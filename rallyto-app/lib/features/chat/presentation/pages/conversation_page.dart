import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/display_join.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../reports/domain/entities/report.dart';
import '../../domain/entities/chat.dart';
import '../bloc/conversation_cubit.dart';
import '../chat_labels.dart';

/// What the conversation's overflow menu offers.
enum _MenuAction { profile, mute }

/// One conversation: messages newest at the bottom with older pages above and a Jalali day separator over each day,
/// the safety notice for a new conversation or a request, the request recipient's accept / ignore / block, and the
/// composer pinned to the bottom, or a read-only footer when this player can no longer send. Mute is in the overflow
/// menu. Needs a loaded [ConversationCubit] above it.
class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key});

  static const Key composerKey = Key('conversation.composer');
  static const Key sendKey = Key('conversation.send');
  static const Key readOnlyKey = Key('conversation.readOnly');
  static const Key safetyNoticeKey = Key('conversation.safetyNotice');
  static const Key loadOlderKey = Key('conversation.loadOlder');
  static const Key moreKey = Key('conversation.more');
  static const Key muteKey = Key('conversation.mute');
  static const Key profileKey = Key('conversation.profile');
  static const Key requestBarKey = Key('conversation.requestBar');
  static const Key acceptKey = Key('conversation.accept');
  static const Key ignoreKey = Key('conversation.ignore');
  static const Key blockKey = Key('conversation.block');
  static const Key confirmKey = Key('conversation.confirm');

  static Key messageKey(String key) => Key('conversation.message.$key');

  static Key retryKey(String key) => Key('conversation.retry.$key');

  static Key discardKey(String key) => Key('conversation.discard.$key');

  static Key readKey(String key) => Key('conversation.read.$key');

  static Key dayKey(String key) => Key('conversation.day.$key');

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConversationCubit>();
    return BlocConsumer<ConversationCubit, ConversationState>(
      listenWhen: (previous, current) =>
          (current.feedback != null && !identical(previous.feedback, current.feedback)) ||
          (current.left && !previous.left),
      listener: (context, state) {
        final feedback = state.feedback;
        if (feedback != null) {
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        }
        if (state.left) {
          final navigator = Navigator.of(context);
          navigator.canPop() ? navigator.pop() : context.go(Routes.chat);
        }
      },
      builder: (context, state) {
        final conversation = state.conversation;
        final otherUserId = conversation?.otherUserId;
        final palette = context.palette;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    state.title.isEmpty ? AppStrings.conversationTitle : state.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (conversation?.muted ?? false) ...[
                  const SizedBox(width: AppSpacing.xxs + 2),
                  Icon(
                    Icons.notifications_off_outlined,
                    size: AppIconSize.sm,
                    color: palette.muted,
                    semanticLabel: AppStrings.mutedConversation,
                  ),
                ],
              ],
            ),
            actions: [
              if (conversation != null)
                PopupMenuButton<_MenuAction>(
                  key: moreKey,
                  tooltip: AppStrings.moreActions,
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (action) => switch (action) {
                    _MenuAction.profile => context.push(Routes.playerPath(otherUserId!)),
                    _MenuAction.mute => cubit.toggleMute(),
                  },
                  itemBuilder: (_) => [
                    if (otherUserId != null)
                      const PopupMenuItem(
                        key: profileKey,
                        value: _MenuAction.profile,
                        child: _MenuRow(icon: Icons.person_outline_rounded, label: AppStrings.viewProfile),
                      ),
                    PopupMenuItem(
                      key: muteKey,
                      value: _MenuAction.mute,
                      enabled: !state.busy,
                      child: _MenuRow(
                        icon: conversation.muted
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        label: conversation.muted ? AppStrings.unmute : AppStrings.mute,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, ConversationState state) {
    final cubit = context.read<ConversationCubit>();
    if (state.status == ViewStatus.error && state.notFound) {
      return EmptyState(
        icon: state.noMatchChat ? Icons.forum_outlined : Icons.speaker_notes_off_outlined,
        title: state.errorMessage ?? AppStrings.chatConversationNotFound,
        subtitle: state.noMatchChat ? AppStrings.matchChatMissingHint : null,
        ctaLabel: AppStrings.backToHome,
        onCta: () => context.go(Routes.home),
      );
    }
    return StateSwitcher(
      status: state.status,
      errorMessage: state.errorMessage,
      onRetry: cubit.load,
      contentBuilder: (context) => Column(
        children: [
          Expanded(child: _Messages(state: state)),
          if (state.isRequestRecipient) _RequestBar(state: state),
          if (state.canSend) const _Composer() else const _ReadOnlyFooter(),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.action, color: context.palette.muted),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// A white bar pinned to the bottom with a line on top: the composer, the read-only footer.
class _BottomBar extends StatelessWidget {
  const _BottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: 9),
          child: child,
        ),
      ),
    );
  }
}

class _ReadOnlyFooter extends StatelessWidget {
  const _ReadOnlyFooter();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _BottomBar(
      key: ConversationPage.readOnlyKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: AppIconSize.sm, color: palette.muted),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                AppStrings.cannotReplyFooter,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.state});

  final ConversationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConversationCubit>();
    final messages = state.messages;
    final extras = <Widget>[
      if (state.nextCursor != null)
        Center(
          child: AppButton.ghost(
            key: ConversationPage.loadOlderKey,
            label: AppStrings.loadOlderMessages,
            loading: state.loadingOlder,
            onPressed: cubit.loadOlder,
          ),
        ),
      if (state.showSafetyNotice)
        const Padding(
          padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxs),
          child: NoticeBanner(
            key: ConversationPage.safetyNoticeKey,
            tone: NoticeTone.info,
            icon: Icons.shield_outlined,
            title: AppStrings.safetyBannerTitle,
            body:
                '${AppStrings.safetyMeetAtClubs}\n${AppStrings.safetyNoPersonalDetails}\n${AppStrings.safetyBlockReport}',
          ),
        ),
    ];
    // Reversed: index 0 (the newest message) sits at the bottom, older pages and the notice above.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.sm),
      itemCount: messages.length + extras.length,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final message = messages[index];
          final mine = state.isMine(message);
          final bubble = _Bubble(
            key: ConversationPage.messageKey(message.key),
            message: message,
            mine: mine,
            showSender: (state.conversation?.isMatch ?? false) && !mine,
          );
          // A new day starts above the oldest loaded message, and wherever the day changes.
          final older = index + 1 < messages.length ? messages[index + 1] : null;
          if (older != null && ChatLabels.sameDay(older.sentAt, message.sentAt)) return bubble;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DaySeparator(key: ConversationPage.dayKey(message.key), instant: message.sentAt),
              bubble,
            ],
          );
        }
        return extras[extras.length - 1 - (index - messages.length)];
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({super.key, required this.instant});

  final DateTime instant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      child: Text(
        ChatLabels.day(instant),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.muted),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, required this.mine, required this.showSender});

  final ChatMessage message;
  final bool mine;
  final bool showSender;

  static const double _radius = 15;
  static const double _tail = 4;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConversationCubit>();
    final theme = Theme.of(context);
    final palette = context.palette;
    final failed = message.delivery == MessageDelivery.failed;
    final foreground = mine ? palette.onPrimarySoft : palette.ink;
    final meta = theme.textTheme.labelSmall?.copyWith(color: palette.muted);
    // The design: theirs at the start (right) with the bottom-start corner sharp; mine at the end with the bottom-end
    // corner sharp.
    final radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(_radius),
      topEnd: const Radius.circular(_radius),
      bottomStart: Radius.circular(mine ? _radius : _tail),
      bottomEnd: Radius.circular(mine ? _tail : _radius),
    );
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: GestureDetector(
          onLongPress: !message.isSent || message.deleted
              ? null
              : mine
              ? () => _confirmDelete(context)
              : () => _report(context),
          child: Container(
            margin: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xxs),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm - 2),
            decoration: BoxDecoration(
              color: mine ? palette.primarySoft : palette.surface,
              borderRadius: radius,
              border: failed
                  ? Border.all(color: palette.error)
                  : mine
                  ? null
                  : Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSender)
                  Text(message.senderName, style: theme.textTheme.labelMedium?.copyWith(color: palette.primary)),
                if (message.deleted)
                  Text(
                    AppStrings.deletedMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted, fontStyle: FontStyle.italic),
                  )
                else
                  Text(message.body ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ChatLabels.time(message.sentAt), style: meta),
                    if (mine) ..._status(meta, palette),
                  ],
                ),
                if (failed) ...[
                  if (message.errorMessage case final error?)
                    Text(error, style: theme.textTheme.labelSmall?.copyWith(color: palette.error)),
                  Wrap(
                    children: [
                      AppButton.ghost(
                        key: ConversationPage.retryKey(message.key),
                        label: AppStrings.retrySend,
                        icon: Icons.refresh_rounded,
                        compact: true,
                        onPressed: () => cubit.retry(message),
                      ),
                      AppButton.ghost(
                        key: ConversationPage.discardKey(message.key),
                        label: AppStrings.discardMessage,
                        compact: true,
                        onPressed: () => cubit.discard(message),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// «، در حال ارسال», «، ارسال نشد», «، خوانده شد», or a tick once sent. It follows the time, so the separator is the
  /// Persian comma: a dot beside a digit reads as a zero (see [DisplayJoin]).
  List<Widget> _status(TextStyle? meta, AppPalette palette) {
    final dot = Text(DisplayJoin.comma, style: meta);
    return switch (message.delivery) {
      MessageDelivery.pending => [dot, Text(AppStrings.messagePending, style: meta)],
      MessageDelivery.failed => [dot, Text(AppStrings.messageFailed, style: meta?.copyWith(color: palette.error))],
      MessageDelivery.sent when message.readByOthers && !message.deleted => [
        dot,
        Text(AppStrings.messageRead, key: ConversationPage.readKey(message.key), style: meta),
      ],
      MessageDelivery.sent => [
        const SizedBox(width: AppSpacing.xxs),
        Icon(Icons.done_rounded, size: AppIconSize.xs, color: meta?.color),
      ],
    };
  }

  /// Reports another player's message (long press); when its sender was blocked too, the conversation is fetched
  /// again so it turns read-only.
  Future<void> _report(BuildContext context) async {
    final cubit = context.read<ConversationCubit>();
    final blocked = await context.push<bool>(
      Routes.report,
      extra: ReportTarget.message(message.id, senderName: message.senderName),
    );
    if (blocked == true && !cubit.isClosed) await cubit.refresh();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<ConversationCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        content: const Text(AppStrings.deleteMessageQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(
            key: ConversationPage.confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.deleteMessage),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.delete(message);
  }
}

/// The request recipient's choice, above the composer: who asks, what answering means, and block / ignore / accept.
class _RequestBar extends StatelessWidget {
  const _RequestBar({required this.state});

  final ConversationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConversationCubit>();
    final theme = Theme.of(context);
    final palette = context.palette;
    return DecoratedBox(
      key: ConversationPage.requestBarKey,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.requestFrom(state.title), style: theme.textTheme.titleSmall),
            Text(AppStrings.requestHint, style: theme.textTheme.bodySmall?.copyWith(color: palette.muted)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppButton.ghost(
                    key: ConversationPage.ignoreKey,
                    label: AppStrings.ignoreRequest,
                    expanded: true,
                    compact: true,
                    onPressed: state.busy ? null : cubit.ignore,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  flex: 3,
                  child: AppButton(
                    key: ConversationPage.acceptKey,
                    label: AppStrings.acceptRequest,
                    icon: Icons.check_rounded,
                    compact: true,
                    onPressed: state.busy ? null : cubit.accept,
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.center,
              child: TextButton.icon(
                key: ConversationPage.blockKey,
                style: TextButton.styleFrom(foregroundColor: palette.error),
                icon: const Icon(Icons.block_rounded, size: AppIconSize.action),
                label: const Text(AppStrings.blockSender),
                onPressed: state.busy ? null : () => _confirmBlock(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final cubit = context.read<ConversationCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.blockQuestion(state.title)),
        content: const Text(AppStrings.blockExplanation),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(
            key: ConversationPage.confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.block),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.blockOther();
  }
}

class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final cubit = context.read<ConversationCubit>();
    final text = _text.text;
    final problem = cubit.checkMessage(text);
    if (problem != null) {
      AppSnackbar.error(context, problem);
      return;
    }
    _text.clear();
    await cubit.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final maxLength = context.select<ConversationCubit, int>((c) => c.state.maxLength);
    final palette = context.palette;
    return _BottomBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: ConversationPage.composerKey,
              controller: _text,
              minLines: 1,
              maxLines: 5,
              maxLength: maxLength,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: AppStrings.messageHint,
                counterText: '',
                filled: true,
                fillColor: palette.canvas,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs - 3),
          IconButton.filled(
            key: ConversationPage.sendKey,
            tooltip: AppStrings.send,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(AppSizes.control),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
            ),
            icon: const Icon(Icons.send_rounded),
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
