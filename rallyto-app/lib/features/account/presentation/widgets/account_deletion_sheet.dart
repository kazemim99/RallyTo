import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';

/// The first step of deleting the account: what deletion does (the profile anonymised, future games left or
/// cancelled, messages kept as «کاربر حذف‌شده», no way back), and that an SMS code confirms it. True when the player
/// chose to go on.
class AccountDeletionSheet extends StatelessWidget {
  const AccountDeletionSheet({super.key});

  static const Key continueKey = Key('accountDeletion.continue');
  static const Key cancelKey = Key('accountDeletion.cancel');

  /// Shows the sheet over the bottom bar; true when the player chose to go on.
  static Future<bool> show(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AccountDeletionSheet(),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: palette.errorSoft, shape: BoxShape.circle),
                  child: Icon(Icons.person_remove_outlined, color: palette.error, size: AppIconSize.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                AppStrings.deleteAccountQuestion,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.deleteAccountIntro, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            const _Consequence(icon: Icons.visibility_off_outlined, text: AppStrings.deleteAccountAnonymised),
            const _Consequence(icon: Icons.event_busy_outlined, text: AppStrings.deleteAccountGames),
            const _Consequence(icon: Icons.chat_bubble_outline_rounded, text: AppStrings.deleteAccountMessages),
            const _Consequence(
              icon: Icons.warning_amber_rounded,
              text: AppStrings.deleteAccountIrreversible,
              emphasised: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            const NoticeBanner(tone: NoticeTone.info, icon: Icons.sms_outlined, body: AppStrings.deleteAccountCodeHint),
            const SizedBox(height: AppSpacing.md),
            AppButton.danger(
              key: continueKey,
              label: AppStrings.deleteAccountContinue,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton.ghost(
              key: cancelKey,
              label: AppStrings.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// One thing deletion does: an icon and a sentence; the last one, «برگشت‌پذیر نیست», in the error colour.
class _Consequence extends StatelessWidget {
  const _Consequence({required this.icon, required this.text, this.emphasised = false});

  final IconData icon;
  final String text;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final color = emphasised ? palette.error : palette.muted;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: ExcludeSemantics(
              child: Icon(icon, size: AppIconSize.action, color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: emphasised
                  ? theme.textTheme.titleSmall?.copyWith(color: palette.error)
                  : theme.textTheme.bodyMedium?.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}
