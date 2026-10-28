// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:dio/dio.dart' as _i361;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/account/data/account_api.dart' as _i107;
import '../../features/account/data/account_repository_impl.dart' as _i1023;
import '../../features/account/domain/account_repository.dart' as _i266;
import '../../features/account/presentation/bloc/account_deletion_cubit.dart'
    as _i272;
import '../../features/auth/data/auth_repository_impl.dart' as _i781;
import '../../features/auth/domain/auth_repository.dart' as _i996;
import '../../features/auth/domain/otp_challenge.dart' as _i151;
import '../../features/auth/presentation/bloc/code_bloc.dart' as _i20;
import '../../features/auth/presentation/bloc/phone_bloc.dart' as _i157;
import '../../features/availability/data/availability_api.dart' as _i707;
import '../../features/availability/data/availability_repository_impl.dart'
    as _i855;
import '../../features/availability/domain/availability_repository.dart'
    as _i411;
import '../../features/availability/domain/entities/availability_window.dart'
    as _i782;
import '../../features/availability/presentation/bloc/availability_form_cubit.dart'
    as _i55;
import '../../features/availability/presentation/bloc/availability_list_cubit.dart'
    as _i624;
import '../../features/catalog/data/catalog_api.dart' as _i525;
import '../../features/catalog/data/catalog_repository_impl.dart' as _i471;
import '../../features/catalog/domain/catalog_repository.dart' as _i586;
import '../../features/catalog/presentation/bloc/city_picker_cubit.dart'
    as _i947;
import '../../features/catalog/presentation/bloc/venue_detail_cubit.dart'
    as _i356;
import '../../features/catalog/presentation/bloc/venue_picker_cubit.dart'
    as _i719;
import '../../features/chat/data/chat_api.dart' as _i202;
import '../../features/chat/data/chat_repository_impl.dart' as _i327;
import '../../features/chat/domain/chat_repository.dart' as _i963;
import '../../features/chat/presentation/bloc/chat_badge_cubit.dart' as _i944;
import '../../features/chat/presentation/bloc/chat_inbox_cubit.dart' as _i616;
import '../../features/chat/presentation/bloc/conversation_cubit.dart' as _i783;
import '../../features/matches/data/match_api.dart' as _i290;
import '../../features/matches/data/match_repository_impl.dart' as _i479;
import '../../features/matches/domain/match_repository.dart' as _i1025;
import '../../features/matches/presentation/bloc/match_detail_cubit.dart'
    as _i747;
import '../../features/matches/presentation/bloc/match_form_cubit.dart'
    as _i214;
import '../../features/matches/presentation/bloc/my_matches_cubit.dart' as _i13;
import '../../features/notifications/data/firebase_push_service.dart' as _i402;
import '../../features/notifications/data/notification_api.dart' as _i950;
import '../../features/notifications/data/notification_repository_impl.dart'
    as _i354;
import '../../features/notifications/domain/notification_repository.dart'
    as _i224;
import '../../features/notifications/presentation/bloc/notification_badge_cubit.dart'
    as _i559;
import '../../features/notifications/presentation/bloc/notification_inbox_cubit.dart'
    as _i358;
import '../../features/notifications/presentation/bloc/notification_preferences_cubit.dart'
    as _i777;
import '../../features/notifications/presentation/push_registration.dart'
    as _i997;
import '../../features/onboarding/presentation/bloc/onboarding_cubit.dart'
    as _i153;
import '../../features/profile/data/profile_api.dart' as _i453;
import '../../features/profile/data/profile_repository_impl.dart' as _i206;
import '../../features/profile/domain/profile_repository.dart' as _i789;
import '../../features/profile/presentation/bloc/blocked_players_cubit.dart'
    as _i351;
import '../../features/profile/presentation/bloc/my_profile_cubit.dart'
    as _i102;
import '../../features/profile/presentation/bloc/player_profile_cubit.dart'
    as _i654;
import '../../features/ratings/data/rating_api.dart' as _i587;
import '../../features/ratings/data/rating_repository_impl.dart' as _i699;
import '../../features/ratings/domain/entities/rating.dart' as _i420;
import '../../features/ratings/domain/rating_repository.dart' as _i41;
import '../../features/ratings/presentation/bloc/rating_form_cubit.dart'
    as _i352;
import '../../features/reports/data/report_api.dart' as _i30;
import '../../features/reports/data/report_repository_impl.dart' as _i1015;
import '../../features/reports/domain/entities/report.dart' as _i978;
import '../../features/reports/domain/report_repository.dart' as _i898;
import '../../features/reports/presentation/bloc/my_reports_cubit.dart'
    as _i147;
import '../../features/reports/presentation/bloc/report_form_cubit.dart'
    as _i751;
import '../../features/search/data/search_api.dart' as _i169;
import '../../features/search/data/search_repository_impl.dart' as _i686;
import '../../features/search/domain/entities/search.dart' as _i652;
import '../../features/search/domain/search_repository.dart' as _i419;
import '../../features/search/presentation/bloc/partner_search_cubit.dart'
    as _i700;
import '../../features/search/presentation/bloc/saved_searches_cubit.dart'
    as _i626;
import '../api/client/auth_api.dart' as _i945;
import '../api/client/dio_client.dart' as _i981;
import '../api/interceptors/auth_interceptor.dart' as _i861;
import '../api/interceptors/error_interceptor.dart' as _i581;
import '../auth/auth_session_cubit.dart' as _i903;
import '../auth/current_user.dart' as _i552;
import '../auth/token_storage.dart' as _i1002;
import '../push/push_service.dart' as _i1040;
import '../realtime/realtime_client.dart' as _i838;
import '../realtime/realtime_lifecycle.dart' as _i946;
import '../realtime/signalr_realtime_client.dart' as _i536;
import '../share/share_service.dart' as _i171;
import '../storage/secure_storage_service.dart' as _i666;
import '../utils/countdown.dart' as _i791;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final networkModule = _$NetworkModule();
    final accountModule = _$AccountModule();
    final availabilityModule = _$AvailabilityModule();
    final catalogModule = _$CatalogModule();
    final chatModule = _$ChatModule();
    final matchModule = _$MatchModule();
    final notificationModule = _$NotificationModule();
    final profileModule = _$ProfileModule();
    final ratingModule = _$RatingModule();
    final reportModule = _$ReportModule();
    final searchModule = _$SearchModule();
    gh.factory<_i581.ErrorInterceptor>(() => _i581.ErrorInterceptor());
    gh.factory<_i791.Countdown>(() => const _i791.Countdown());
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => networkModule.secureStorage,
    );
    gh.lazySingleton<_i666.SecureStorageService>(
      () => _i666.SecureStorageService(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i171.ShareService>(() => _i171.SharePlusShareService());
    gh.lazySingleton<_i361.Dio>(
      () => networkModule.authDio(gh<_i581.ErrorInterceptor>()),
      instanceName: 'authDio',
    );
    gh.lazySingleton<_i1040.PushService>(() => _i402.FirebasePushService());
    gh.lazySingleton<_i945.AuthApi>(
      () => networkModule.authApi(gh<_i361.Dio>(instanceName: 'authDio')),
    );
    gh.lazySingleton<_i1002.TokenStorage>(
      () => _i1002.TokenStorage(gh<_i666.SecureStorageService>()),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i903.AuthSessionCubit>(
      () => _i903.AuthSessionCubit.withApi(
        gh<_i1002.TokenStorage>(),
        gh<_i945.AuthApi>(),
      ),
    );
    gh.lazySingleton<_i996.AuthRepository>(
      () => _i781.AuthRepositoryImpl(gh<_i945.AuthApi>()),
    );
    gh.factory<_i861.AuthInterceptor>(
      () => _i861.AuthInterceptor(
        gh<_i1002.TokenStorage>(),
        gh<_i361.Dio>(instanceName: 'authDio'),
      ),
    );
    gh.lazySingleton<_i838.RealtimeClient>(
      () => _i536.SignalRRealtimeClient(gh<_i1002.TokenStorage>()),
    );
    gh.lazySingleton<_i552.CurrentUser>(
      () => _i552.CurrentUser(gh<_i1002.TokenStorage>()),
    );
    gh.lazySingleton<_i946.RealtimeLifecycle>(
      () => _i946.RealtimeLifecycle(
        gh<_i903.AuthSessionCubit>(),
        gh<_i838.RealtimeClient>(),
      ),
    );
    gh.factoryParam<_i20.CodeBloc, _i151.OtpChallenge, dynamic>(
      (challenge, _) => _i20.CodeBloc(
        gh<_i996.AuthRepository>(),
        gh<_i903.AuthSessionCubit>(),
        gh<_i791.Countdown>(),
        challenge,
      ),
    );
    gh.lazySingleton<_i361.Dio>(
      () => networkModule.apiDio(
        gh<_i861.AuthInterceptor>(),
        gh<_i581.ErrorInterceptor>(),
      ),
      instanceName: 'apiDio',
    );
    gh.factory<_i157.PhoneBloc>(
      () => _i157.PhoneBloc(gh<_i996.AuthRepository>(), gh<_i791.Countdown>()),
    );
    gh.lazySingleton<_i107.AccountApi>(
      () => accountModule.accountApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i707.AvailabilityApi>(
      () => availabilityModule.availabilityApi(
        gh<_i361.Dio>(instanceName: 'apiDio'),
      ),
    );
    gh.lazySingleton<_i525.CatalogApi>(
      () => catalogModule.catalogApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i202.ChatApi>(
      () => chatModule.chatApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i290.MatchApi>(
      () => matchModule.matchApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i950.NotificationApi>(
      () => notificationModule.notificationApi(
        gh<_i361.Dio>(instanceName: 'apiDio'),
      ),
    );
    gh.lazySingleton<_i453.ProfileApi>(
      () => profileModule.profileApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i587.RatingApi>(
      () => ratingModule.ratingApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i30.ReportApi>(
      () => reportModule.reportApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i169.SearchApi>(
      () => searchModule.searchApi(gh<_i361.Dio>(instanceName: 'apiDio')),
    );
    gh.lazySingleton<_i586.CatalogRepository>(
      () => _i471.CatalogRepositoryImpl(
        gh<_i525.CatalogApi>(),
        gh<_i666.SecureStorageService>(),
      ),
    );
    gh.factoryParam<_i356.VenueDetailCubit, String, dynamic>(
      (venueId, _) =>
          _i356.VenueDetailCubit(gh<_i586.CatalogRepository>(), venueId),
    );
    gh.lazySingleton<_i1025.MatchRepository>(
      () => _i479.MatchRepositoryImpl(gh<_i290.MatchApi>()),
    );
    gh.lazySingleton<_i224.DeviceTokenRepository>(
      () => _i354.DeviceTokenRepositoryImpl(gh<_i950.NotificationApi>()),
    );
    gh.lazySingleton<_i419.SearchRepository>(
      () => _i686.SearchRepositoryImpl(gh<_i169.SearchApi>()),
    );
    gh.factory<_i947.CityPickerCubit>(
      () => _i947.CityPickerCubit(gh<_i586.CatalogRepository>()),
    );
    gh.lazySingleton<_i963.ChatRepository>(
      () => _i327.ChatRepositoryImpl(
        gh<_i202.ChatApi>(),
        gh<_i838.RealtimeClient>(),
      ),
    );
    gh.lazySingleton<_i41.RatingRepository>(
      () => _i699.RatingRepositoryImpl(gh<_i587.RatingApi>()),
    );
    gh.factoryParam<_i719.VenuePickerCubit, _i719.VenuePickerArgs, dynamic>(
      (args, _) => _i719.VenuePickerCubit(gh<_i586.CatalogRepository>(), args),
    );
    gh.lazySingleton<_i411.AvailabilityRepository>(
      () => _i855.AvailabilityRepositoryImpl(gh<_i707.AvailabilityApi>()),
    );
    gh.lazySingleton<_i898.ReportRepository>(
      () => _i1015.ReportRepositoryImpl(gh<_i30.ReportApi>()),
    );
    gh.lazySingleton<_i224.NotificationRepository>(
      () => _i354.NotificationRepositoryImpl(
        gh<_i950.NotificationApi>(),
        gh<_i838.RealtimeClient>(),
      ),
    );
    gh.factoryParam<_i747.MatchDetailCubit, _i747.MatchRef, dynamic>(
      (ref, _) => _i747.MatchDetailCubit(
        gh<_i1025.MatchRepository>(),
        gh<_i586.CatalogRepository>(),
        gh<_i963.ChatRepository>(),
        gh<_i552.CurrentUser>(),
        gh<_i171.ShareService>(),
        ref,
      ),
    );
    gh.factory<_i624.AvailabilityListCubit>(
      () => _i624.AvailabilityListCubit(
        gh<_i411.AvailabilityRepository>(),
        gh<_i586.CatalogRepository>(),
      ),
    );
    gh.factory<_i147.MyReportsCubit>(
      () => _i147.MyReportsCubit(gh<_i898.ReportRepository>()),
    );
    gh.factory<_i777.NotificationPreferencesCubit>(
      () => _i777.NotificationPreferencesCubit(
        gh<_i224.NotificationRepository>(),
      ),
    );
    gh.lazySingleton<_i789.ProfileRepository>(
      () => _i206.ProfileRepositoryImpl(gh<_i453.ProfileApi>()),
    );
    gh.factory<_i944.ChatBadgeCubit>(
      () => _i944.ChatBadgeCubit(
        gh<_i963.ChatRepository>(),
        gh<_i838.RealtimeClient>(),
      ),
    );
    gh.factoryParam<
      _i55.AvailabilityFormCubit,
      _i782.AvailabilityWindow?,
      dynamic
    >(
      (existing, _) => _i55.AvailabilityFormCubit(
        gh<_i411.AvailabilityRepository>(),
        gh<_i789.ProfileRepository>(),
        gh<_i586.CatalogRepository>(),
        existing,
      ),
    );
    gh.lazySingleton<_i997.PushRegistration>(
      () => _i997.PushRegistration(
        gh<_i1040.PushService>(),
        gh<_i224.DeviceTokenRepository>(),
        gh<_i224.NotificationRepository>(),
        gh<_i903.AuthSessionCubit>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i266.AccountRepository>(
      () => _i1023.AccountRepositoryImpl(gh<_i107.AccountApi>()),
    );
    gh.factory<_i13.MyMatchesCubit>(
      () => _i13.MyMatchesCubit(
        gh<_i1025.MatchRepository>(),
        gh<_i586.CatalogRepository>(),
      ),
    );
    gh.factoryParam<_i654.PlayerProfileCubit, String, dynamic>(
      (userId, _) => _i654.PlayerProfileCubit(
        gh<_i789.ProfileRepository>(),
        gh<_i411.AvailabilityRepository>(),
        gh<_i586.CatalogRepository>(),
        userId,
      ),
    );
    gh.factoryParam<_i751.ReportFormCubit, _i978.ReportTarget, dynamic>(
      (target, _) =>
          _i751.ReportFormCubit(gh<_i898.ReportRepository>(), target),
    );
    gh.factory<_i626.SavedSearchesCubit>(
      () => _i626.SavedSearchesCubit(
        gh<_i419.SearchRepository>(),
        gh<_i586.CatalogRepository>(),
      ),
    );
    gh.factoryParam<_i352.RatingFormCubit, _i420.RatingTarget, dynamic>(
      (target, _) => _i352.RatingFormCubit(gh<_i41.RatingRepository>(), target),
    );
    gh.factory<_i272.AccountDeletionCubit>(
      () => _i272.AccountDeletionCubit(
        gh<_i266.AccountRepository>(),
        gh<_i903.AuthSessionCubit>(),
        gh<_i791.Countdown>(),
      ),
    );
    gh.factory<_i559.NotificationBadgeCubit>(
      () => _i559.NotificationBadgeCubit(
        gh<_i224.NotificationRepository>(),
        gh<_i838.RealtimeClient>(),
      ),
    );
    gh.factory<_i358.NotificationInboxCubit>(
      () => _i358.NotificationInboxCubit(
        gh<_i224.NotificationRepository>(),
        gh<_i838.RealtimeClient>(),
      ),
    );
    gh.factory<_i153.OnboardingCubit>(
      () => _i153.OnboardingCubit(
        gh<_i789.ProfileRepository>(),
        gh<_i586.CatalogRepository>(),
        gh<_i903.AuthSessionCubit>(),
      ),
    );
    gh.factoryParam<_i783.ConversationCubit, _i783.ConversationTarget, dynamic>(
      (target, _) => _i783.ConversationCubit(
        gh<_i963.ChatRepository>(),
        gh<_i789.ProfileRepository>(),
        gh<_i838.RealtimeClient>(),
        gh<_i552.CurrentUser>(),
        target,
      ),
    );
    gh.factoryParam<_i700.PartnerSearchCubit, _i652.SearchFilters?, dynamic>(
      (initial, _) => _i700.PartnerSearchCubit(
        gh<_i419.SearchRepository>(),
        gh<_i789.ProfileRepository>(),
        gh<_i586.CatalogRepository>(),
        initial,
      ),
    );
    gh.factory<_i102.MyProfileCubit>(
      () => _i102.MyProfileCubit(
        gh<_i789.ProfileRepository>(),
        gh<_i586.CatalogRepository>(),
      ),
    );
    gh.factory<_i351.BlockedPlayersCubit>(
      () => _i351.BlockedPlayersCubit(gh<_i789.ProfileRepository>()),
    );
    gh.factoryParam<_i214.MatchFormCubit, _i214.MatchFormArgs, dynamic>(
      (args, _) => _i214.MatchFormCubit(
        gh<_i1025.MatchRepository>(),
        gh<_i789.ProfileRepository>(),
        gh<_i586.CatalogRepository>(),
        args,
      ),
    );
    gh.factory<_i616.ChatInboxCubit>(
      () => _i616.ChatInboxCubit(
        gh<_i963.ChatRepository>(),
        gh<_i838.RealtimeClient>(),
        gh<_i789.ProfileRepository>(),
      ),
    );
    return this;
  }
}

class _$NetworkModule extends _i981.NetworkModule {}

class _$AccountModule extends _i107.AccountModule {}

class _$AvailabilityModule extends _i707.AvailabilityModule {}

class _$CatalogModule extends _i525.CatalogModule {}

class _$ChatModule extends _i202.ChatModule {}

class _$MatchModule extends _i290.MatchModule {}

class _$NotificationModule extends _i950.NotificationModule {}

class _$ProfileModule extends _i453.ProfileModule {}

class _$RatingModule extends _i587.RatingModule {}

class _$ReportModule extends _i30.ReportModule {}

class _$SearchModule extends _i169.SearchModule {}
