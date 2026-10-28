import 'dart:ui' show CheckedState;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/catalog/domain/entities/venue.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/venue_picker_cubit.dart';
import 'package:rallyto_app/features/catalog/presentation/widgets/venue_picker.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';

/// The venue picker on screen: sport tags on each venue, the selection as chips, and the limit enforced.
void main() {
  late FakeCatalogRepository repository;

  setUp(() => repository = FakeCatalogRepository());

  Future<List<List<Venue>>> showPicker(WidgetTester tester, {int max = 2}) async {
    final confirmed = <List<Venue>>[];
    await pumpInShell(
      tester,
      Scaffold(
        body: BlocProvider(
          create: (_) => VenuePickerCubit(repository, VenuePickerArgs(cityId: 10, maxSelection: max))..start(),
          child: VenuePicker(onConfirm: confirmed.add),
        ),
      ),
    );
    return confirmed;
  }

  Finder result(String id) => find.byKey(VenuePicker.resultKey(id));

  /// Each result is read out as a checkbox: whether it is checked.
  bool checked(WidgetTester tester, String id) {
    final data = tester.getSemantics(result(id)).getSemanticsData();
    expect(data.flagsCollection.isChecked, isNot(CheckedState.none), reason: '$id is read out as a checkbox');
    return data.flagsCollection.isChecked == CheckedState.isTrue;
  }

  testWidgets('each venue shows its sports as tags, with court counts in Persian digits', (tester) async {
    await showPicker(tester);

    expect(find.descendant(of: result('v-1'), matching: find.text('تنیس ۶ زمین')), findsOneWidget);
    expect(find.descendant(of: result('v-2'), matching: find.text('تنیس ۴ زمین')), findsOneWidget);
    expect(find.descendant(of: result('v-2'), matching: find.text('پدل ۲ زمین')), findsOneWidget);
  });

  testWidgets('no more than the maximum can be selected, and the player is told why', (tester) async {
    final confirmed = await showPicker(tester, max: 2);

    await tester.tap(result('v-1'));
    await tester.pump();
    await tester.tap(result('v-2'));
    await tester.pump();
    await tester.tap(result('v-3'));
    await tester.pumpAndSettle();

    expect(checked(tester, 'v-1'), isTrue);
    expect(checked(tester, 'v-2'), isTrue);
    expect(checked(tester, 'v-3'), isFalse);
    expect(find.byKey(VenuePicker.chipKey('v-1')), findsOneWidget);
    expect(find.byKey(VenuePicker.chipKey('v-2')), findsOneWidget);
    expect(find.byKey(VenuePicker.chipKey('v-3')), findsNothing);
    expect(find.text(AppStrings.venueSelectionLimit('۲')), findsOneWidget);
    expect(find.text(AppStrings.venueConfirm('۲', '۲')), findsOneWidget);

    // The message goes by itself, uncovering the confirm button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(VenuePicker.confirmKey));
    expect(confirmed.single.map((v) => v.id), ['v-1', 'v-2']);
  });

  testWidgets('removing a chip frees a place', (tester) async {
    await showPicker(tester, max: 1);

    await tester.tap(result('v-1'));
    await tester.pump();
    await tester.tap(find.descendant(of: find.byKey(VenuePicker.chipKey('v-1')), matching: find.byType(Icon)).last);
    await tester.pump();
    await tester.tap(result('v-3'));
    await tester.pump();

    expect(checked(tester, 'v-1'), isFalse);
    expect(checked(tester, 'v-3'), isTrue);
    expect(find.text(AppStrings.venueSelectionLimit('۱')), findsNothing);
  });

  testWidgets('typing searches the server once the player pauses', (tester) async {
    await showPicker(tester);
    repository.searches.clear();

    await tester.enterText(find.byType(TextField), 'آزادی');
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.searches, isEmpty);

    await tester.pump(VenuePickerCubit.defaultDebounce);
    await tester.pumpAndSettle();
    expect(repository.searches.single.query, 'آزادی');
    expect(result('v-2'), findsOneWidget);
    expect(result('v-1'), findsNothing);
  });

  testWidgets('a search with no venues says so', (tester) async {
    repository.venues = (_) => const Right([]);
    await showPicker(tester);

    expect(find.text(AppStrings.venuesEmptyTitle), findsOneWidget);
  });
}
