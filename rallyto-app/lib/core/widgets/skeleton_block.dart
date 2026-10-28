import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';

/// The design's `.skeleton i`: a static, shimmer-free placeholder bar in the content's shape. With [pulse] it fades
/// gently while loading, unless the player asked for less motion (`MediaQuery.disableAnimations`), when it stays
/// still. Placeholders are hidden from screen readers; wrap a group in [SkeletonLines] (or label it) so loading is
/// announced once.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({super.key, this.width, this.height = 14, this.radius = AppSpacing.xs, this.pulse = false});

  /// Null fills the width.
  final double? width;
  final double height;
  final double radius;
  final bool pulse;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SkeletonBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.pulse && !MediaQuery.of(context).disableAnimations;
    if (animate && _controller == null) {
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
    } else if (!animate && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bar = ExcludeSemantics(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [palette.skeleton, Color.lerp(palette.skeleton, palette.surface, 0.6)!, palette.skeleton],
          ),
        ),
      ),
    );
    final controller = _controller;
    if (controller == null) return bar;
    return FadeTransition(opacity: Tween<double>(begin: 1, end: 0.55).animate(controller), child: bar);
  }
}

/// A stack of [count] placeholder lines (the last one shorter), announced once as «در حال بارگذاری…».
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.count = 3, this.lineHeight = 14, this.pulse = false});

  final int count;
  final double lineHeight;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.loading,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              SkeletonBlock(
                height: lineHeight,
                pulse: pulse,
                width: i == count - 1 && count > 1 && constraints.hasBoundedWidth ? constraints.maxWidth * 0.75 : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
