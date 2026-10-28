import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_palette.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/main.dart';

/// The launch splash: it takes over from the native splash on its first frame, plays the rally once, then leaves the
/// app (built and running underneath all along) on its own. Reduced motion skips it.
void main() {
  final overlay = find.byKey(LaunchSplash.overlayKey);
  final tile = find.descendant(of: overlay, matching: find.byType(BrandTile));

  /// The app as `main()` builds it, with a [_Probe] for a home screen.
  Future<void> pumpApp(WidgetTester tester, {String label = 'app'}) => tester.pumpWidget(
    MaterialApp(
      locale: appLocale,
      theme: AppTheme.light,
      builder: (context, child) => LaunchSplash(child: buildAppShell(context, child)),
      home: _Probe(label: label),
    ),
  );

  Offset windowCenter(WidgetTester tester) =>
      (tester.view.physicalSize / tester.view.devicePixelRatio).center(Offset.zero);
  double turn(WidgetTester tester) => tester.widget<BrandTile>(tile).markRotationDegrees;

  testWidgets('its first frame is the native splash: the canvas with the 96dp tile centred, over the app', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(overlay, findsOneWidget);
    expect(tester.widget<Material>(overlay).color, AppPalette.light.canvas);
    expect(tester.getRect(tile), Rect.fromCenter(center: windowCenter(tester), width: 96, height: 96));
    expect(turn(tester), 0, reason: 'the brand pose, as the native splash draws it');
    expect(find.text(AppStrings.appName), findsNothing, reason: 'the wordmark comes later');
    expect(find.byType(_Probe), findsOneWidget, reason: 'the app is built underneath from the start');
  });

  testWidgets('the rally: one full turn ending in the brand pose, a landing pop, then the wordmark under the tile', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.pump(LaunchSplash.spinEnd ~/ 2);
    expect(turn(tester), closeTo(360 * Curves.easeInOutCubic.transform(0.5), 0.5), reason: 'about half way round');

    await tester.pump(LaunchSplash.spinEnd ~/ 2);
    expect(tester.getRect(tile).width, closeTo(96 * 1.06, 0.5), reason: 'the landing pop at its peak');

    await tester.pump(const Duration(milliseconds: 10));
    expect(turn(tester), 0, reason: 'a full turn ends exactly in the static pose');

    await tester.pump(const Duration(milliseconds: 440)); // 1200 ms: the glide is over
    final rect = tester.getRect(tile);
    expect(rect.size, const Size.square(96));
    expect(rect.center, windowCenter(tester) - const Offset(0, LaunchSplash.glideDistance));
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);
    expect(tester.getRect(find.text(AppStrings.appName)).top, closeTo(rect.bottom + 16, 0.5));
    expect(
      tester.getRect(find.text(AppStrings.appTagline)).top,
      greaterThan(tester.getRect(find.text(AppStrings.appName)).bottom - 0.5),
    );
  });

  testWidgets('fades out and leaves after the timeline; the app keeps its state and nothing keeps animating', (
    tester,
  ) async {
    await pumpApp(tester);
    final app = tester.state(find.byType(_Probe));

    await tester.pump(const Duration(milliseconds: 1475));
    final fade = tester.widget<Opacity>(find.ancestor(of: overlay, matching: find.byType(Opacity)).first).opacity;
    expect(fade, inExclusiveRange(0, 1), reason: 'fading out');

    await tester.pump(const Duration(milliseconds: 125)); // 1600 ms: the last frame of the fade
    await tester.pump(const Duration(milliseconds: 16));
    expect(overlay, findsNothing);
    expect(find.byType(BrandTile), findsNothing);
    expect(tester.state(find.byType(_Probe)), same(app), reason: 'the app underneath was never rebuilt from scratch');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('absorbs taps while it shows, and stays out of the semantics tree', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byType(TextButton), warnIfMissed: false);
    await tester.pump();
    expect(find.text('app 0'), findsOneWidget, reason: 'the tap did not reach the app');
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.bySemanticsLabel(AppStrings.appName), findsNothing);

    await tester.pump(LaunchSplash.duration);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('app 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with reduced motion there is no splash at all', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);

    expect(overlay, findsNothing);
    expect(find.byType(BrandTile), findsNothing);
    expect(find.byType(_Probe), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion turned on mid-splash removes it at once', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 300));

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();

    expect(overlay, findsNothing);
    expect(find.byType(_Probe), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('plays once per start: a rebuild neither restarts nor replays it', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 1000));

    await pumpApp(tester, label: 'rebuilt');
    expect(overlay, findsOneWidget, reason: 'still playing');
    expect(turn(tester), 0, reason: 'not restarted: the spin stays over');

    await tester.pump(const Duration(milliseconds: 616));
    expect(overlay, findsNothing, reason: 'finished on the original timeline');

    await pumpApp(tester, label: 'again');
    await tester.pump(const Duration(milliseconds: 100));
    expect(overlay, findsNothing, reason: 'never replays');
  });
}

/// A home screen with a tap counter, to see whether taps reach the app and whether its state survives.
class _Probe extends StatefulWidget {
  const _Probe({required this.label});

  final String label;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(onPressed: () => setState(() => _taps++), child: Text('${widget.label} $_taps')),
      ),
    );
  }
}
