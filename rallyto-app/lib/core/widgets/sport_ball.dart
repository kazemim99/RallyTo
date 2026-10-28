import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';

/// The design's `.sport-ball`: a round, ball-yellow badge with the sport's initial or symbol ([label]), read out as
/// [semanticLabel] (the sport's name).
class SportBall extends StatelessWidget {
  const SportBall({super.key, required this.label, this.semanticLabel, this.size = 42});

  final String label;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: palette.ball, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w800, color: palette.onBall, height: 1.2),
        ),
      ),
    );
  }
}
