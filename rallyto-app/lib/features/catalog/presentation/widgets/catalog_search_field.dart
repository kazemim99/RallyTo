import 'package:flutter/material.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// The search box at the top of the catalog pickers (design `.searchbox`), at the screen's side padding.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.sm),
      child: SearchField(controller: controller, hint: hint, onChanged: onChanged),
    );
  }
}
