import 'package:flutter/material.dart';

import '../../config/theme/app_palette.dart';
import '../../config/theme/app_tokens.dart';

/// The design's avatar sizes: [small] 30 (a host line), [medium] 38 (lists, the default), [large] 44 (chat rows),
/// [xlarge] 64 (profile heroes).
enum AppAvatarSize {
  small(30),
  medium(38),
  large(44),
  xlarge(64);

  const AppAvatarSize(this.dimension);

  final double dimension;
}

/// The design's `.avatar`: the first letter of [name] on a soft green gradient inside a 2px white ring, or the photo
/// at [photoUrl] when there is one (falling back to the letter if it cannot load). Read out as [name].
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = AppAvatarSize.medium, this.photoUrl});

  final String name;
  final AppAvatarSize size;
  final String? photoUrl;

  /// The letter shown for [name]: its first character, or «؟» for an empty name.
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '؟' : trimmed.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = size.dimension;
    final initial = Center(
      child: Text(
        initialOf(name),
        style: TextStyle(
          fontSize: d * (size == AppAvatarSize.xlarge ? 0.32 : 0.38),
          fontWeight: FontWeight.w800,
          color: palette.onPrimarySoft,
          height: 1.2,
        ),
      ),
    );
    final url = photoUrl;
    return Semantics(
      label: name,
      image: url != null,
      excludeSemantics: true,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.surface, width: 2),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [palette.primarySoft, palette.primarySoftBorder],
          ),
        ),
        child: ClipOval(
          child: url == null || url.isEmpty
              ? initial
              : Image.network(
                  url,
                  width: d,
                  height: d,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => initial,
                ),
        ),
      ),
    );
  }
}

/// The design's `.avatars`: up to [maxVisible] avatars overlapping by 10dp (the first at the start), and a muted
/// [caption] after them («شما و علی رضایی»).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    this.caption,
    this.size = AppAvatarSize.medium,
    this.maxVisible = 3,
  });

  final List<String> names;
  final String? caption;
  final AppAvatarSize size;
  final int maxVisible;

  static const double overlap = 10;

  @override
  Widget build(BuildContext context) {
    final visible = names.take(maxVisible).toList();
    final d = size.dimension;
    final step = d - overlap;
    final width = visible.isEmpty ? 0.0 : d + step * (visible.length - 1);
    return Semantics(
      container: true,
      label: caption ?? names.join('، '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: d,
            child: Stack(
              children: [
                for (var i = 0; i < visible.length; i++)
                  PositionedDirectional(
                    start: step * i,
                    top: 0,
                    child: AppAvatar(name: visible[i], size: size),
                  ),
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                caption!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
