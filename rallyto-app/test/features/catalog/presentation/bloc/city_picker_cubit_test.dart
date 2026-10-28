import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/catalog_load_status.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/city_picker_cubit.dart';

import '../../../../helpers/fake_catalog.dart';

/// Province, then city; each list searchable in Persian however it was typed.
void main() {
  late FakeCatalogRepository repository;
  late CityPickerCubit cubit;

  setUp(() {
    repository = FakeCatalogRepository();
    cubit = CityPickerCubit(repository);
  });

  tearDown(() => cubit.close());

  test('opens on the province list', () async {
    await cubit.load();

    expect(cubit.state.step, CityPickerStep.provinces);
    expect(cubit.state.status, CatalogLoadStatus.ready);
    expect(cubit.state.visibleProvinces, testProvinces);
  });

  test("a province opens its cities in the server's order, those with clubs first", () async {
    await cubit.load();
    await cubit.selectProvince(testProvinces.first);

    expect(cubit.state.step, CityPickerStep.cities);
    expect(cubit.state.province, testProvinces.first);
    expect(cubit.state.visibleCities, tehranCities);
    expect(repository.citiesAskedFor, [1]);
  });

  group('search', () {
    setUp(() async {
      await cubit.load();
      await cubit.selectProvince(testProvinces.first);
    });

    test('matches Arabic yeh and kaf typed for Persian ی and ک', () {
      cubit.queryChanged('كرج');
      expect(cubit.state.visibleCities.map((c) => c.name), ['کرج']);

      cubit.queryChanged('شهريار');
      expect(cubit.state.visibleCities.map((c) => c.name), ['شهریار']);
    });

    test('matches a space typed for a half-space', () {
      cubit.queryChanged('رباط كريم');

      expect(cubit.state.visibleCities.map((c) => c.name), ['رباط‌کریم']);
    });

    test('starts empty on every step', () async {
      cubit.queryChanged('کرج');
      cubit.backToProvinces();
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.visibleProvinces, testProvinces, reason: 'the province list is kept, not fetched again');

      cubit.queryChanged('اصف');
      expect(cubit.state.visibleProvinces.map((p) => p.name), ['اصفهان']);
      await cubit.selectProvince(testProvinces[1]);
      expect(cubit.state.query, isEmpty);
    });
  });

  test('cities that arrive after the player went back are not shown', () async {
    await cubit.load();
    final loading = cubit.selectProvince(testProvinces.first);
    cubit.backToProvinces();
    await loading;

    expect(cubit.state.step, CityPickerStep.provinces);
    expect(cubit.state.cities, isEmpty);
  });

  test("a failure shows the server's message, and retry asks again", () async {
    repository.cities[1] = const Left(NetworkFailure('اتصال برقرار نشد'));
    await cubit.load();
    await cubit.selectProvince(testProvinces.first);

    expect(cubit.state.status, CatalogLoadStatus.failure);
    expect(cubit.state.errorMessage, 'اتصال برقرار نشد');

    repository.cities[1] = const Right(tehranCities);
    await cubit.retry();

    expect(cubit.state.status, CatalogLoadStatus.ready);
    expect(cubit.state.visibleCities, tehranCities);
    expect(repository.citiesAskedFor, [1, 1]);
  });
}
