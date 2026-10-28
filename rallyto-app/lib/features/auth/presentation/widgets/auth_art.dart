import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_palette.dart';
import '../../../../config/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/widgets.dart';

/// A sign-in screen's scrolling body: the [AuthArt] at the top, then [children] at the screen's side padding, with a
/// centred bold title and muted subtitle as the design's `.auth h1` and `.auth > p`.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.children});

  final String title;
  final Widget subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const AuthArt(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                ),
                const SizedBox(height: AppSpacing.xs),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted),
                  textAlign: TextAlign.center,
                  child: subtitle,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The sign-in screens' header (design `.auth-art`): dark green, rounded at the bottom, the court-lines motif centred
/// behind the white brand square holding the [BrandMark]. It runs under the status bar, whose icons it turns light.
class AuthArt extends StatelessWidget {
  const AuthArt({super.key});

  static const Key brandKey = Key('auth.brand');

  /// The art's height below the status bar (design 240).
  static const double height = 240;

  /// The brand square's side (design 76) and corner radius (design 22), and the mark's share of its side.
  static const double _squareSize = 76;
  static const double _squareRadius = 22;
  static const double _markScale = 0.8;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: height + topInset,
        padding: EdgeInsetsDirectional.only(top: topInset),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.primaryDark,
          borderRadius: const BorderRadiusDirectional.vertical(bottom: Radius.circular(AppRadius.lg)),
        ),
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            const ExcludeSemantics(child: CourtLines(width: 220, height: 220, angle: 0)),
            Semantics(
              key: brandKey,
              label: AppStrings.brandName,
              image: true,
              excludeSemantics: true,
              child: Container(
                width: _squareSize,
                height: _squareSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: palette.onBrand, borderRadius: BorderRadius.circular(_squareRadius)),
                child: const BrandMark(size: _squareSize * _markScale, style: BrandMarkStyle.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
