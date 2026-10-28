import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/auth/otp_sms_retriever.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/otp.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/widgets/widgets.dart';
import '../bloc/account_deletion_cubit.dart';
import '../widgets/account_deletion_sheet.dart';

/// Confirming the account deletion with the SMS code: the 4 code boxes (filled from the SMS on Android), the resend
/// countdown, the warning, and «حذف همیشگی حساب». A deleted account ends the session and the router moves the player to
/// phone entry; nothing navigates from here. Full screen, over the bottom bar. Expects an [AccountDeletionCubit] above
/// it, already [AccountDeletionCubit.start]ed.
class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key, this.smsRetriever});

  /// Reads the code from the SMS. Null: the platform's ([OtpSmsRetriever.forPlatform], Android only).
  final SmsRetriever? smsRetriever;

  static const Key codeKey = Key('accountDeletion.code');
  static const Key confirmKey = Key('accountDeletion.confirm');
  static const Key resendKey = Key('accountDeletion.resend');
  static const Key resendCountdownKey = Key('accountDeletion.resendCountdown');

  /// The whole flow from My Profile: the sheet that says what deletion does, then this page with a fresh cubit that
  /// asks for the code at once. [create] builds the cubit (the app's registration by default).
  static Future<void> start(
    BuildContext context, {
    AccountDeletionCubit Function()? create,
    SmsRetriever? smsRetriever,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!await AccountDeletionSheet.show(context)) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => (create ?? () => getIt<AccountDeletionCubit>())()..start(),
          child: AccountDeletionPage(smsRetriever: smsRetriever),
        ),
      ),
    );
  }

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final SmsRetriever? _retriever = widget.smsRetriever ?? OtpSmsRetriever.forPlatform();

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit([String? code]) => context.read<AccountDeletionCubit>().submit(code ?? _code.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return BlocBuilder<AccountDeletionCubit, AccountDeletionState>(
      builder: (context, state) => PopScope(
        // Leaving while the account is being deleted would hide the outcome.
        canPop: state.status != AccountDeletionStatus.verifying && state.status != AccountDeletionStatus.deleted,
        child: Scaffold(
          appBar: AppBar(title: const Text(AppStrings.deleteAccountCodeTitle)),
          body: MultiBlocListener(
            listeners: [
              BlocListener<AccountDeletionCubit, AccountDeletionState>(
                listenWhen: (previous, current) => current.errorCount != previous.errorCount,
                listener: (context, state) {
                  _code.clear();
                  _focus.requestFocus();
                },
              ),
              BlocListener<AccountDeletionCubit, AccountDeletionState>(
                listenWhen: (previous, current) => !previous.codeSent && current.codeSent,
                listener: (context, state) => _focus.requestFocus(),
              ),
              BlocListener<AccountDeletionCubit, AccountDeletionState>(
                listenWhen: (previous, current) => current.resentCount > previous.resentCount,
                listener: (context, state) => AppSnackbar.info(context, AppStrings.codeResent),
              ),
            ],
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AppStrings.deleteAccountCodeHeading,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _subtitle(state),
                    style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OtpBoxes(
                  key: AccountDeletionPage.codeKey,
                  controller: _code,
                  focusNode: _focus,
                  autofocus: false,
                  enabled: state.canSubmit,
                  errorText: state.error,
                  smsRetriever: _retriever,
                  onCompleted: _submit,
                  // Only typing clears the message: emptying the boxes after a refused code changes the text too.
                  onChanged: (value) {
                    if (value.isNotEmpty) context.read<AccountDeletionCubit>().codeChanged();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Center(child: _Resend(state: state)),
                const SizedBox(height: AppSpacing.md),
                const NoticeBanner(
                  tone: NoticeTone.warning,
                  icon: Icons.warning_amber_rounded,
                  body: AppStrings.deleteAccountWarning,
                ),
                const SizedBox(height: AppSpacing.md),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _code,
                  builder: (context, value, _) => AppButton.danger(
                    key: AccountDeletionPage.confirmKey,
                    label: AppStrings.deleteAccountConfirm,
                    icon: Icons.delete_forever_outlined,
                    loading:
                        state.status == AccountDeletionStatus.verifying ||
                        state.status == AccountDeletionStatus.deleted,
                    onPressed: value.text.length == otpLength && state.canSubmit ? _submit : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitle(AccountDeletionState state) {
    if (state.codeSent) return AppStrings.deleteAccountCodeSent;
    if (state.status == AccountDeletionStatus.requesting || state.status == AccountDeletionStatus.resending) {
      return AppStrings.deleteAccountSending;
    }
    return AppStrings.deleteAccountNotSent;
  }
}

/// «ارسال دوباره کد تا ۰:۵۹ دیگر» while the server's wait runs, then a link that asks for another code («دریافت کد»
/// when none reached the player yet).
class _Resend extends StatelessWidget {
  const _Resend({required this.state});

  final AccountDeletionState state;

  @override
  Widget build(BuildContext context) {
    if (state.resendSecondsLeft > 0) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
        child: Center(
          key: AccountDeletionPage.resendCountdownKey,
          child: Text(
            AppStrings.resendCodeAfter(Countdown.label(state.resendSecondsLeft)),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.palette.muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return AppButton.ghost(
      key: AccountDeletionPage.resendKey,
      label: state.codeSent ? AppStrings.resendCode : AppStrings.deleteAccountGetCode,
      expanded: false,
      compact: true,
      loading: state.status == AccountDeletionStatus.resending || state.status == AccountDeletionStatus.requesting,
      onPressed: state.canResend ? () => context.read<AccountDeletionCubit>().resend() : null,
    );
  }
}
