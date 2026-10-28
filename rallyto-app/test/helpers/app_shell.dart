import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/main.dart';

/// Pumps [home] inside the app's shell: Persian, right-to-left, the app theme, animations off.
Future<void> pumpInShell(WidgetTester tester, Widget home) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(MaterialApp(locale: appLocale, theme: AppTheme.light, builder: buildAppShell, home: home));
  await tester.pumpAndSettle();
}
