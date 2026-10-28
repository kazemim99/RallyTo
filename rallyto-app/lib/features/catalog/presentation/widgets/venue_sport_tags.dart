import 'package:flutter/material.dart';

import '../../../../config/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/venue.dart';
import '../catalog_labels.dart';

/// A venue's sports as small chips: «تنیس ۶ زمین», «پدل ۲ زمین».
class VenueSportTags extends StatelessWidget {
  const VenueSportTags({super.key, required this.sports, required this.sportNames});

  final List<VenueSport> sports;

  /// Persian names by sport code.
  final Map<String, String> sportNames;

  @override
  Widget build(BuildContext context) {
    if (sports.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      children: [for (final sport in sports) AppChip(label: CatalogLabels.sportTag(sport, sportNames))],
    );
  }
}
