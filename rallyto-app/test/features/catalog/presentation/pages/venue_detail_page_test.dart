import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';
import 'package:rallyto_app/features/catalog/domain/entities/venue.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/venue_detail_cubit.dart';
import 'package:rallyto_app/features/catalog/presentation/pages/venue_detail_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';

/// A venue's page: its facts and courts, a map only when the club's coordinates are known.
void main() {
  late FakeCatalogRepository repository;

  setUp(() => repository = FakeCatalogRepository());

  Future<void> showVenue(WidgetTester tester, String id) => pumpInShell(
    tester,
    BlocProvider(create: (_) => VenueDetailCubit(repository, id)..load(), child: const VenueDetailPage()),
  );

  testWidgets('without coordinates: the address and courts, and no map', (tester) async {
    repository.venue = (id) => Right(
      testVenue(
        id: id,
        latitude: null,
        longitude: null,
        sports: const [
          VenueSport(
            sportCode: 'tennis',
            courtCount: 6,
            setting: CourtSetting.outdoor,
            surface: CourtSurface.clay,
            hasLighting: true,
          ),
          VenueSport(sportCode: 'padel', setting: CourtSetting.indoor),
        ],
      ),
    );
    await showVenue(tester, 'v-1');

    expect(find.text('باشگاه انقلاب'), findsWidgets);
    final cover = find.byKey(VenueDetailPage.coverKey);
    expect(find.descendant(of: cover, matching: find.text('باشگاه انقلاب')), findsOneWidget);
    expect(find.descendant(of: cover, matching: find.text('تهران')), findsOneWidget);
    expect(find.text('تهران'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(VenueDetailPage.addressKey), matching: find.text('تهران، خیابان انقلاب')),
      findsOneWidget,
    );
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(VenueDetailPage.mapKey), findsNothing);

    // The sports offered, as chips on the cover.
    for (final (code, name) in [('tennis', 'تنیس'), ('padel', 'پدل')]) {
      expect(find.descendant(of: find.byKey(VenueDetailPage.sportChipKey(code)), matching: find.text(name)), findsOne);
    }

    // Each sport's courts, with its own facts: count in Persian digits, setting, surface and night lighting.
    Finder inSport(String code, String text) =>
        find.descendant(of: find.byKey(VenueDetailPage.sportKey(code)), matching: find.text(text));
    expect(inSport('tennis', 'تنیس'), findsOneWidget);
    expect(inSport('tennis', '۶'), findsOneWidget);
    expect(inSport('tennis', 'روباز'), findsOneWidget);
    expect(inSport('tennis', 'خاک رس'), findsOneWidget);
    expect(inSport('tennis', AppStrings.courtLighting), findsOneWidget);

    // What the club has not said reads «نامشخص», and an unlit sport has no lighting chip.
    expect(inSport('padel', 'پدل'), findsOneWidget);
    expect(inSport('padel', 'سرپوشیده'), findsOneWidget);
    expect(inSport('padel', AppStrings.venueStatUnknown), findsNWidgets(2), reason: 'court count and surface');
    expect(inSport('padel', AppStrings.courtLighting), findsNothing);
  });

  testWidgets('the phone is shown left to right in its own row', (tester) async {
    repository.venue = (id) =>
        Right(Venue(id: id, name: 'باشگاه انقلاب', cityId: 10, cityName: 'تهران', phone: '021-66001122'));
    await showVenue(tester, 'v-1');

    final row = find.byKey(VenueDetailPage.phoneKey);
    expect(find.descendant(of: row, matching: find.text(AppStrings.venuePhone)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('021-66001122')), findsOneWidget);
  });

  testWidgets('without an address either, says it is not recorded', (tester) async {
    repository.venue = (id) => Right(testVenue(id: id, address: null, latitude: null, longitude: null));
    await showVenue(tester, 'v-1');

    expect(find.text(AppStrings.venueNoAddress), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('with coordinates: a map of the club', (tester) async {
    await showVenue(tester, 'v-1');

    expect(find.byKey(VenueDetailPage.mapKey), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(find.text('تهران، خیابان انقلاب'), findsOneWidget);
  });

  testWidgets('a hidden venue is not found, with no retry', (tester) async {
    repository.venue = (_) => const Left(NotFoundFailure('باشگاه پیدا نشد'));
    await showVenue(tester, 'v-9');

    expect(find.text(AppStrings.venueNotFound), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });

  testWidgets('another failure offers a retry', (tester) async {
    repository.venue = (_) => const Left(NetworkFailure(AppStrings.offlineActionError));
    await showVenue(tester, 'v-1');
    expect(find.text(AppStrings.offlineActionError), findsOneWidget);

    repository.venue = (id) => Right(testVenue(id: id, latitude: null, longitude: null));
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('تهران، خیابان انقلاب'), findsOneWidget);
  });
}
