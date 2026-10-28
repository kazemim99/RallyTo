import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/api/client/auth_api.dart';
import 'package:rallyto_app/core/api/client/dio_names.dart';
import 'package:rallyto_app/core/api/interceptors/auth_interceptor.dart';
import 'package:rallyto_app/core/api/interceptors/error_interceptor.dart';
import 'package:rallyto_app/core/auth/auth_session_cubit.dart';
import 'package:rallyto_app/core/auth/current_user.dart';
import 'package:rallyto_app/core/auth/token_storage.dart';
import 'package:rallyto_app/core/di/injection.dart';
import 'package:rallyto_app/core/push/push_service.dart';
import 'package:rallyto_app/core/realtime/realtime_client.dart';
import 'package:rallyto_app/core/realtime/realtime_lifecycle.dart';
import 'package:rallyto_app/core/share/share_service.dart';
import 'package:rallyto_app/features/account/domain/account_repository.dart';
import 'package:rallyto_app/features/account/presentation/bloc/account_deletion_cubit.dart';
import 'package:rallyto_app/features/auth/domain/auth_repository.dart';
import 'package:rallyto_app/features/auth/domain/otp_challenge.dart';
import 'package:rallyto_app/features/auth/presentation/bloc/code_bloc.dart';
import 'package:rallyto_app/features/auth/presentation/bloc/phone_bloc.dart';
import 'package:rallyto_app/features/availability/domain/availability_repository.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/availability/presentation/bloc/availability_form_cubit.dart';
import 'package:rallyto_app/features/availability/presentation/bloc/availability_list_cubit.dart';
import 'package:rallyto_app/features/catalog/data/catalog_api.dart';
import 'package:rallyto_app/features/catalog/domain/catalog_repository.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/city_picker_cubit.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/venue_picker_cubit.dart';
import 'package:rallyto_app/features/chat/domain/chat_repository.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/chat_badge_cubit.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/chat_inbox_cubit.dart';
import 'package:rallyto_app/features/chat/presentation/bloc/conversation_cubit.dart';
import 'package:rallyto_app/features/matches/domain/match_repository.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_detail_cubit.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/match_form_cubit.dart';
import 'package:rallyto_app/features/matches/presentation/bloc/my_matches_cubit.dart';
import 'package:rallyto_app/features/notifications/domain/notification_repository.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_badge_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_inbox_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/bloc/notification_preferences_cubit.dart';
import 'package:rallyto_app/features/notifications/presentation/push_registration.dart';
import 'package:rallyto_app/features/onboarding/presentation/bloc/onboarding_cubit.dart';
import 'package:rallyto_app/features/profile/domain/profile_repository.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/blocked_players_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/my_profile_cubit.dart';
import 'package:rallyto_app/features/profile/presentation/bloc/player_profile_cubit.dart';
import 'package:rallyto_app/features/ratings/domain/entities/rating.dart';
import 'package:rallyto_app/features/ratings/domain/rating_repository.dart';
import 'package:rallyto_app/features/ratings/presentation/bloc/rating_form_cubit.dart';
import 'package:rallyto_app/features/reports/domain/entities/report.dart';
import 'package:rallyto_app/features/reports/domain/report_repository.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/my_reports_cubit.dart';
import 'package:rallyto_app/features/reports/presentation/bloc/report_form_cubit.dart';
import 'package:rallyto_app/features/search/domain/entities/search.dart';
import 'package:rallyto_app/features/search/domain/search_repository.dart';
import 'package:rallyto_app/features/search/presentation/bloc/partner_search_cubit.dart';
import 'package:rallyto_app/features/search/presentation/bloc/saved_searches_cubit.dart';

/// The generated registrations (injection.config.dart) wire the app as designed.
void main() {
  setUp(configureDependencies);
  tearDown(getIt.reset);

  test('the API client renews tokens; the auth client cannot', () {
    final api = getIt<Dio>(instanceName: DioNames.api);
    final auth = getIt<Dio>(instanceName: DioNames.auth);

    final apiOrder = api.interceptors.where((i) => i is AuthInterceptor || i is ErrorInterceptor).toList();
    expect(apiOrder.map((i) => i.runtimeType), [AuthInterceptor, ErrorInterceptor], reason: 'a 401 is retried first');
    expect(auth.interceptors.whereType<AuthInterceptor>(), isEmpty, reason: 'a 401 there must not refresh');
    expect(auth.interceptors.whereType<ErrorInterceptor>(), hasLength(1));
  });

  test('session state is one per app, over one token store', () {
    expect(getIt<AuthSessionCubit>(), same(getIt<AuthSessionCubit>()));
    expect(getIt<TokenStorage>(), same(getIt<TokenStorage>()));
    expect(getIt<AuthApi>(), isA<AuthApi>());
  });

  test('the sign-in screens get a fresh bloc each time, over one repository', () async {
    const challenge = OtpChallenge(phoneNumber: '09121234567', expiresInSeconds: 300, resendAfterSeconds: 60);
    final phone = getIt<PhoneBloc>();
    final code = getIt<CodeBloc>(param1: challenge);
    addTearDown(phone.close);
    addTearDown(code.close);

    final another = getIt<PhoneBloc>();
    addTearDown(another.close);
    expect(another, isNot(same(phone)));
    expect(code.state.phoneNumber, challenge.phoneNumber);
    expect(code.state.resendSecondsLeft, 60);
    expect(getIt<AuthRepository>(), same(getIt<AuthRepository>()));
  });

  test('the catalog: one repository (its session cache), and a fresh picker each time it opens', () async {
    expect(getIt<CatalogRepository>(), same(getIt<CatalogRepository>()));
    expect(getIt<CatalogApi>(), isA<CatalogApi>());

    final city = getIt<CityPickerCubit>();
    final another = getIt<CityPickerCubit>();
    final venues = getIt<VenuePickerCubit>(param1: VenuePickerArgs(cityId: 10, maxSelection: 3));
    addTearDown(city.close);
    addTearDown(another.close);
    addTearDown(venues.close);

    expect(another, isNot(same(city)));
    expect(venues.state.maxSelection, 3);
  });

  test('profile and availability: one repository each, and a fresh cubit for every screen', () async {
    expect(getIt<ProfileRepository>(), same(getIt<ProfileRepository>()));
    expect(getIt<AvailabilityRepository>(), same(getIt<AvailabilityRepository>()));

    final onboarding = getIt<OnboardingCubit>();
    final profile = getIt<MyProfileCubit>();
    final blocks = getIt<BlockedPlayersCubit>();
    final player = getIt<PlayerProfileCubit>(param1: 'u-2');
    final list = getIt<AvailabilityListCubit>();
    final newWindow = getIt<AvailabilityFormCubit>(param1: null);
    const window = AvailabilityWindow(
      id: 'w-1',
      sportId: 's-tennis',
      sportCode: 'tennis',
      kind: AvailabilityKind.recurring,
      startTime: '18:00',
      endTime: '20:00',
      status: AvailabilityStatus.active,
    );
    final editWindow = getIt<AvailabilityFormCubit>(param1: window);
    for (final cubit in [onboarding, profile, blocks, player, list, newWindow, editWindow]) {
      addTearDown(cubit.close);
    }

    final another = getIt<OnboardingCubit>();
    addTearDown(another.close);
    expect(another, isNot(same(onboarding)));
    expect(newWindow.isEditing, isFalse);
    expect(editWindow.isEditing, isTrue);
    expect(editWindow.state.startMinute, 18 * 60);
  });

  test('search and matches: one repository each, and a fresh cubit for every screen', () async {
    expect(getIt<SearchRepository>(), same(getIt<SearchRepository>()));
    expect(getIt<MatchRepository>(), same(getIt<MatchRepository>()));

    final search = getIt<PartnerSearchCubit>(param1: null);
    final fromSaved = getIt<PartnerSearchCubit>(param1: const SearchFilters(sportId: 's-tennis'));
    final saved = getIt<SavedSearchesCubit>();
    final mine = getIt<MyMatchesCubit>();
    final post = getIt<MatchFormCubit>(param1: const MatchFormArgs.post());
    final invitation = getIt<MatchFormCubit>(param1: const MatchFormArgs.invitation(InviteeRef(userId: 'u-2')));
    final byId = getIt<MatchDetailCubit>(param1: const MatchRef.id('m-1'));
    final byToken = getIt<MatchDetailCubit>(param1: const MatchRef.token('abc123def456'));
    for (final cubit in [search, fromSaved, saved, mine, post, invitation, byId, byToken]) {
      addTearDown(cubit.close);
    }

    expect(fromSaved, isNot(same(search)));
    expect(post.isInvitation, isFalse);
    expect(invitation.isInvitation, isTrue);
  });

  test('chat and notifications: one realtime client and push channel for the app, a fresh cubit per screen', () async {
    expect(getIt<RealtimeClient>(), same(getIt<RealtimeClient>()));
    expect(getIt<RealtimeLifecycle>(), same(getIt<RealtimeLifecycle>()));
    expect(getIt<PushService>(), same(getIt<PushService>()));
    expect(getIt<PushRegistration>(), same(getIt<PushRegistration>()));
    expect(getIt<ChatRepository>(), same(getIt<ChatRepository>()));
    expect(getIt<NotificationRepository>(), same(getIt<NotificationRepository>()));
    expect(getIt<DeviceTokenRepository>(), isA<DeviceTokenRepository>());
    expect(getIt<CurrentUser>(), same(getIt<CurrentUser>()));

    final inbox = getIt<ChatInboxCubit>();
    final conversation = getIt<ConversationCubit>(param1: const ConversationTarget.id('c-1'));
    final withPlayer = getIt<ConversationCubit>(param1: const ConversationTarget.player('u-2'));
    final chatBadge = getIt<ChatBadgeCubit>();
    final notifications = getIt<NotificationInboxCubit>();
    final badge = getIt<NotificationBadgeCubit>();
    final preferences = getIt<NotificationPreferencesCubit>();
    for (final cubit in [inbox, conversation, withPlayer, chatBadge, notifications, badge, preferences]) {
      addTearDown(cubit.close);
    }

    expect(withPlayer, isNot(same(conversation)));
  });

  test('ratings, reports and sharing: one repository each and one share sheet, a fresh form per screen', () async {
    expect(getIt<RatingRepository>(), same(getIt<RatingRepository>()));
    expect(getIt<ReportRepository>(), same(getIt<ReportRepository>()));
    expect(getIt<ShareService>(), isA<SharePlusShareService>());

    final rating = getIt<RatingFormCubit>(
      param1: const RatingTarget(matchId: 'm-1', rateeId: 'u-2'),
    );
    final report = getIt<ReportFormCubit>(param1: const ReportTarget.player('u-2'));
    final another = getIt<ReportFormCubit>(param1: const ReportTarget.message('msg-1'));
    final mine = getIt<MyReportsCubit>();
    for (final cubit in [rating, report, another, mine]) {
      addTearDown(cubit.close);
    }

    expect(rating.state.target.rateeId, 'u-2');
    expect(another, isNot(same(report)));
    expect(another.state.target.type, ReportTargetType.message);
  });

  test('account deletion: one repository, and a fresh cubit each time the flow opens', () async {
    expect(getIt<AccountRepository>(), same(getIt<AccountRepository>()));

    final first = getIt<AccountDeletionCubit>();
    final second = getIt<AccountDeletionCubit>();
    addTearDown(first.close);
    addTearDown(second.close);

    expect(second, isNot(same(first)));
    expect(first.state.started, isFalse, reason: 'the page starts it');
  });
}
