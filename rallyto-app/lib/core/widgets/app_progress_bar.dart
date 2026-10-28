import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';
import '../utils/display_join.dart';
import '../utils/persian_digits.dart';

/// The design's `.progress`: a 5dp bar, green on the line colour, filling from the start side. Read out as a
/// percentage unless [semanticLabel] says otherwise.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.semanticLabel, this.height = AppSizes.progressBar});

  /// 0 to 1; clamped.
  final double value;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = value.clamp(0.0, 1.0);
    final duration = MediaQuery.of(context).disableAnimations ? Duration.zero : AppMotion.normal;
    return Semantics(
      label: semanticLabel,
      value: AppStrings.progressPercent(PersianDigits.fromInt((v * 100).round())),
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: palette.line, borderRadius: BorderRadius.circular(height)),
        child: AnimatedFractionallySizedBox(
          duration: duration,
          curve: AppMotion.standard,
          alignment: AlignmentDirectional.centerStart,
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(height)),
          ),
        ),
      ),
    );
  }
}

/// A multi-step form's header: the progress bar and «مرحله ۲ از ۶» centred under it, after an optional [label]
/// («جزئیات بازی • مرحله ۲ از ۳»).
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.total, this.label});

  /// 1-based.
  final int step;
  final int total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final stepText = AppStrings.stepOf(PersianDigits.fromInt(step), PersianDigits.fromInt(total));
    final text = label == null ? stepText : [label ?? '', stepText].joinDisplay();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: AppProgressBar(value: total <= 0 ? 0 : step / total)),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.muted),
          ),
        ),
      ],
    );
  }
}
