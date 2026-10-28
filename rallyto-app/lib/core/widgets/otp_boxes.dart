import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';
import '../constants/otp.dart';
import '../utils/persian_digits.dart';

/// The design's `.otp`: [length] (4) code boxes, 58×62, radius 14, reading left to right inside the right-to-left
/// page. Typing moves to the next box, a pasted or SMS-filled code fills them all, a Persian or Arabic keyboard's
/// digits become ASCII, and [onCompleted] fires once every box is filled (auto-submit).
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    this.controller,
    this.focusNode,
    this.length = otpLength,
    this.enabled = true,
    this.autofocus = true,
    this.errorText,
    this.onCompleted,
    this.onChanged,
    this.smsRetriever,
    this.semanticLabel = AppStrings.codeFieldLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final int length;
  final bool enabled;
  final bool autofocus;

  /// Shown under the boxes, which turn to the error colour.
  final String? errorText;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  /// Reads the code from the SMS (Android). Pinput asks it once and disposes it with the field.
  final SmsRetriever? smsRetriever;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final box = PinTheme(
      width: 58,
      height: 62,
      textStyle: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: palette.line),
      ),
    );
    PinTheme bordered(Color color) => box.copyWith(
      decoration: box.decoration!.copyWith(border: Border.all(color: color, width: 1.5)),
    );

    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            // A code reads left to right, whatever the page does.
            textDirection: TextDirection.ltr,
            child: Pinput(
              controller: controller,
              focusNode: focusNode,
              length: length,
              enabled: enabled,
              autofocus: autofocus,
              separatorBuilder: (_) => const SizedBox(width: 10),
              // The blinking cursor is motion: off when the player asked for less of it.
              isCursorAnimationEnabled: !MediaQuery.of(context).disableAnimations,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              smsRetriever: smsRetriever,
              inputFormatters: [PersianDigitsInputFormatter()],
              defaultPinTheme: box,
              focusedPinTheme: bordered(palette.primary),
              submittedPinTheme: box,
              errorPinTheme: bordered(palette.error),
              forceErrorState: errorText != null,
              onCompleted: onCompleted,
              onChanged: onChanged,
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                style: theme.textTheme.bodyMedium?.copyWith(color: palette.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
