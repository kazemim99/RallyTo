import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/availability/domain/entities/availability_window.dart';
import 'package:rallyto_app/features/availability/presentation/bloc/availability_list_cubit.dart';
import 'package:rallyto_app/features/availability/presentation/pages/availability_list_page.dart';
import 'package:rallyto_app/features/availability/presentation/widgets/availability_window_card.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_profile.dart';

/// The player's windows grouped by status, each with the actions its status allows.
void main() {
  late FakeAvailabilityRepository availability;

  setUp(() => availability = FakeAvailabilityRepository());

  Future<void> showList(WidgetTester tester) async {
    final cubit = AvailabilityListCubit(availability, FakeCatalogRepository());
    addTearDown(cubit.close);
    await cubit.load();
    await pumpInShell(tester, BlocProvider.value(value: cubit, child: const AvailabilityListPage()));
  }

  testWidgets('groups the windows by status, active first, each in Persian', (tester) async {
    availability.mine = [
      testWindow(id: 'w-paused', status: AvailabilityStatus.paused),
      testWindow(id: 'w-active'),
      testWindow(id: 'w-once', kind: AvailabilityKind.oneOff, status: AvailabilityStatus.expired),
    ];
    await showList(tester);

    final active = tester.getTopLeft(find.byKey(AvailabilityListPage.sectionKey(AvailabilityStatus.active))).dy;
    final paused = tester.getTopLeft(find.byKey(AvailabilityListPage.sectionKey(AvailabilityStatus.paused))).dy;
    expect(find.text('${AppStrings.statusActive} (۱)'), findsOneWidget);
    expect(find.text('${AppStrings.statusPaused} (۱)'), findsOneWidget);
    expect(active, lessThan(paused));
    final activeCard = tester.getTopLeft(find.byKey(AvailabilityListPage.windowKey('w-active'))).dy;
    final pausedCard = tester.getTopLeft(find.byKey(AvailabilityListPage.windowKey('w-paused'))).dy;
    expect(activeCard, lessThan(pausedCard));

    expect(find.text('شنبه، دوشنبه، ۱۸:۰۰ تا ۲۰:۰۰'), findsNWidgets(2), reason: 'Saturday first, Persian digits');
    expect(find.text('تنیس'), findsWidgets);

    await tester.scrollUntilVisible(find.byKey(AvailabilityListPage.windowKey('w-once')), 200);
    expect(find.text('${AppStrings.statusExpired} (۱)'), findsOneWidget);
    expect(find.text('۸ آبان ۱۴۰۵، ۱۸:۰۰ تا ۲۰:۰۰'), findsOneWidget, reason: 'a one-off shows its Jalali date');
  });

  testWidgets('an active recurring window can be paused; a paused one resumed', (tester) async {
    await showList(tester);

    expect(find.byKey(AvailabilityListPage.confirmKey('w-1')), findsNothing, reason: 'confirmed recently');
    expect(find.byKey(AvailabilityListPage.pauseKey('w-1')), findsOneWidget);
    expect(find.byKey(AvailabilityListPage.resumeKey('w-1')), findsNothing);
    expect(find.byKey(AvailabilityListPage.resumeKey('w-2')), findsOneWidget);
    expect(find.byKey(AvailabilityListPage.pauseKey('w-2')), findsNothing);

    await tester.ensureVisible(find.byKey(AvailabilityListPage.pauseKey('w-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvailabilityListPage.pauseKey('w-1')));
    await tester.pumpAndSettle();

    expect(availability.actions, [('pause', 'w-1')]);
    expect(find.text(AppStrings.availabilityPaused), findsOneWidget);
    expect(find.text('${AppStrings.statusPaused} (۲)'), findsOneWidget, reason: 'it moved to the paused group');
  });

  testWidgets('deleting asks first', (tester) async {
    await showList(tester);

    await tester.scrollUntilVisible(find.byKey(AvailabilityListPage.deleteKey('w-2')), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvailabilityListPage.deleteKey('w-2')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.availabilityDeleteQuestion), findsOneWidget);
    await tester.tap(find.text(AppStrings.remove));
    await tester.pumpAndSettle();

    expect(availability.actions, [('delete', 'w-2')]);
    expect(find.byKey(AvailabilityListPage.windowKey('w-2')), findsNothing);
  });

  testWidgets('a dashed button adds a window; each card shows its status as a chip', (tester) async {
    await showList(tester);

    expect(find.widgetWithText(DashedButton, AppStrings.availabilityAdd), findsOneWidget);
    final active = find.byKey(AvailabilityListPage.windowKey('w-1'));
    expect(
      find.descendant(of: active, matching: find.widgetWithText(AppChip, AppStrings.statusActive)),
      findsOneWidget,
    );
    expect(find.descendant(of: active, matching: find.text(AppStrings.kindRecurring)), findsOneWidget);
  });

  testWidgets('a window that needs reconfirming: the reminder with its pause day, a warning chip, «هنوز آزادم»', (
    tester,
  ) async {
    availability.mine = [
      testWindow(id: 'w-due', needsReconfirmation: true, pausesOn: '1405/08/30'),
      testWindow(id: 'w-fresh', pausesOn: '1405/09/20'),
    ];
    await showList(tester);

    expect(find.byKey(AvailabilityListPage.reconfirmNoticeKey), findsOneWidget);
    expect(find.text('بازهٔ زمانی شما ۳۰ آبان ۱۴۰۵ متوقف می‌شود.'), findsOneWidget);
    expect(find.byKey(AvailabilityWindowCard.reconfirmChipKey('w-due')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(AvailabilityWindowCard.reconfirmChipKey('w-due')),
        matching: find.text(AppStrings.availabilityPausesOn('۳۰ آبان ۱۴۰۵')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(AvailabilityListPage.confirmKey('w-due')), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byKey(AvailabilityListPage.confirmKey('w-due'))).variant,
      AppButtonVariant.primary,
      reason: 'prominent where it matters',
    );

    await tester.ensureVisible(find.byKey(AvailabilityListPage.confirmKey('w-due')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvailabilityListPage.confirmKey('w-due')));
    await tester.pumpAndSettle();

    expect(availability.actions, [('confirm', 'w-due')]);
    expect(find.byKey(AvailabilityListPage.reconfirmNoticeKey), findsNothing, reason: 'nothing needs it any more');
    expect(find.byKey(AvailabilityListPage.confirmKey('w-due')), findsNothing);
  });

  testWidgets('an active weekly window confirmed recently: its pause day, quietly; no reminder, no «هنوز آزادم»', (
    tester,
  ) async {
    availability.mine = [
      testWindow(id: 'w-fresh', pausesOn: '1405/09/20'),
      testWindow(id: 'w-paused', status: AvailabilityStatus.paused),
    ];
    await showList(tester);

    expect(find.byKey(AvailabilityListPage.reconfirmNoticeKey), findsNothing);
    expect(find.byKey(AvailabilityListPage.confirmKey('w-fresh')), findsNothing);
    expect(find.byKey(AvailabilityWindowCard.reconfirmChipKey('w-fresh')), findsNothing);
    final pauseDay = find.byKey(AvailabilityWindowCard.pauseDayKey('w-fresh'));
    expect(pauseDay, findsOneWidget);
    expect(tester.widget<Text>(pauseDay).data, AppStrings.availabilityPausesOn('۲۰ آذر ۱۴۰۵'));
  });

  testWidgets('without an active weekly window, no reminder', (tester) async {
    availability.mine = [testWindow(id: 'w-paused', status: AvailabilityStatus.paused)];
    await showList(tester);

    expect(find.byKey(AvailabilityListPage.reconfirmNoticeKey), findsNothing);
  });

  testWidgets('without windows, says so and offers to add one', (tester) async {
    availability.mine = [];
    await showList(tester);

    expect(find.text(AppStrings.availabilityEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.availabilityAdd), findsWidgets);
  });
}
