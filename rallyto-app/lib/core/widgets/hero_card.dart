import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's `.hero`: the brand gradient (primary → primaryDark), radius 24, a rotated court outline drawn in 15%
/// white at the end side, a muted [eyebrow], a large white [title], and a [cta] slot at the bottom (usually an
/// `AppButton.inverse`).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.title, this.eyebrow, this.cta, this.minHeight = 220});

  final String title;
  final String? eyebrow;
  final Widget? cta;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.brandStart, palette.brandEnd],
        ),
      ),
      child: Stack(
        children: [
          const PositionedDirectional(
            end: -42,
            top: 5,
            child: ExcludeSemantics(child: CourtLines(width: 190, height: 220, angle: 12)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight - 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xxs),
                            child: Text(
                              eyebrow!,
                              style: theme.textTheme.bodySmall?.copyWith(color: palette.onBrandMuted),
                            ),
                          ),
                        Text(title, style: theme.textTheme.displaySmall?.copyWith(color: palette.onBrand)),
                      ],
                    ),
                  ),
                  if (cta != null) ...[const SizedBox(height: AppSpacing.md), cta!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The court-lines motif (design `.court-lines`): a court outline with its centre lines and service box, rotated by
/// [angle] degrees, in [color] (default: 15% white). Decorative.
class CourtLines extends StatelessWidget {
  const CourtLines({super.key, this.width = 190, this.height = 220, this.angle = 12, this.color});

  final double width;
  final double height;
  final double angle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: CustomPaint(
        size: Size(width, height),
        painter: CourtLinesPainter(color ?? context.palette.onBrand.withValues(alpha: 0.15)),
      ),
    );
  }
}

/// Paints [CourtLines]: the outline, a horizontal and a vertical centre line, and the inner box (55% × 50%).
class CourtLinesPainter extends CustomPainter {
  const CourtLinesPainter(this.color, {this.strokeWidth = 2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawRect(Offset.zero & size, paint)
      ..drawLine(Offset(0, h / 2), Offset(w, h / 2), paint)
      ..drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint)
      ..drawRect(Rect.fromLTWH(w * 0.22, h * 0.25, w * 0.55, h * 0.5), paint);
  }

  @override
  bool shouldRepaint(CourtLinesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
