import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/core/widgets/widgets.dart';
import 'package:rallyto_app/features/catalog/domain/entities/place.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/city_picker_cubit.dart';
import 'package:rallyto_app/features/catalog/presentation/widgets/city_picker.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';

/// The city picker on screen: province then city, a search that accepts Arabic letters, and the choice returned.
void main() {
  late FakeCatalogRepository repository;

  setUp(() => repository = FakeCatalogRepository());

  Future<List<CitySelection>> showPicker(WidgetTester tester) async {
    final selections = <CitySelection>[];
    await pumpInShell(
      tester,
      Scaffold(
        body: BlocProvider(
          create: (_) => CityPickerCubit(repository)..load(),
          child: CityPicker(onSelected: selections.add),
        ),
      ),
    );
    return selections;
  }

  Finder row(String name) => find.widgetWithText(ListRow, name);
  final searchField = find.descendant(of: find.byKey(CityPicker.searchFieldKey), matching: find.byType(TextField));

  testWidgets('a search typed with Arabic kaf and yeh finds the Persian city, and it is returned', (tester) async {
    final selections = await showPicker(tester);
    expect(row('تهران'), findsOneWidget);
    expect(row('اصفهان'), findsOneWidget);

    await tester.tap(row('تهران'));
    await tester.pumpAndSettle();
    expect(row('شهریار'), findsOneWidget);
    expect(find.text(AppStrings.cityVenueCount('۱۲')), findsOneWidget, reason: 'club counts in Persian digits');

    await tester.enterText(searchField, 'كرج');
    await tester.pumpAndSettle();
    expect(row('کرج'), findsOneWidget);
    expect(row('شهریار'), findsNothing);
    expect(row('تهران'), findsNothing);

    await tester.enterText(searchField, 'شهريار');
    await tester.pumpAndSettle();
    expect(row('شهریار'), findsOneWidget);
    expect(row('کرج'), findsNothing);

    await tester.tap(row('شهریار'));
    expect(selections, [const CitySelection(cityId: 11, cityName: 'شهریار', provinceName: 'تهران')]);
  });

  testWidgets('the province search filters too, and nothing found says so', (tester) async {
    await showPicker(tester);

    await tester.enterText(find.byType(TextField), 'اصف');
    await tester.pumpAndSettle();
    expect(row('اصفهان'), findsOneWidget);
    expect(row('تهران'), findsNothing);

    await tester.enterText(find.byType(TextField), 'شیراز');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noResultsTitle), findsOneWidget);
  });

  testWidgets('as a full screen: back from the cities returns to the provinces, and a city closes it', (tester) async {
    CitySelection? result;
    await pumpInShell(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<CitySelection>(
                MaterialPageRoute(
                  builder: (_) =>
                      BlocProvider(create: (_) => CityPickerCubit(repository)..load(), child: const CityPickerPage()),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(row('اصفهان'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.changeProvince), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.cityPickerTitle), findsOneWidget, reason: 'still on the picker');
    expect(row('تهران'), findsOneWidget);

    await tester.tap(row('اصفهان'));
    await tester.pumpAndSettle();
    await tester.tap(row('اصفهان'));
    await tester.pumpAndSettle();

    expect(result, const CitySelection(cityId: 20, cityName: 'اصفهان', provinceName: 'اصفهان'));
    expect(find.text('open'), findsOneWidget);
  });
}
