import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/auth/otp_sms_retriever.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/otp.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/widgets/widgets.dart';
import '../bloc/code_bloc.dart';
import '../phone_mask.dart';
import '../widgets/auth_art.dart';

/// Code entry (`/auth/code`), the design's SignIn in its code state: the 4 code boxes, filled in automatically on
/// Android and sent as soon as they are full, the resend countdown, then sign-in. A verified code signs in and the
/// router moves the player on; nothing navigates from here. Expects a [CodeBloc] above it.
class CodePage extends StatefulWidget {
  const CodePage({super.key, this.smsRetriever});

  /// Reads the code from the SMS. Null: the platform's ([OtpSmsRetriever.forPlatform], Android only).
  final SmsRetriever? smsRetriever;

  static const Key resendCountdownKey = Key('code.resendCountdown');

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final SmsRetriever? _retriever = widget.smsRetriever ?? OtpSmsRetriever.forPlatform();

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _verify([String? code]) => context.read<CodeBloc>().add(CodeSubmitted(code ?? _code.text));

  void _editPhone() {
    if (context.canPop()) {
      // Phone entry below keeps the number as typed.
      context.pop();
    } else {
      context.go(Routes.phone);
    }
  }

  Future<void> _showBlocked(String message) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.block_rounded),
        title: const Text(AppStrings.accountBlockedTitle),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text(AppStrings.understood)),
        ],
      ),
    );
    if (mounted) context.read<CodeBloc>().add(const CodeBlockedDismissed());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<CodeBloc, CodeState>(
            listenWhen: (previous, current) => current.errorCount != previous.errorCount,
            listener: (context, state) {
              _code.clear();
              if (state.blockedMessage == null) _focus.requestFocus();
            },
          ),
          BlocListener<CodeBloc, CodeState>(
            listenWhen: (previous, current) => current.resentCount > previous.resentCount,
            listener: (context, state) => AppSnackbar.info(context, AppStrings.codeResent),
          ),
          BlocListener<CodeBloc, CodeState>(
            listenWhen: (previous, current) => previous.blockedMessage == null && current.blockedMessage != null,
            listener: (context, state) => _showBlocked(state.blockedMessage!),
          ),
        ],
        child: BlocBuilder<CodeBloc, CodeState>(
          builder: (context, state) => AuthLayout(
            title: AppStrings.codeHeading,
            subtitle: Column(
              children: [
                Text(AppStrings.codeSentTo(PhoneMask.mask(state.phoneNumber))),
                TextButton.icon(
                  onPressed: _editPhone,
                  icon: const Icon(Icons.edit_outlined, size: AppIconSize.sm),
                  label: const Text(AppStrings.editPhone),
                ),
              ],
            ),
            children: [
              OtpBoxes(
                controller: _code,
                focusNode: _focus,
                enabled: state.status != CodeStatus.verifying && state.status != CodeStatus.verified,
                errorText: state.error,
                smsRetriever: _retriever,
                onCompleted: _verify,
                // Only typing clears the message: emptying the boxes after a refused code changes the text too.
                onChanged: (value) {
                  if (value.isNotEmpty) context.read<CodeBloc>().add(const CodeChanged());
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: state.resendSecondsLeft > 0
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
                        child: Center(
                          key: CodePage.resendCountdownKey,
                          child: Text(
                            AppStrings.resendCodeAfter(Countdown.label(state.resendSecondsLeft)),
                            style: theme.textTheme.labelMedium?.copyWith(color: palette.muted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : AppButton.ghost(
                        label: AppStrings.resendCode,
                        expanded: false,
                        compact: true,
                        loading: state.status == CodeStatus.resending,
                        onPressed: state.canResend
                            ? () => context.read<CodeBloc>().add(const CodeResendRequested())
                            : null,
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _code,
                builder: (context, value, _) => AppButton(
                  label: AppStrings.verifyCode,
                  loading: state.status == CodeStatus.verifying || state.status == CodeStatus.verified,
                  onPressed: value.text.length == otpLength && !state.isBusy ? _verify : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
