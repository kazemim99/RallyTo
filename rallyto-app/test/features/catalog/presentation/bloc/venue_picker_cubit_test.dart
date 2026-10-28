import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/errors/failures.dart';
import 'package:rallyto_app/features/catalog/domain/entities/venue.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/catalog_load_status.dart';
import 'package:rallyto_app/features/catalog/presentation/bloc/venue_picker_cubit.dart';

import '../../../../helpers/fake_catalog.dart';

/// Venue search as the player types (debounced, latest answer wins), and multi-select up to a limit.
void main() {
  late FakeCatalogRepository repository;

  setUp(() => repository = FakeCatalogRepository());

  VenuePickerCubit cubitFor({int max = 3, String? sport = 'tennis', List<Venue> initial = const []}) =>
      VenuePickerCubit(
        repository,
        VenuePickerArgs(cityId: 10, sportCode: sport, maxSelection: max, initialSelection: initial),
      );

  test('opens with every venue of the city for the sport, and the sport names for the tags', () async {
    final cubit = cubitFor();
    addTearDown(cubit.close);

    await cubit.start();

    expect(repository.searches.single, (cityId: 10, sportCode: 'tennis', query: ''));
    expect(cubit.state.status, CatalogLoadStatus.ready);
    expect(cubit.state.results, testVenues);
    expect(cubit.state.sportNames, {'tennis': 'تنیس', 'padel': 'پدل'});
  });

  group('debounced search', () {
    test('a word typed quickly is one request, sent once typing pauses', () {
      fakeAsync((async) {
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();
        repository.searches.clear();

        cubit.queryChanged('ب');
        async.elapse(const Duration(milliseconds: 150));
        cubit.queryChanged('باش');
        async.elapse(const Duration(milliseconds: 150));
        cubit.queryChanged('باشگاه');
        async.elapse(const Duration(milliseconds: 399));
        expect(repository.searches, isEmpty, reason: 'still typing');
        expect(cubit.state.query, 'باشگاه', reason: 'the field follows every keystroke');

        async.elapse(const Duration(milliseconds: 1));
        expect(repository.searches.map((s) => s.query), ['باشگاه']);
        expect(cubit.state.results.map((v) => v.id), ['v-1', 'v-3', 'v-4']);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('typing back to what was last searched sends nothing', () {
      fakeAsync((async) {
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();

        cubit.queryChanged('آزادی');
        async.elapse(VenuePickerCubit.defaultDebounce);
        cubit.queryChanged('آزادی ');
        async.elapse(VenuePickerCubit.defaultDebounce);

        expect(repository.searches.map((s) => s.query), ['', 'آزادی']);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('a slow earlier answer does not replace a later one', () {
      fakeAsync((async) {
        final slow = Completer<void>();
        final fast = Completer<void>();
        repository.searchGates = [Completer<void>()..complete(), slow, fast];
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();

        cubit.queryChanged('انقلاب');
        async.elapse(VenuePickerCubit.defaultDebounce);
        cubit.queryChanged('آزادی');
        async.elapse(VenuePickerCubit.defaultDebounce);
        fast.complete();
        async.flushMicrotasks();
        slow.complete();
        async.flushMicrotasks();

        expect(cubit.state.results.map((v) => v.name), ['مجموعه آزادی']);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test("a failure shows the server's message, and retry searches again at once", () async {
      repository.venues = (_) => const Left(ServerFailure('خطای سرور'));
      final cubit = cubitFor();
      addTearDown(cubit.close);
      await cubit.start();

      expect(cubit.state.status, CatalogLoadStatus.failure);
      expect(cubit.state.errorMessage, 'خطای سرور');

      repository.venues = (_) => Right(testVenues);
      await cubit.retry();

      expect(cubit.state.status, CatalogLoadStatus.ready);
      expect(repository.searches, hasLength(2));
    });
  });

  group('selection', () {
    test('up to the limit; one more is refused and counted, so the screen can say why', () async {
      final cubit = cubitFor(max: 2);
      addTearDown(cubit.close);
      await cubit.start();

      cubit
        ..toggle(testVenues[0])
        ..toggle(testVenues[1])
        ..toggle(testVenues[2]);

      expect(cubit.state.selected.map((v) => v.id), ['v-1', 'v-2']);
      expect(cubit.state.isFull, isTrue);
      expect(cubit.state.limitHits, 1);
    });

    test('unselecting frees a place', () async {
      final cubit = cubitFor(max: 2);
      addTearDown(cubit.close);
      await cubit.start();

      cubit
        ..toggle(testVenues[0])
        ..toggle(testVenues[1])
        ..toggle(testVenues[0])
        ..toggle(testVenues[2]);

      expect(cubit.state.selected.map((v) => v.id), ['v-2', 'v-3']);
      expect(cubit.state.limitHits, 0);
    });

    test('is kept across searches', () {
      fakeAsync((async) {
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();
        cubit.toggle(testVenues[0]);

        cubit.queryChanged('آزادی');
        async.elapse(VenuePickerCubit.defaultDebounce);

        expect(cubit.state.results.map((v) => v.id), ['v-2']);
        expect(cubit.state.selected.map((v) => v.id), ['v-1']);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('the limit is 1 to 5, and an initial selection is kept within it', () {
      expect(VenuePickerArgs(cityId: 10, maxSelection: 0).maxSelection, 1);
      expect(VenuePickerArgs(cityId: 10, maxSelection: 9).maxSelection, 5);

      final cubit = cubitFor(max: 2, initial: testVenues);
      addTearDown(cubit.close);
      expect(cubit.state.selected.map((v) => v.id), ['v-1', 'v-2']);
    });
  });
}
