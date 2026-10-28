import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/widgets.dart';
import '../../features/chat/domain/entities/chat.dart';
import '../../features/chat/presentation/bloc/chat_badge_cubit.dart';
import '../theme/app_tokens.dart';

/// The signed-in app's frame: the five tab stacks of a `StatefulShellRoute.indexedStack` ([navigationShell]) over
/// the bottom navigation bar. The bar carries the chat unread badge from the [ChatBadgeCubit] above it (the same
/// cubit the home page reads: `GET /conversations/unread`, re-read on every realtime message and polled while the
/// hub is down), and is re-read here whenever the player leaves a chat screen or changes tab.
///
/// The bar hides on the full-screen flows ([hiddenOn], by route pattern: forms and the conversation screen), which
/// are pushed inside the current tab's stack. Tapping the current tab again pops it to its root.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell, this.hiddenOn = const {}});

  final StatefulNavigationShell navigationShell;

  /// Route patterns (`GoRoute.path`, e.g. `/chat/:id`) on which the bar is hidden.
  final Set<String> hiddenOn;

  static const Key navKey = Key('shell.nav');
  static const List<Key> tabKeys = [
    Key('shell.tab.home'),
    Key('shell.tab.search'),
    Key('shell.tab.matches'),
    Key('shell.tab.chat'),
    Key('shell.tab.profile'),
  ];

  /// The tab index of the chat inbox.
  static const int chatTab = 3;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  GoRouter? _router;
  String? _topRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router?.routerDelegate.addListener(_onRouteChanged);
      _topRoute = _currentTopRoute();
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// The pattern of the route on top (`/chat/:id`), or null while there is none.
  String? _currentTopRoute() {
    final delegate = _router?.routerDelegate;
    if (delegate == null) return null;
    final matches = delegate.currentConfiguration;
    if (matches.isEmpty || matches.isError) return null;
    return delegate.state.fullPath;
  }

  static bool _isChatRoute(String? route) => route != null && (route.startsWith('/chat') || route.endsWith('/chat'));

  void _onRouteChanged() {
    if (!mounted) return;
    final previous = _topRoute;
    final current = _currentTopRoute();
    if (current == previous) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      _topRoute = current;
    } else {
      setState(() => _topRoute = current);
    }
    // Reading a conversation changes the unread counts; nothing else pushes them.
    if (_isChatRoute(previous) && !_isChatRoute(current)) _refreshBadge();
  }

  void _refreshBadge() {
    final cubit = context.read<ChatBadgeCubit>();
    if (!cubit.isClosed) unawaited(cubit.refresh());
  }

  void _onSelected(int index) {
    final shell = widget.navigationShell;
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
    _refreshBadge();
  }

  @override
  Widget build(BuildContext context) {
    final visible = !widget.hiddenOn.contains(_topRoute);
    final duration = MediaQuery.of(context).disableAnimations ? Duration.zero : AppMotion.fast;
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: ClipRect(
        child: AnimatedAlign(
          duration: duration,
          curve: AppMotion.standard,
          alignment: AlignmentDirectional.topCenter,
          heightFactor: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible,
              child: BlocBuilder<ChatBadgeCubit, ChatUnreadCounts>(
                builder: (context, unread) => AppBottomNav(
                  key: MainShell.navKey,
                  currentIndex: widget.navigationShell.currentIndex,
                  onSelected: _onSelected,
                  items: [
                    AppNavItem(
                      key: MainShell.tabKeys[0],
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: AppStrings.navHome,
                    ),
                    AppNavItem(key: MainShell.tabKeys[1], icon: Icons.search_rounded, label: AppStrings.navSearch),
                    AppNavItem(
                      key: MainShell.tabKeys[2],
                      icon: Icons.event_available_outlined,
                      selectedIcon: Icons.event_available_rounded,
                      label: AppStrings.navMatches,
                    ),
                    AppNavItem(
                      key: MainShell.tabKeys[3],
                      icon: Icons.chat_bubble_outline_rounded,
                      selectedIcon: Icons.chat_bubble_rounded,
                      label: AppStrings.navChat,
                      badgeCount: unread.total,
                    ),
                    AppNavItem(
                      key: MainShell.tabKeys[4],
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: AppStrings.navProfile,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
