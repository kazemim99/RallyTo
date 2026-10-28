import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/constants/app_strings.dart';
import 'package:rallyto_app/features/search/presentation/bloc/saved_searches_cubit.dart';
import 'package:rallyto_app/features/search/presentation/pages/saved_searches_page.dart';

import '../../../../helpers/app_shell.dart';
import '../../../../helpers/fake_catalog.dart';
import '../../../../helpers/fake_search.dart';

/// Saved searches: each with its filters in Persian, an alerts switch and delete behind a confirmation.
void main() {
  late FakeSearchRepository search;

  setUp(() => search = FakeSearchRepository());

  Future<void> show(WidgetTester tester) async {
    final cubit = SavedSearchesCubit(search, FakeCatalogRepository());
    addTearDown(cubit.close);
    await cubit.load();
    await pumpInShell(tester, BlocProvider.value(value: cubit, child: const SavedSearchesPage()));
  }

  testWidgets('each search with its filters, its city and clubs by name, and how many of 5 are used', (tester) async {
    await show(tester);

    expect(find.text('۲ از ۵ جستجو'), findsOneWidget);
    expect(find.text('شنبه‌شب‌ها'), findsNWidgets(2));
    expect(find.text('تنیس ‏•‏ شنبه، ۱۸:۰۰ تا ۲۲:۰۰، متوسط رو به پایین تا پیشرفته'), findsNWidgets(2));
    expect(find.text('تهران ‏•‏ باشگاه انقلاب'), findsNWidgets(2));
  });

  testWidgets('the alerts switch turns them off', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(SavedSearchesPage.alertsKey('ss-1')));
    await tester.pumpAndSettle();

    expect(search.updated.single.$3, isFalse);
    expect(find.text(AppStrings.alertsOff), findsOneWidget);
  });

  testWidgets('deleting asks first', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(SavedSearchesPage.deleteKey('ss-2')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.savedSearchDeleteQuestion('شنبه‌شب‌ها')), findsOneWidget);
    await tester.tap(find.text(AppStrings.remove));
    await tester.pumpAndSettle();

    expect(search.deleted, ['ss-2']);
    expect(find.byKey(SavedSearchesPage.searchKey('ss-2')), findsNothing);
    expect(find.text('۱ از ۵ جستجو'), findsOneWidget);
  });

  testWidgets('none saved: explains how to save one', (tester) async {
    search.saved = [];
    await show(tester);

    expect(find.text(AppStrings.savedSearchesEmptyTitle), findsOneWidget);
  });
}
