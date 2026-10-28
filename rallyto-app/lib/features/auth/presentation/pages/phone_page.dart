import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/auth/auth_session_cubit.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/widgets/widgets.dart';
import '../bloc/phone_bloc.dart';
import '../widgets/auth_art.dart';

/// Phone entry (`/auth/phone`), the design's SignIn: the brand art, a welcome, the mobile number and «دریافت کد», then
/// on to code entry. Expects a [PhoneBloc] and the app's [AuthSessionCubit] above it.
class PhonePage extends StatefulWidget {
  const PhonePage({super.key});

  /// Key of the number field, for tests.
  static const Key phoneFieldKey = Key('phone-field');
  static const Key serverErrorKey = Key('phone.serverError');
  static const Key signOutNoticeKey = Key('phone.signOutNotice');
  static const Key deletedNoticeKey = Key('phone.deletedNotice');

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  late final TextEditingController _phone = TextEditingController(text: context.read<PhoneBloc>().state.phone);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<PhoneBloc>().add(const PhoneSubmitted());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: BlocListener<PhoneBloc, PhoneState>(
        listenWhen: (previous, current) =>
            previous.status != PhoneStatus.codeSent && current.status == PhoneStatus.codeSent,
        listener: (context, state) => context.push(Routes.code, extra: state.challenge),
        child: AuthLayout(
          title: AppStrings.phoneHeading,
          subtitle: const Text(AppStrings.signInTagline),
          children: [
            const _SignOutNotice(),
            BlocBuilder<PhoneBloc, PhoneState>(
              builder: (context, state) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: PhonePage.phoneFieldKey,
                    controller: _phone,
                    enabled: state.status != PhoneStatus.sending,
                    // A phone number reads left to right inside the right-to-left page.
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      // ASCII, Persian or Arabic digits, spaces and a leading + (as in +98 912 …).
                      FilteringTextInputFormatter.allow(RegExp('[0-9۰-۹٠-٩+ ]')),
                      LengthLimitingTextInputFormatter(17),
                    ],
                    decoration: InputDecoration(
                      labelText: AppStrings.phoneFieldLabel,
                      hintText: AppStrings.phoneFieldHint,
                      hintTextDirection: TextDirection.ltr,
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                      helperText: AppStrings.phoneExplanation,
                      helperMaxLines: 3,
                      errorText: state.fieldError,
                      errorMaxLines: 2,
                    ),
                    onChanged: (value) => context.read<PhoneBloc>().add(PhoneChanged(value)),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (state.serverError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: NoticeBanner(
                        key: PhonePage.serverErrorKey,
                        tone: NoticeTone.error,
                        body: state.serverError,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: state.cooldownSeconds > 0
                        ? AppStrings.sendCodeAfter(Countdown.label(state.cooldownSeconds))
                        : AppStrings.sendCode,
                    loading: state.status == PhoneStatus.sending,
                    onPressed: state.canSubmit ? _submit : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.signInTerms,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: context.palette.muted, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }
}

/// The server's words when it signed the player out (a suspended, banned or inactive account), or the word that the
/// player's account was deleted, until dismissed.
class _SignOutNotice extends StatelessWidget {
  const _SignOutNotice();

  @override
  Widget build(BuildContext context) {
    final (message, notice) = context.select<AuthSessionCubit, (String?, String?)>(
      (session) => switch (session.state) {
        Unauthenticated(:final message, :final notice) => (message, notice),
        Authenticated() => (null, null),
      },
    );
    if (message == null && notice == null) return const SizedBox.shrink();
    final palette = context.palette;
    final blocked = message != null;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Stack(
        key: blocked ? PhonePage.signOutNoticeKey : PhonePage.deletedNoticeKey,
        children: [
          Semantics(
            liveRegion: true,
            child: blocked
                ? NoticeBanner(
                    tone: NoticeTone.error,
                    icon: Icons.block_rounded,
                    title: AppStrings.accountBlockedTitle,
                    body: message,
                  )
                : NoticeBanner(
                    tone: NoticeTone.success,
                    icon: Icons.check_circle_outline_rounded,
                    title: AppStrings.accountDeletedTitle,
                    body: notice,
                  ),
          ),
          // The close button sits beside the short title line, at the notice's top end.
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              tooltip: AppStrings.dismiss,
              icon: Icon(
                Icons.close_rounded,
                size: AppIconSize.action,
                color: blocked ? palette.error : palette.success,
              ),
              onPressed: () => context.read<AuthSessionCubit>().dismissSignOutMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
