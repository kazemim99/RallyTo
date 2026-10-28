import 'package:flutter/material.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';

/// The design's `.check`: a 24dp green circle with a white tick when [checked], an empty ring otherwise. Decorative;
/// the row it sits in says whether it is checked.
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: AppIconSize.md,
      height: AppIconSize.md,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? palette.primary : null,
        border: checked ? null : Border.all(color: palette.navInactive, width: 2),
      ),
      child: checked ? Icon(Icons.check_rounded, size: AppIconSize.sm, color: palette.onPrimary) : null,
    );
  }
}
