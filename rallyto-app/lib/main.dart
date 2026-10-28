import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'core/auth/auth_session_cubit.dart';
import 'core/constants/app_strings.dart';
import 'core/di/injection.dart';
import 'core/realtime/realtime_lifecycle.dart';
import 'core/widgets/app_viewport_frame.dart';
import 'core/widgets/launch_splash.dart';
import 'features/notifications/presentation/push_registration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  // The stored session is read before the first frame, so the router starts on the right screen.
  final session = getIt<AuthSessionCubit>();
  await session.restore();

  // The realtime hub while signed in and in the foreground; push (when Firebase is configured) for the rest. Neither
  // waits: push that cannot start leaves the app running without it.
  getIt<RealtimeLifecycle>().start();
  final push = getIt<PushRegistration>();
  unawaited(push.start());

  runApp(RallytoApp(session: session, deepLinks: push.deepLinks));
}

/// The app: Persian only, right-to-left, Material 3 in light and dark.
class RallytoApp extends StatefulWidget {
  const RallytoApp({super.key, required this.session, this.deepLinks});

  final AuthSessionCubit session;

  /// App locations to open as they come (a tapped push).
  final Stream<String>? deepLinks;

  @override
  State<RallytoApp> createState() => _RallytoAppState();
}

class _RallytoAppState extends State<RallytoApp> {
  late final AppRouter _router = AppRouter(widget.session);
  StreamSubscription<String>? _deepLinks;

  @override
  void initState() {
    super.initState();
    _deepLinks = widget.deepLinks?.listen((location) => _router.router.push(location));
  }

  @override
  void dispose() {
    unawaited(_deepLinks?.cancel());
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.session,
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        locale: appLocale,
        supportedLocales: const [appLocale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Light only: the approved design has no dark version, so the app ignores the device's dark mode.
        // `AppTheme.dark` exists and is tested, ready for when a dark design is made.
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        // The frame keeps the app phone-shaped in a desktop browser or on a tablet; a phone is never framed. The launch
        // splash covers the whole window, frame included, once per app start.
        builder: (context, child) => LaunchSplash(child: AppViewportFrame(child: buildAppShell(context, child))),
        routerConfig: _router.router,
      ),
    );
  }
}

/// The only locale: Persian (Iran).
const Locale appLocale = Locale('fa', 'IR');

/// Wraps every route (MaterialApp.builder): right-to-left throughout.
Widget buildAppShell(BuildContext context, Widget? child) {
  return Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink());
}
