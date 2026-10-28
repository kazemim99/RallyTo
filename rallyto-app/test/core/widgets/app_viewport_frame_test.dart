import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/core/widgets/app_viewport_frame.dart';

void main() {
  group('appliesTo', () {
    test('a phone-width viewport is never framed, on the web or not', () {
      expect(AppViewportFrame.appliesTo(const Size(412, 915), isWeb: true), isFalse);
      expect(AppViewportFrame.appliesTo(const Size(412, 915), isWeb: false), isFalse);
      expect(AppViewportFrame.appliesTo(const Size(AppViewportFrame.maxContentWidth, 900), isWeb: true), isFalse);
    });

    test('a wide browser window is framed, whatever its height', () {
      expect(AppViewportFrame.appliesTo(const Size(1440, 900), isWeb: true), isTrue);
      expect(AppViewportFrame.appliesTo(const Size(900, 500), isWeb: true), isTrue);
    });

    test('a native tablet is framed; a native phone in landscape keeps the whole screen', () {
      expect(AppViewportFrame.appliesTo(const Size(1280, 800), isWeb: false), isTrue);
      expect(AppViewportFrame.appliesTo(const Size(915, 412), isWeb: false), isFalse);
    });
  });

  Future<Size> pumpFrame(WidgetTester tester, Size window, {required bool isWeb}) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppViewportFrame(
          isWeb: isWeb,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const Scaffold(
                body: Center(child: Text('محتوا', textDirection: TextDirection.rtl)),
              );
            },
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('on a wide browser window the app is a centred column of the maximum width, on a backdrop', (
    tester,
  ) async {
    final seen = await pumpFrame(tester, const Size(1440, 900), isWeb: true);

    final column = tester.getRect(find.byKey(AppViewportFrame.columnKey));
    expect(find.byKey(AppViewportFrame.backdropKey), findsOneWidget);
    expect(column.width, AppViewportFrame.maxContentWidth);
    expect(column.height, 900);
    expect(column.center.dx, 720, reason: 'centred horizontally');
    expect(seen, const Size(AppViewportFrame.maxContentWidth, 900), reason: 'MediaQuery reports the column');
  });

  testWidgets('the backdrop is darker than the canvas, so the column reads as a surface', (tester) async {
    await pumpFrame(tester, const Size(1440, 900), isWeb: true);

    final backdrop = tester.widget<ColoredBox>(find.byKey(AppViewportFrame.backdropKey)).color;
    expect(backdrop.computeLuminance(), lessThan(AppTheme.lightScheme.surface.computeLuminance()));
  });

  testWidgets('a phone-width window gets no frame and the full width', (tester) async {
    final seen = await pumpFrame(tester, const Size(412, 915), isWeb: true);

    expect(find.byKey(AppViewportFrame.backdropKey), findsNothing);
    expect(find.byKey(AppViewportFrame.columnKey), findsNothing);
    expect(seen, const Size(412, 915));
  });

  testWidgets('a bottom sheet opened inside the frame is as wide as the column, not the window', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => AppViewportFrame(isWeb: true, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(key: ValueKey('sheet-content'), height: 120, width: double.infinity),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const ValueKey('sheet-content'))).width, AppViewportFrame.maxContentWidth);
  });
}
