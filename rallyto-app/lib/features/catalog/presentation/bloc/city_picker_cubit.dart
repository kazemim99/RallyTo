import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/persian_text.dart';
import '../../domain/catalog_repository.dart';
import '../../domain/entities/place.dart';
import 'catalog_load_status.dart';

part 'city_picker_state.dart';

/// City selection in two steps: a province, then one of its cities. Each list has a search field that matches
/// Persian text however it was typed (Arabic ي/ك, half-spaces, digits).
@injectable
class CityPickerCubit extends Cubit<CityPickerState> {
  CityPickerCubit(this._repository) : super(const CityPickerState());

  final CatalogRepository _repository;

  /// Loads the provinces. Called once when the picker opens.
  Future<void> load() async {
    emit(state.copyWith(step: CityPickerStep.provinces, status: CatalogLoadStatus.loading, errorMessage: () => null));
    final result = await _repository.getProvinces();
    if (isClosed || state.step != CityPickerStep.provinces) return;
    result.fold(
      (failure) => emit(state.copyWith(status: CatalogLoadStatus.failure, errorMessage: () => failure.message)),
      (provinces) => emit(state.copyWith(status: CatalogLoadStatus.ready, provinces: provinces)),
    );
  }

  /// Moves on to [province]'s cities, with an empty search.
  Future<void> selectProvince(Province province) async {
    emit(
      state.copyWith(
        step: CityPickerStep.cities,
        province: () => province,
        cities: const [],
        query: '',
        status: CatalogLoadStatus.loading,
        errorMessage: () => null,
      ),
    );
    final result = await _repository.getCities(province.id);
    // The player may have gone back, or picked another province, while this was loading.
    if (isClosed || state.step != CityPickerStep.cities || state.province != province) return;
    result.fold(
      (failure) => emit(state.copyWith(status: CatalogLoadStatus.failure, errorMessage: () => failure.message)),
      (cities) => emit(state.copyWith(status: CatalogLoadStatus.ready, cities: cities)),
    );
  }

  /// Back to the province list (already loaded), with an empty search.
  void backToProvinces() {
    if (state.provinces.isEmpty) {
      emit(state.copyWith(step: CityPickerStep.provinces, province: () => null, query: ''));
      unawaited(load());
      return;
    }
    emit(
      state.copyWith(
        step: CityPickerStep.provinces,
        province: () => null,
        cities: const [],
        query: '',
        status: CatalogLoadStatus.ready,
        errorMessage: () => null,
      ),
    );
  }

  void queryChanged(String query) => emit(state.copyWith(query: query));

  /// Repeats whatever failed.
  Future<void> retry() async {
    final province = state.province;
    if (state.step == CityPickerStep.cities && province != null) return selectProvince(province);
    return load();
  }
}
