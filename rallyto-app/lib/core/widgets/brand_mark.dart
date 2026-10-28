import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which colours the mark is drawn in.
enum BrandMarkStyle {
  /// For brand green or dark backgrounds: white trail → ball-yellow ball, ball-yellow trail → white ball. The app
  /// tile uses it.
  reversed,

  /// For light backgrounds: court-green trail → clay ball, clay trail → court-green ball.
  color,

  /// One colour (ink): silhouettes and print.
  mono,
}

/// The Rallyto mark, the "rally loop": two tapered arcs close a ring, each the path of a shot that ends in the ball
/// reaching the partner. Each player's shot, in their colour, travels round to the other's ball.
///
/// Painted from the brand's geometry (branding/mark.json, a 100×100 grid) rather than shipped as an image, so it stays
/// sharp at any size without an asset or an SVG dependency. Decorative unless given a [semanticLabel].
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 48,
    this.style = BrandMarkStyle.color,
    this.semanticLabel,
    this.rotationDegrees = 0,
  });

  final double size;
  final BrandMarkStyle style;

  /// Read by screen readers; null when the name is already spelled out next to the mark.
  final String? semanticLabel;

  /// The whole mark turned clockwise about its centre (the launch splash spins it); 0 is the brand's pose.
  final double rotationDegrees;

  @override
  Widget build(BuildContext context) => _labelled(
    semanticLabel,
    CustomPaint(
      size: Size.square(size),
      painter: BrandMarkPainter(style: style, rotationDegrees: rotationDegrees),
    ),
  );
}

/// The app tile (branding/appicon.svg): the rounded court-green gradient square with the reversed mark at
/// [markScale] of its side, as on the launcher, the native splash and the launch splash.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, this.size = 96, this.semanticLabel, this.markRotationDegrees = 0});

  /// The mark's side as a share of the tile's, so the balls keep a margin from the edge (build_brand.py
  /// `TILE_MARK_SCALE`).
  static const double markScale = 0.9;

  final double size;

  /// Read by screen readers; null when the name is already spelled out next to the tile.
  final String? semanticLabel;

  /// The mark turned clockwise inside the still tile (the launch splash spins it); 0 is the brand's pose.
  final double markRotationDegrees;

  @override
  Widget build(BuildContext context) => _labelled(
    semanticLabel,
    Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * BrandMarkPainter.tileCornerRadius / BrandMarkPainter.grid),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandMarkPainter.tileGradientFrom, BrandMarkPainter.tileGradientTo],
        ),
      ),
      child: CustomPaint(
        size: Size.square(size * markScale),
        painter: BrandMarkPainter(style: BrandMarkStyle.reversed, rotationDegrees: markRotationDegrees),
      ),
    ),
  );
}

Widget _labelled(String? label, Widget mark) => label == null
    ? ExcludeSemantics(child: mark)
    : Semantics(label: label, image: true, excludeSemantics: true, child: mark);

/// Paints the mark on its 100×100 grid, scaled to the canvas.
///
/// Trail A runs clockwise along the ring from [trailFromDegrees] to [trailToDegrees] (screen angles: 0° is +x,
/// clockwise positive), its half-width growing as `(trailWidth / 2) · t^trailTaper` from a point at the tail to a round
/// head; ball A sits on the ring at [ballAngleDegrees]. Trail B and ball B are A turned 180°.
///
/// The constants mirror branding/mark.json, the one source of every brand file; brand_mark_test.dart fails when they
/// drift apart. The colours are fixed brand values, not theme tokens: the mark looks the same in every theme.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.style = BrandMarkStyle.color, this.rotationDegrees = 0});

  // mark.json › grid, center, ringRadius
  static const double grid = 100;
  static const Offset center = Offset(50, 50);
  static const double ringRadius = 25;

  // mark.json › trail
  static const double trailFromDegrees = -205;
  static const double trailToDegrees = -36;
  static const double trailWidth = 13;
  static const double trailTaper = 0.85;
  static const int trailSamples = 48;

  // mark.json › ball
  static const double ballAngleDegrees = -36;
  static const double ballRadius = 10.5;

  // mark.json › tile
  static const double tileCornerRadius = 23;
  static const Color tileGradientFrom = Color(0xFF187658);
  static const Color tileGradientTo = Color(0xFF0B4C3A);

  // mark.json › colors
  static const Color green = Color(0xFF146B52);
  static const Color greenDeep = Color(0xFF0B4C3A);
  static const Color ball = Color(0xFFD9EF70);
  static const Color white = Color(0xFFFFFFFF);
  static const Color clay = Color(0xFFE9783C);
  static const Color canvas = Color(0xFFF5F8F7);
  static const Color ink = Color(0xFF172522);

  final BrandMarkStyle style;

  /// The whole mark turned clockwise about [center], in degrees.
  final double rotationDegrees;

  /// The point [radius] from [center] at [degrees] (screen angle).
  static Offset point(double radius, double degrees) {
    final a = degrees * math.pi / 180;
    return center + Offset(radius * math.cos(a), radius * math.sin(a));
  }

  /// The colours of each part in [style].
  static ({Color trailA, Color ballA, Color trailB, Color ballB}) colorsOf(BrandMarkStyle style) => switch (style) {
    BrandMarkStyle.reversed => (trailA: white, ballA: ball, trailB: ball, ballB: white),
    BrandMarkStyle.color => (trailA: green, ballA: clay, trailB: clay, ballB: green),
    BrandMarkStyle.mono => (trailA: ink, ballA: ink, trailB: ink, ballB: ink),
  };

  /// A trail turned by [turnDegrees]: the outer edge from tail to head, the round head cap, the inner edge back.
  static Path trailPath(double turnDegrees) {
    const from = trailFromDegrees, to = trailToDegrees;
    final outer = <Offset>[], inner = <Offset>[];
    for (var k = 0; k <= trailSamples; k++) {
      final t = k / trailSamples;
      final angle = from + (to - from) * t + turnDegrees;
      final half = trailWidth / 2 * math.pow(t, trailTaper);
      outer.add(point(ringRadius + half, angle));
      inner.add(point(ringRadius - half, angle));
    }
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final p in outer.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.arcToPoint(inner.last, radius: const Radius.circular(trailWidth / 2));
    for (final p in inner.reversed.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // The geometry never changes; only the colours and the turn do.
  static final Path _trailA = trailPath(0);
  static final Path _trailB = trailPath(180);
  static final Offset _ballA = point(ringRadius, ballAngleDegrees);
  static final Offset _ballB = point(ringRadius, ballAngleDegrees + 180);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = colorsOf(style);
    final paint = Paint()..isAntiAlias = true;
    canvas
      ..save()
      ..scale(size.width / grid, size.height / grid);
    if (rotationDegrees % 360 != 0) {
      canvas
        ..translate(center.dx, center.dy)
        ..rotate(rotationDegrees * math.pi / 180)
        ..translate(-center.dx, -center.dy);
    }
    // The SVG's order: both trails, then both balls (ball A covers the point of trail B's tail).
    canvas
      ..drawPath(_trailA, paint..color = colors.trailA)
      ..drawPath(_trailB, paint..color = colors.trailB)
      ..drawCircle(_ballA, ballRadius, paint..color = colors.ballA)
      ..drawCircle(_ballB, ballRadius, paint..color = colors.ballB)
      ..restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.rotationDegrees != rotationDegrees;
}
