import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  );

  group('AppButton', () {
    testWidgets('is at least 48dp tall and calls back on tap', (tester) async {
      var taps = 0;
      await pump(tester, AppButton(label: 'ثبت', onPressed: () => taps++));

      await tester.tap(find.text('ثبت'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('while loading shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await pump(tester, AppButton(label: 'ثبت', onPressed: () => taps++, loading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('ثبت'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });
  });

  testWidgets('ErrorState shows the message and retries', (tester) async {
    var retries = 0;
    await pump(tester, ErrorState(message: 'سرور در دسترس نیست', onRetry: () => retries++));

    expect(find.text('سرور در دسترس نیست'), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    expect(retries, 1);
  });

  testWidgets('ErrorState falls back to the generic message', (tester) async {
    await pump(tester, ErrorState(onRetry: () {}));

    expect(find.text(AppStrings.genericError), findsOneWidget);
  });

  testWidgets('EmptyState shows its call to action only with a handler', (tester) async {
    var taps = 0;
    await pump(
      tester,
      EmptyState(icon: Icons.sports_tennis, title: 'بازی‌ای نیست', ctaLabel: 'ساختن بازی', onCta: () => taps++),
    );
    await tester.tap(find.text('ساختن بازی'));
    expect(taps, 1);

    await pump(tester, const EmptyState(icon: Icons.sports_tennis, title: 'بازی‌ای نیست', ctaLabel: 'ساختن بازی'));
    expect(find.text('ساختن بازی'), findsNothing);
  });

  testWidgets('StateSwitcher renders each state', (tester) async {
    Widget switcher(ViewStatus status) =>
        StateSwitcher(status: status, contentBuilder: (_) => const Text('محتوا'), onRetry: () {}, errorMessage: 'خطا');

    await pump(tester, switcher(ViewStatus.loading));
    expect(find.byType(LoadingView), findsOneWidget);

    await pump(tester, switcher(ViewStatus.content));
    expect(find.text('محتوا'), findsOneWidget);

    await pump(tester, switcher(ViewStatus.empty));
    expect(find.text(AppStrings.noResultsTitle), findsOneWidget);

    await pump(tester, switcher(ViewStatus.error));
    expect(find.text('خطا'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('AppSnackbar shows the message', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) =>
            TextButton(onPressed: () => AppSnackbar.error(context, 'ذخیره نشد'), child: const Text('x')),
      ),
    );

    await tester.tap(find.text('x'));
    await tester.pump();
    expect(find.text('ذخیره نشد'), findsOneWidget);
  });
}
