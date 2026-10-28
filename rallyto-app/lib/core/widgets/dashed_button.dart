import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's `.new-game`: a full-width 50dp button with a dashed green border and green text, for «add another»
/// actions («ساخت بازی جدید»).
class DashedButton extends StatelessWidget {
  const DashedButton({super.key, required this.label, required this.onPressed, this.icon = Icons.add_rounded});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = onPressed == null ? palette.muted : palette.primary;
    final radius = BorderRadius.circular(AppRadius.button);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(color: color, radius: AppRadius.button),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: SizedBox(
              height: AppSizes.control,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: color, size: AppIconSize.action),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded-rectangle border.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, this.radius = AppRadius.button, this.dash = 5, this.gap = 4});

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(0.5);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius || oldDelegate.dash != dash || oldDelegate.gap != gap;
}
