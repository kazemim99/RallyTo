import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session_cubit.dart';
import '../../core/auth/auth_state.dart';
import '../../core/constants/app_strings.dart';
import '../../core/di/injection.dart';
import '../../core/widgets/widgets.dart';
import '../../features/auth/domain/otp_challenge.dart';
import '../../features/auth/presentation/bloc/code_bloc.dart';
import '../../features/auth/presentation/bloc/phone_bloc.dart';
import '../../features/auth/presentation/pages/code_page.dart';
import '../../features/auth/presentation/pages/phone_page.dart';
import '../../features/availability/domain/entities/availability_window.dart';
import '../../features/availability/presentation/bloc/availability_form_cubit.dart';
import '../../features/availability/presentation/bloc/availability_list_cubit.dart';
import '../../features/availability/presentation/pages/availability_form_page.dart';
import '../../features/availability/presentation/pages/availability_list_page.dart';
import '../../features/catalog/presentation/bloc/venue_detail_cubit.dart';
import '../../features/chat/presentation/bloc/chat_badge_cubit.dart';
import '../../features/chat/presentation/bloc/chat_inbox_cubit.dart';
import '../../features/chat/presentation/bloc/conversation_cubit.dart';
import '../../features/chat/presentation/pages/chat_inbox_page.dart';
import '../../features/chat/presentation/pages/conversation_page.dart';
import '../../features/catalog/presentation/pages/venue_detail_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/matches/presentation/bloc/match_detail_cubit.dart';
import '../../features/matches/presentation/bloc/match_form_cubit.dart';
import '../../features/matches/presentation/bloc/my_matches_cubit.dart';
import '../../features/matches/presentation/pages/match_detail_page.dart';
import '../../features/matches/presentation/pages/match_form_page.dart';
import '../../features/matches/presentation/pages/my_matches_page.dart';
import '../../features/notifications/presentation/bloc/notification_badge_cubit.dart';
import '../../features/notifications/presentation/bloc/notification_inbox_cubit.dart';
import '../../features/notifications/presentation/bloc/notification_preferences_cubit.dart';
import '../../features/notifications/presentation/pages/notification_inbox_page.dart';
import '../../features/notifications/presentation/pages/notification_preferences_page.dart';
import '../../features/onboarding/presentation/bloc/onboarding_cubit.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/profile/presentation/bloc/blocked_players_cubit.dart';
import '../../features/profile/presentation/bloc/my_profile_cubit.dart';
import '../../features/profile/presentation/bloc/player_profile_cubit.dart';
import '../../features/profile/presentation/pages/blocked_players_page.dart';
import '../../features/profile/presentation/pages/my_profile_page.dart';
import '../../features/profile/presentation/pages/player_profile_page.dart';
import '../../features/ratings/domain/entities/rating.dart';
import '../../features/ratings/presentation/bloc/rating_form_cubit.dart';
import '../../features/ratings/presentation/pages/rating_form_page.dart';
import '../../features/reports/domain/entities/report.dart';
import '../../features/reports/presentation/bloc/my_reports_cubit.dart';
import '../../features/reports/presentation/bloc/report_form_cubit.dart';
import '../../features/reports/presentation/pages/my_reports_page.dart';
import '../../features/reports/presentation/pages/report_form_page.dart';
import '../../features/search/domain/entities/search.dart';
import '../../features/search/presentation/bloc/partner_search_cubit.dart';
import '../../features/search/presentation/bloc/saved_searches_cubit.dart';
import '../../features/search/presentation/pages/partner_search_page.dart';
import '../../features/search/presentation/pages/saved_searches_page.dart';
import 'main_shell.dart';

/// Route paths. Every destination is addressable (deep-linkable).
class Routes {
  Routes._();

  /// Everything under it is reachable without a session: phone entry and code entry.
  static const String auth = '/auth';
  static const String phone = '/auth/phone';

  /// Code entry. Its `extra` is the `OtpChallenge` phone entry got back; without one (a deep link, a restored
  /// route) there is no code to enter, and it goes to phone entry.
  static const String code = '/auth/code';
  static const String onboarding = '/onboarding';
  static const String home = '/home';

  /// A venue's page; `:id` is the venue's id.
  static const String venue = '/venues/:id';

  /// The location of venue [id]'s page.
  static String venuePath(String id) => '/venues/${Uri.encodeComponent(id)}';

  /// The player's own profile, and the players they blocked.
  static const String profile = '/profile';
  static const String blockedPlayers = '/profile/blocked';

  /// The reports this player filed, each open or resolved.
  static const String myReports = '/profile/reports';

  /// The report form. Its `extra` is the `ReportTarget`; without one (a deep link, a restored route) there is nothing
  /// to report, and it goes home. Closes with `true` when the player was blocked too.
  static const String report = '/report';

  /// Another player's page; `:id` is their user id.
  static const String player = '/players/:id';

  /// The location of player [id]'s page.
  static String playerPath(String id) => '/players/${Uri.encodeComponent(id)}';

  /// The player's availability windows, and the form for a new one.
  static const String availability = '/availability';
  static const String availabilityNew = '/availability/new';

  /// The form for an existing window. Its `extra` is the `AvailabilityWindow`; without one (a deep link, a restored
  /// route) there is nothing to edit, and it goes to the list.
  static const String availabilityEdit = '/availability/edit';

  /// Partner search. Its optional `extra` is the `SearchFilters` to start from (a saved search, a game to fill);
  /// without one it starts from the profile's defaults.
  static const String search = '/search';

  /// The player's saved searches. Running one goes back to the search with its filters.
  static const String savedSearches = '/search/saved';

  /// The player's games, upcoming and past, and the form for a new play post.
  static const String matches = '/matches';
  static const String matchNew = '/matches/new';

  /// One game; `:id` is its id.
  static const String match = '/matches/:id';

  /// The location of game [id].
  static String matchPath(String id) => '/matches/${Uri.encodeComponent(id)}';

  /// Rating player `:playerId` of game `:id`. Its optional `extra` is their display name. Closes with `true` once
  /// the rating is stored.
  static const String rateMatchPlayer = '/matches/:id/rate/:playerId';

  /// The location of the form rating player [playerId] of game [matchId].
  static String rateMatchPlayerPath(String matchId, String playerId) =>
      '/matches/${Uri.encodeComponent(matchId)}/rate/${Uri.encodeComponent(playerId)}';

  /// A direct invitation to player `:id`. Its optional `extra` is their display name.
  static const String invitePlayer = '/players/:id/invite';

  /// The location of the invitation form for player [id].
  static String invitePlayerPath(String id) => '/players/${Uri.encodeComponent(id)}/invite';

  /// The game behind a share link: the same path as the server's `{PublicBaseUrl}/m/{token}`, so an opened link
  /// lands here.
  static const String sharedMatch = '/m/:token';

  /// The location of the game behind share token [token].
  static String sharedMatchPath(String token) => '/m/${Uri.encodeComponent(token)}';

  /// The chat inbox: conversations and message requests.
  static const String chat = '/chat';

  /// One conversation; `:id` is its id. A chat push's deep link (`/chat/{conversationId}`) lands here.
  static const String conversation = '/chat/:id';

  /// The location of conversation [id].
  static String chatPath(String id) => '/chat/${Uri.encodeComponent(id)}';

  /// The direct conversation with player `:id`, opened (or started) on the way in. Its optional `extra` is their
  /// display name.
  static const String playerChat = '/players/:id/chat';

  /// The location of the direct conversation with player [id].
  static String playerChatPath(String id) => '/players/${Uri.encodeComponent(id)}/chat';

  /// The group conversation of game `:id`.
  static const String matchChat = '/matches/:id/chat';

  /// The location of game [id]'s group conversation.
  static String matchChatPath(String id) => '/matches/${Uri.encodeComponent(id)}/chat';

  /// The notification inbox, and the push and quiet-hours settings.
  static const String notifications = '/notifications';
  static const String notificationSettings = '/notifications/settings';
}

/// The app's [GoRouter], redirecting on the sign-in state of an [AuthSessionCubit].
class AppRouter {
  AppRouter(AuthSessionCubit session) : _refresh = _StreamListenable(session.stream) {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: Routes.home,
      refreshListenable: _refresh,
      redirect: (context, state) => redirectFor(state.uri.path, session.state),
      routes: [
        // Signed out and onboarding: full screen, outside the tab shell.
        GoRoute(
          path: Routes.phone,
          builder: (context, state) => BlocProvider(create: (_) => getIt<PhoneBloc>(), child: const PhonePage()),
        ),
        GoRoute(
          path: Routes.code,
          redirect: (context, state) => state.extra is OtpChallenge ? null : Routes.phone,
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<CodeBloc>(param1: state.extra as OtpChallenge)..add(const CodeStarted()),
            child: const CodePage(),
          ),
        ),
        GoRoute(
          path: Routes.onboarding,
          builder: (context, state) =>
              BlocProvider(create: (_) => getIt<OnboardingCubit>()..start(), child: const OnboardingPage()),
        ),
        // Signed in: five tab stacks under the bottom bar. A route belongs to the branch a `go` lands it in; a `push`
        // stacks it on the current tab. The badge cubits live here, so the bar and home share one source.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<ChatBadgeCubit>()..start()),
              BlocProvider(create: (_) => getIt<NotificationBadgeCubit>()..start()),
            ],
            child: MainShell(navigationShell: navigationShell, hiddenOn: fullScreenRoutes),
          ),
          branches: [
            StatefulShellBranch(
              initialLocation: Routes.home,
              routes: [
                GoRoute(path: Routes.home, builder: (context, state) => const HomePage()),
                GoRoute(
                  path: Routes.notifications,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<NotificationInboxCubit>()..load(),
                    child: const NotificationInboxPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.notificationSettings,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<NotificationPreferencesCubit>()..load(),
                    child: const NotificationPreferencesPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.availability,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<AvailabilityListCubit>()..load(),
                    child: const AvailabilityListPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.availabilityNew,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<AvailabilityFormCubit>(param1: null)..load(),
                    child: const AvailabilityFormPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.availabilityEdit,
                  redirect: (context, state) => state.extra is AvailabilityWindow ? null : Routes.availability,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<AvailabilityFormCubit>(param1: state.extra as AvailabilityWindow)..load(),
                    child: const AvailabilityFormPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.venue,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<VenueDetailCubit>(param1: state.pathParameters['id'] ?? '')..load(),
                    child: const VenueDetailPage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: Routes.search,
              routes: [
                GoRoute(
                  path: Routes.search,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<PartnerSearchCubit>(
                      param1: state.extra is SearchFilters ? state.extra as SearchFilters : null,
                    )..load(),
                    child: const PartnerSearchPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.savedSearches,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<SavedSearchesCubit>()..load(),
                    child: const SavedSearchesPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.player,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<PlayerProfileCubit>(param1: state.pathParameters['id'] ?? '')..load(),
                    child: const PlayerProfilePage(),
                  ),
                ),
                GoRoute(
                  path: Routes.invitePlayer,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<MatchFormCubit>(
                      param1: MatchFormArgs.invitation(
                        InviteeRef(
                          userId: state.pathParameters['id'] ?? '',
                          displayName: state.extra is String ? state.extra as String : '',
                        ),
                      ),
                    )..load(),
                    child: const MatchFormPage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: Routes.matches,
              routes: [
                GoRoute(
                  path: Routes.matches,
                  builder: (context, state) =>
                      BlocProvider(create: (_) => getIt<MyMatchesCubit>()..load(), child: const MyMatchesPage()),
                ),
                // Before `/matches/:id`, which would otherwise take «new» for an id.
                GoRoute(
                  path: Routes.matchNew,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<MatchFormCubit>(param1: const MatchFormArgs.post())..load(),
                    child: const MatchFormPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.match,
                  builder: (context, state) => BlocProvider(
                    create: (_) =>
                        getIt<MatchDetailCubit>(param1: MatchRef.id(state.pathParameters['id'] ?? ''))..load(),
                    child: const MatchDetailPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.rateMatchPlayer,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<RatingFormCubit>(
                      param1: RatingTarget(
                        matchId: state.pathParameters['id'] ?? '',
                        rateeId: state.pathParameters['playerId'] ?? '',
                        rateeName: state.extra is String ? state.extra as String : null,
                      ),
                    ),
                    child: const RatingFormPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.sharedMatch,
                  builder: (context, state) => BlocProvider(
                    create: (_) =>
                        getIt<MatchDetailCubit>(param1: MatchRef.token(state.pathParameters['token'] ?? ''))..load(),
                    child: const MatchDetailPage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: Routes.chat,
              routes: [
                GoRoute(
                  path: Routes.chat,
                  builder: (context, state) =>
                      BlocProvider(create: (_) => getIt<ChatInboxCubit>()..load(), child: const ChatInboxPage()),
                ),
                GoRoute(
                  path: Routes.conversation,
                  builder: (context, state) =>
                      _conversation(ConversationTarget.id(state.pathParameters['id'] ?? ''), key: state.pageKey),
                ),
                GoRoute(
                  path: Routes.playerChat,
                  builder: (context, state) => _conversation(
                    ConversationTarget.player(
                      state.pathParameters['id'] ?? '',
                      playerName: state.extra is String ? state.extra as String : null,
                    ),
                    key: state.pageKey,
                  ),
                ),
                GoRoute(
                  path: Routes.matchChat,
                  builder: (context, state) =>
                      _conversation(ConversationTarget.match(state.pathParameters['id'] ?? ''), key: state.pageKey),
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: Routes.profile,
              routes: [
                GoRoute(
                  path: Routes.profile,
                  builder: (context, state) =>
                      BlocProvider(create: (_) => getIt<MyProfileCubit>()..load(), child: const MyProfilePage()),
                ),
                GoRoute(
                  path: Routes.blockedPlayers,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<BlockedPlayersCubit>()..load(),
                    child: const BlockedPlayersPage(),
                  ),
                ),
                GoRoute(
                  path: Routes.myReports,
                  builder: (context, state) =>
                      BlocProvider(create: (_) => getIt<MyReportsCubit>()..load(), child: const MyReportsPage()),
                ),
                GoRoute(
                  path: Routes.report,
                  redirect: (context, state) => state.extra is ReportTarget ? null : Routes.home,
                  builder: (context, state) => BlocProvider(
                    create: (_) => getIt<ReportFormCubit>(param1: state.extra as ReportTarget),
                    child: const ReportFormPage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => const _NotFoundPage(),
    );
  }

  final _StreamListenable _refresh;
  late final GoRouter router;

  /// The root navigator: sign-in and onboarding, dialogs, and full-screen pickers pushed with
  /// `Navigator.of(context, rootNavigator: true)`.
  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  /// The full-screen flows, by route pattern: the bottom bar hides on them. Everything else under the shell (the five
  /// tab roots and the read-only pages reached from them) shows it.
  ///
  /// They are pushed inside the current tab's stack rather than on [rootNavigatorKey]: go_router cannot push a
  /// shell route (a player's page from a conversation, the profile from a form, a push deep link) over a route on the
  /// root navigator without building the shell twice (duplicate page keys), and the app does all three.
  static const Set<String> fullScreenRoutes = {
    Routes.matchNew,
    Routes.invitePlayer,
    Routes.availabilityNew,
    Routes.availabilityEdit,
    Routes.rateMatchPlayer,
    Routes.report,
    Routes.conversation,
    Routes.playerChat,
    Routes.matchChat,
    Routes.notificationSettings,
  };

  /// A conversation screen; keyed by its page, so two conversations on the stack keep their own cubits.
  static Widget _conversation(ConversationTarget target, {LocalKey? key}) => BlocProvider(
    key: key,
    create: (_) => getIt<ConversationCubit>(param1: target)..load(),
    child: const ConversationPage(),
  );

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }

  /// Where [location] must go for [authState], or null to stay. Pure, so it is unit-tested directly.
  ///
  /// * Signed out: only `/auth/…` is reachable; everything else goes to `/auth/phone`.
  /// * Signed in, profile not completed: only `/onboarding`.
  /// * Signed in and onboarded: `/auth/…`, `/onboarding` and `/` go to `/home`; any other location stays.
  static String? redirectFor(String location, AuthState authState) {
    final path = location.isEmpty ? '/' : location;
    final onAuth = path == Routes.auth || path.startsWith('${Routes.auth}/');
    final onOnboarding = path == Routes.onboarding || path.startsWith('${Routes.onboarding}/');

    switch (authState) {
      case Unauthenticated():
        if (path == Routes.auth) return Routes.phone;
        return onAuth ? null : Routes.phone;
      case Authenticated(profileCompleted: false):
        return path == Routes.onboarding ? null : Routes.onboarding;
      case Authenticated(profileCompleted: true):
        return onAuth || onOnboarding || path == '/' ? Routes.home : null;
    }
  }
}

/// Re-runs the router's redirect whenever [stream] emits.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: AppStrings.pageNotFound,
        ctaLabel: AppStrings.backToHome,
        onCta: () => context.go(Routes.home),
      ),
    );
  }
}
