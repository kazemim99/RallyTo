import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/availability/presentation/bloc/availability_form_cubit.dart';
import 'package:rallyto_app/features/availability/presentation/pages/availability_form_page.dart';
import 'package:rallyto_app/features/catalog/domain/entities/sport.dart';

import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';
import '../../../../helpers/router_shell.dart';

/// The window form: weekdays from Saturday, weekly or one-off, the pinned save button, and the server's refusal.
void main() {
  // 1 Aban 1405, 11:30 in Tehran.
  final now = DateTime.utc(2026, 10, 23, 8);
  late FakeAvailabilityRepository availability;

  setUp(() => availability = FakeAvailabilityRepository());

  /// Opens the form from a launcher screen that shows the window the form closed with.
  Future<AvailabilityFormCubit> open(WidgetTester tester) async {
    final cubit = AvailabilityFormCubit(
      availability,
      FakeProfileRepository(),
      FakeCatalogRepository(),
      null,
      clock: () => now,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await pumpRouter(tester, [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: _Launcher(open: () => context.push<AvailabilityWindow>('/form'))),
      ),
      GoRoute(
        path: '/form',
        builder: (context, state) => BlocProvider.value(value: cubit, child: const AvailabilityFormPage()),
      ),
    ]);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<void> chooseSingles(WidgetTester tester) async {
    final singles = find.byKey(AvailabilityFormPage.formatKey(PlayFormat.singles));
    await tester.scrollUntilVisible(singles, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(singles);
    await tester.pumpAndSettle();
  }

  testWidgets('the weekdays start on Saturday, at the start of the line', (tester) async {
    await open(tester);

    final saturday = tester.getCenter(find.byKey(AvailabilityFormPage.weekdayKey(Weekday.saturday)));
    final sunday = tester.getCenter(find.byKey(AvailabilityFormPage.weekdayKey(Weekday.sunday)));
    expect(saturday.dx, greaterThan(sunday.dx), reason: 'right to left');
  });

  testWidgets('one-off swaps the weekdays for a Jalali date', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(AvailabilityFormPage.kindKey(AvailabilityKind.oneOff)));
    await tester.pumpAndSettle();

    expect(find.byKey(AvailabilityFormPage.weekdayKey(Weekday.saturday)), findsNothing);
    expect(find.byKey(AvailabilityFormPage.dateKey), findsOneWidget);
  });

  testWidgets('save is pinned at the bottom; a valid window is saved and the form closes with it', (tester) async {
    final cubit = await open(tester);

    expect(find.byType(StickyActions), findsOneWidget);
    await tester.tap(find.byKey(AvailabilityFormPage.weekdayKey(Weekday.saturday)));
    cubit.venuesChanged([testVenues.first]);
    await tester.pumpAndSettle();
    await chooseSingles(tester);
    await tester.tap(find.byKey(AvailabilityFormPage.saveKey));
    await tester.pumpAndSettle();

    expect(availability.createdDrafts.single.weekdays, {Weekday.saturday});
    expect(find.text('closed with w-new'), findsOneWidget);
  });

  testWidgets('a missing weekday is refused on the device', (tester) async {
    final cubit = await open(tester);
    cubit.venuesChanged([testVenues.first]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvailabilityFormPage.saveKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.weekdaysRequired), findsOneWidget);
    expect(availability.createdDrafts, isEmpty);
  });

  testWidgets("the server's refusal shows as an error banner", (tester) async {
    availability.saveFailure = const ServerFailure('بازه‌ها هم‌پوشانی دارند', code: 'OVERLAPPING_WINDOW');
    final cubit = await open(tester);
    await tester.tap(find.byKey(AvailabilityFormPage.weekdayKey(Weekday.saturday)));
    cubit.venuesChanged([testVenues.first]);
    await tester.pumpAndSettle();
    await chooseSingles(tester);

    await tester.tap(find.byKey(AvailabilityFormPage.saveKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(AvailabilityFormPage.serverErrorKey),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.widgetWithText(NoticeBanner, 'بازه‌ها هم‌پوشانی دارند'), findsOneWidget);
  });
}

class _Launcher extends StatefulWidget {
  const _Launcher({required this.open});

  final Future<AvailabilityWindow?> Function() open;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  String _result = '';

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        onPressed: () async {
          final saved = await widget.open();
          if (mounted) setState(() => _result = 'closed with ${saved?.id}');
        },
        child: const Text('open'),
      ),
      Text(_result),
    ],
  );
}
