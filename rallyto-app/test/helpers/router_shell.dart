import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/config/theme/app_theme.dart';
import 'package:rallyto_app/main.dart';

/// Pumps [routes] under a [GoRouter] starting at [initialLocation], inside the app's shell (Persian, right-to-left,
/// the app theme, animations off), for screens that navigate.
Future<GoRouter> pumpRouter(WidgetTester tester, List<RouteBase> routes, {String initialLocation = '/'}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(locale: appLocale, theme: AppTheme.light, builder: buildAppShell, routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

/// A stand-in screen for a route the test only needs to land on: shows its location (and `extra`, when a string).
GoRoute landingRoute(String path) => GoRoute(
  path: path,
  builder: (context, state) =>
      Scaffold(body: Text('landed ${state.uri.path}${state.extra is String ? ' ${state.extra}' : ''}')),
);
