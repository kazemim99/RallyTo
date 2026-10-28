import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat.dart';
import '../bloc/chat_inbox_cubit.dart';
import '../chat_labels.dart';

/// The chat inbox: conversations and message requests behind a two-way segment, each label carrying its unread count.
/// Conversations are rows (avatar or the game's group square, name and time, the last message, the unread badge);
/// requests are cards the recipient can accept, ignore or block (after a confirmation) on the spot, or open. Needs a
/// loaded [ChatInboxCubit] above it.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key, this.clock});

  /// Today, for the conversations' times (tests pass one).
  final DateTime Function()? clock;

  static const Key conversationsTabKey = Key('chatInbox.conversationsTab');
  static const Key requestsTabKey = Key('chatInbox.requestsTab');

  static Key conversationKey(String id) => Key('chatInbox.conversation.$id');

  static Key acceptKey(String id) => Key('chatInbox.accept.$id');

  static Key ignoreKey(String id) => Key('chatInbox.ignore.$id');

  static Key blockKey(String id) => Key('chatInbox.block.$id');

  static const Key confirmBlockKey = Key('chatInbox.confirmBlock');

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  bool _requests = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.chatTitle)),
      body: BlocConsumer<ChatInboxCubit, ChatInboxState>(
        listenWhen: (previous, current) => current.feedback != null && !identical(previous.feedback, current.feedback),
        listener: (context, state) {
          final feedback = state.feedback!;
          feedback.isError
              ? AppSnackbar.error(context, feedback.message)
              : AppSnackbar.success(context, feedback.message);
        },
        builder: (context, state) {
          final now = (widget.clock ?? DateTime.now)();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screen,
                  AppSpacing.xxs,
                  AppSpacing.screen,
                  AppSpacing.xs,
                ),
                child: AppSegmented<bool>(
                  segments: [
                    AppSegment(
                      key: ChatInboxPage.conversationsTabKey,
                      value: false,
                      label: _label(AppStrings.conversationsTab, state.unread.conversations),
                    ),
                    AppSegment(
                      key: ChatInboxPage.requestsTabKey,
                      value: true,
                      label: _label(AppStrings.requestsTab, state.unread.requests),
                    ),
                  ],
                  selected: _requests,
                  onChanged: (requests) => setState(() => _requests = requests),
                ),
              ),
              Expanded(
                child: _requests
                    ? _ConversationTab(
                        key: const ValueKey('chatInbox.requests'),
                        list: state.requests,
                        empty: const EmptyState(
                          icon: Icons.mark_chat_unread_outlined,
                          title: AppStrings.requestsEmptyTitle,
                          subtitle: AppStrings.requestsEmptySubtitle,
                        ),
                        separated: false,
                        itemBuilder: (conversation) =>
                            _RequestCard(request: conversation, now: now, answering: state.answeringId),
                      )
                    : _ConversationTab(
                        key: const ValueKey('chatInbox.conversations'),
                        list: state.conversations,
                        empty: const EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: AppStrings.conversationsEmptyTitle,
                          subtitle: AppStrings.conversationsEmptySubtitle,
                        ),
                        separated: true,
                        itemBuilder: (conversation) => _ConversationRow(conversation: conversation, now: now),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// «گفتگوها • ۳» while something is unread, else just the label.
  static String _label(String label, int unread) =>
      unread > 0 ? AppStrings.segmentWithCount(label, ChatLabels.badge(unread)) : label;
}

/// Opens [conversation], then reloads the inbox for its new unread count.
Future<void> _open(BuildContext context, Conversation conversation) async {
  final cubit = context.read<ChatInboxCubit>();
  await context.push(Routes.chatPath(conversation.id));
  if (!cubit.isClosed) await cubit.refresh();
}

class _ConversationTab extends StatelessWidget {
  const _ConversationTab({
    super.key,
    required this.list,
    required this.empty,
    required this.separated,
    required this.itemBuilder,
  });

  final ConversationList list;
  final Widget empty;

  /// Rows divided by lines (conversations), or cards apart (requests).
  final bool separated;
  final Widget Function(Conversation conversation) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatInboxCubit>();
    final palette = context.palette;
    return StateSwitcher(
      status: list.status,
      errorMessage: list.errorMessage,
      onRetry: cubit.load,
      empty: empty,
      loading: const Padding(padding: EdgeInsetsDirectional.all(AppSpacing.screen), child: SkeletonLines(count: 6)),
      contentBuilder: (context) => RefreshIndicator(
        onRefresh: cubit.refresh,
        child: ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
          itemCount: list.items.length,
          separatorBuilder: (_, _) =>
              separated ? Divider(height: 1, thickness: 1, color: palette.line) : const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => itemBuilder(list.items[index]),
        ),
      ),
    );
  }
}

/// A conversation's leading picture: the other player's avatar, or for a game's group a rounded green square with
/// its initial.
class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    if (!conversation.isMatch) return AppAvatar(name: conversation.title, size: AppAvatarSize.large);
    final palette = context.palette;
    final size = AppAvatarSize.large.dimension;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(AppRadius.field)),
        child: Text(
          AppAvatar.initialOf(conversation.title),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: palette.onPrimary, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.now});

  final Conversation conversation;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final unread = conversation.unreadCount > 0;
    final at = conversation.lastMessageAt;
    return Semantics(
      button: true,
      child: InkWell(
        key: ChatInboxPage.conversationKey(conversation.id),
        onTap: () => _open(context, conversation),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
          child: Row(
            children: [
              _ConversationAvatar(conversation: conversation),
              const SizedBox(width: AppSpacing.sm - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (conversation.muted) ...[
                          Icon(
                            Icons.notifications_off_outlined,
                            size: AppIconSize.xs,
                            color: palette.muted,
                            semanticLabel: AppStrings.mutedConversation,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                        ],
                        if (at != null)
                          Text(
                            ChatLabels.when(at, now: now),
                            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage ?? AppStrings.noMessagesYet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: unread ? palette.ink : palette.muted),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(count: conversation.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A message request: who sent it, their message in a canvas box, ignore / accept, and «مسدود کردن» (asked first).
/// Tapping the card opens the conversation.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.now, required this.answering});

  final Conversation request;
  final DateTime now;

  /// The request whose answer is on its way, if any.
  final String? answering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final cubit = context.read<ChatInboxCubit>();
    final at = request.lastMessageAt;
    final busy = answering != null;
    final message = request.lastMessage;
    return AppCard(
      key: ChatInboxPage.conversationKey(request.id),
      onTap: () => _open(context, request),
      padding: const EdgeInsetsDirectional.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: request.title),
              const SizedBox(width: AppSpacing.sm - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      AppStrings.messageRequestLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
              if (at != null)
                Text(
                  ChatLabels.when(at, now: now),
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              if (request.unreadCount > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                AppBadge(count: request.unreadCount),
              ],
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Container(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm - 2),
              decoration: BoxDecoration(color: palette.canvas, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(message, maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            ),
          ],
          if (request.isRequestRecipient) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppButton.ghost(
                    key: ChatInboxPage.ignoreKey(request.id),
                    label: AppStrings.ignoreRequest,
                    expanded: true,
                    compact: true,
                    onPressed: busy ? null : () => cubit.answerRequest(request, accept: false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  flex: 3,
                  child: AppButton(
                    key: ChatInboxPage.acceptKey(request.id),
                    label: AppStrings.acceptRequest,
                    compact: true,
                    loading: answering == request.id,
                    onPressed: busy ? null : () => _accept(context),
                  ),
                ),
              ],
            ),
            if (request.otherUserId != null)
              Align(
                alignment: AlignmentDirectional.center,
                child: TextButton.icon(
                  key: ChatInboxPage.blockKey(request.id),
                  style: TextButton.styleFrom(foregroundColor: palette.error),
                  icon: const Icon(Icons.block_rounded, size: AppIconSize.action),
                  label: const Text(AppStrings.blockSender),
                  onPressed: busy ? null : () => _confirmBlock(context),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Asks first, as the conversation screen does; a confirmed block takes the request off the list.
  Future<void> _confirmBlock(BuildContext context) async {
    final cubit = context.read<ChatInboxCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.blockQuestion(request.title)),
        content: const Text(AppStrings.blockExplanation),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(AppStrings.cancel)),
          TextButton(
            key: ChatInboxPage.confirmBlockKey,
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.block),
          ),
        ],
      ),
    );
    if (confirmed == true && !cubit.isClosed) await cubit.blockSender(request);
  }

  /// Accepts, then opens the conversation to reply.
  Future<void> _accept(BuildContext context) async {
    final accepted = await context.read<ChatInboxCubit>().answerRequest(request, accept: true);
    if (accepted && context.mounted) await _open(context, request);
  }
}
