import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_colors.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';

/// The painted mark is the brand's mark: every number and colour mirrors branding/mark.json (the source of every brand
/// file and raster), the balls land where the generated SVGs put them, and it paints and reads out at any size.
void main() {
  // Tests run from the app folder; the brand's source files live in the repository's branding/ folder.
  String brandFile(String name) => File('../branding/$name').readAsStringSync();
  final spec = jsonDecode(brandFile('mark.json')) as Map<String, dynamic>;
  Map<String, dynamic> section(String key) => spec[key] as Map<String, dynamic>;
  double n(Object? v) => (v! as num).toDouble();
  Color hex(Object? v) => Color(int.parse('FF${(v! as String).substring(1)}', radix: 16));

  group('mirrors branding/mark.json', () {
    test('the grid, centre and ring', () {
      expect(n(spec['grid']), BrandMarkPainter.grid);
      final center = spec['center'] as List<dynamic>;
      expect(Offset(n(center[0]), n(center[1])), BrandMarkPainter.center);
      expect(n(spec['ringRadius']), BrandMarkPainter.ringRadius);
    });

    test('the trail', () {
      final trail = section('trail');
      expect(n(trail['fromDeg']), BrandMarkPainter.trailFromDegrees);
      expect(n(trail['toDeg']), BrandMarkPainter.trailToDegrees);
      expect(n(trail['width']), BrandMarkPainter.trailWidth);
      expect(n(trail['taper']), BrandMarkPainter.trailTaper);
      expect(trail['samples'], BrandMarkPainter.trailSamples);
    });

    test('the ball', () {
      final ball = section('ball');
      expect(n(ball['angleDeg']), BrandMarkPainter.ballAngleDegrees);
      expect(n(ball['radius']), BrandMarkPainter.ballRadius);
    });

    test('the tile', () {
      final tile = section('tile');
      expect(n(tile['cornerRadius']), BrandMarkPainter.tileCornerRadius);
      expect(hex(tile['gradientFrom']), BrandMarkPainter.tileGradientFrom);
      expect(hex(tile['gradientTo']), BrandMarkPainter.tileGradientTo);
    });

    test('every colour, and no colour the painter does not have', () {
      final colors = section('colors');
      const dart = {
        'green': BrandMarkPainter.green,
        'greenDeep': BrandMarkPainter.greenDeep,
        'ball': BrandMarkPainter.ball,
        'white': BrandMarkPainter.white,
        'clay': BrandMarkPainter.clay,
        'canvas': BrandMarkPainter.canvas,
        'ink': BrandMarkPainter.ink,
      };
      expect(colors.keys.toSet(), dart.keys.toSet());
      for (final name in dart.keys) {
        expect(hex(colors[name]), dart[name], reason: name);
      }
    });

    test('the tile draws the mark at the scale of branding/appicon.svg', () {
      final scale = RegExp(r'scale\(([\d.]+)\)').firstMatch(brandFile('appicon.svg'))!.group(1)!;
      expect(double.parse(scale), BrandTile.markScale);
    });
  });

  group('matches the generated SVGs', () {
    /// Each `<path>` (trail A, trail B) and `<circle>` (ball A, ball B) of a symbol SVG, in drawing order.
    ({List<(Offset, Color)> trails, List<(Offset, double, Color)> balls}) parts(String svg) => (
      trails: RegExp(
        r'<path d="M([\d.]+) ([\d.]+) [^"]*" fill="(#[0-9A-Fa-f]{6})"',
      ).allMatches(svg).map((m) => (Offset(double.parse(m[1]!), double.parse(m[2]!)), hex(m[3]))).toList(),
      balls: RegExp(r'<circle cx="([\d.]+)" cy="([\d.]+)" r="([\d.]+)" fill="(#[0-9A-Fa-f]{6})"')
          .allMatches(svg)
          .map((m) => (Offset(double.parse(m[1]!), double.parse(m[2]!)), double.parse(m[3]!), hex(m[4])))
          .toList(),
    );

    // The SVGs round coordinates to two decimals.
    Matcher near(Offset expected) => isA<Offset>().having((o) => (o - expected).distance, 'distance', lessThan(0.01));

    for (final (file, style) in [
      ('symbol-reversed.svg', BrandMarkStyle.reversed),
      ('symbol-color.svg', BrandMarkStyle.color),
      ('symbol-mono.svg', BrandMarkStyle.mono),
    ]) {
      test('$file: the trails start and the balls sit where the painter puts them, in the same colours', () {
        final svg = parts(brandFile(file));
        final colors = BrandMarkPainter.colorsOf(style);
        const r = BrandMarkPainter.ringRadius, tail = BrandMarkPainter.trailFromDegrees;
        const ball = BrandMarkPainter.ballAngleDegrees;

        expect(svg.trails, hasLength(2));
        expect(svg.trails[0].$1, near(BrandMarkPainter.point(r, tail)));
        expect(svg.trails[1].$1, near(BrandMarkPainter.point(r, tail + 180)));
        expect(svg.balls, hasLength(2));
        expect(svg.balls[0].$1, near(BrandMarkPainter.point(r, ball)));
        expect(svg.balls[1].$1, near(BrandMarkPainter.point(r, ball + 180)));
        expect(svg.balls.map((b) => b.$2), everyElement(BrandMarkPainter.ballRadius));
        expect(
          [svg.trails[0].$2, svg.trails[1].$2, svg.balls[0].$3, svg.balls[1].$3],
          [colors.trailA, colors.trailB, colors.ballA, colors.ballB],
        );
      });
    }
  });

  test('the theme carries the brand colours, so the app, its icon and its native splash agree', () {
    expect(AppColors.primary, BrandMarkPainter.green);
    expect(AppColors.primaryDark, BrandMarkPainter.greenDeep);
    expect(AppColors.accent, BrandMarkPainter.clay);
    expect(AppColors.ball, BrandMarkPainter.ball);
    expect(AppColors.ink, BrandMarkPainter.ink);
    expect(AppColors.onPrimary, BrandMarkPainter.white);
    expect(AppColors.canvas, BrandMarkPainter.canvas, reason: 'the native splash background is the canvas');
  });

  group('painting', () {
    test('paints every style, turned or not, at any size', () {
      for (final style in BrandMarkStyle.values) {
        for (final rotation in [0.0, 90.0, 360.0]) {
          for (final size in [
            const Size.square(1),
            const Size.square(24),
            const Size.square(512),
            const Size(40, 60),
          ]) {
            final recorder = ui.PictureRecorder();
            BrandMarkPainter(style: style, rotationDegrees: rotation).paint(Canvas(recorder), size);
            recorder.endRecording().dispose();
          }
        }
      }
    });

    test('repaints only when the style or the turn changes', () {
      const still = BrandMarkPainter(style: BrandMarkStyle.reversed);
      expect(still.shouldRepaint(const BrandMarkPainter(style: BrandMarkStyle.reversed)), isFalse);
      expect(still.shouldRepaint(const BrandMarkPainter(style: BrandMarkStyle.color)), isTrue);
      expect(still.shouldRepaint(const BrandMarkPainter(style: BrandMarkStyle.reversed, rotationDegrees: 10)), isTrue);
    });

    testWidgets('lays out at the size asked for', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            children: [
              BrandMark(size: 16),
              BrandMark(size: 48, style: BrandMarkStyle.reversed),
              BrandMark(size: 120, style: BrandMarkStyle.mono, rotationDegrees: 45),
              BrandTile(size: 24),
              BrandTile(),
              BrandTile(size: 192, markRotationDegrees: 200),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      for (final mark in tester.widgetList<BrandMark>(find.byType(BrandMark))) {
        expect(tester.getSize(find.byWidget(mark)), Size.square(mark.size));
      }
      expect(tester.getSize(find.byType(BrandTile).first), const Size.square(24));
      expect(tester.getSize(find.byType(BrandTile).at(1)), const Size.square(96), reason: 'the native splash size');
      expect(tester.getSize(find.byType(BrandTile).last), const Size.square(192));
    });

    /// The colour at [at] of [widget] rendered alone at 100 logical pixels (1:1 with the brand grid).
    Future<Color> pixel(WidgetTester tester, Widget widget, Offset at) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(key: key, child: widget),
        ),
      );
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data;
      }))!;
      final i = 4 * (at.dy.round() * 100 + at.dx.round());
      return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    }

    testWidgets('puts ball A (clay) at the top right and ball B (green) at the bottom left, with the ring open', (
      tester,
    ) async {
      const r = BrandMarkPainter.ringRadius, ball = BrandMarkPainter.ballAngleDegrees;
      const mark = BrandMark(size: 100);
      expect(await pixel(tester, mark, BrandMarkPainter.point(r, ball)), BrandMarkPainter.clay);
      expect(await pixel(tester, mark, BrandMarkPainter.point(r, ball + 180)), BrandMarkPainter.green);
      expect((await pixel(tester, mark, BrandMarkPainter.center)).a, 0, reason: 'the centre of the loop is open');
    });

    testWidgets('turns the whole mark clockwise', (tester) async {
      const r = BrandMarkPainter.ringRadius, ball = BrandMarkPainter.ballAngleDegrees;
      const turned = BrandMark(size: 100, rotationDegrees: 90);
      expect(await pixel(tester, turned, BrandMarkPainter.point(r, ball + 90)), BrandMarkPainter.clay);
      expect(await pixel(tester, turned, BrandMarkPainter.point(r, ball + 270)), BrandMarkPainter.green);
    });

    testWidgets('the tile is the rounded gradient square with the reversed mark', (tester) async {
      const tile = BrandTile(size: 100);
      final center = BrandMarkPainter.center;
      // The mark is drawn at 90% about the centre.
      Offset inTile(Offset p) => center + (p - center) * BrandTile.markScale;
      const r = BrandMarkPainter.ringRadius, ball = BrandMarkPainter.ballAngleDegrees;

      expect((await pixel(tester, tile, const Offset(1, 1))).a, 0, reason: 'rounded corners');
      expect(await pixel(tester, tile, inTile(BrandMarkPainter.point(r, ball))), BrandMarkPainter.ball);
      expect(await pixel(tester, tile, inTile(BrandMarkPainter.point(r, ball + 180))), BrandMarkPainter.white);
      final middle = await pixel(tester, tile, center);
      expect(middle.a, 1, reason: 'the gradient fills the tile behind the open loop');
      expect(middle.g, greaterThan(middle.r), reason: 'court green');
    });
  });

  group('semantics', () {
    testWidgets('the mark and the tile are decorative unless given a label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              BrandMark(),
              BrandMark(semanticLabel: 'رالیتو'),
              BrandTile(),
              BrandTile(semanticLabel: 'نشان رالیتو'),
            ],
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(BrandMark).last), isSemantics(label: 'رالیتو', isImage: true));
      expect(tester.getSemantics(find.byType(BrandTile).last), isSemantics(label: 'نشان رالیتو', isImage: true));
      // Everything read out on the screen: only the two labels, nothing from the unlabelled mark and tile.
      final labels = <String>[];
      void visit(SemanticsNode node) {
        if (node.label.isNotEmpty) labels.add(node.label);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester.getSemantics(find.byType(Row)));
      expect(labels, unorderedEquals(['رالیتو', 'نشان رالیتو']));
      semantics.dispose();
    });
  });
}
