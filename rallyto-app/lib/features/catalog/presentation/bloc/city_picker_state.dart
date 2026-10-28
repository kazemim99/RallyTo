part of 'city_picker_cubit.dart';

enum CityPickerStep { provinces, cities }

class CityPickerState extends Equatable {
  const CityPickerState({
    this.step = CityPickerStep.provinces,
    this.status = CatalogLoadStatus.loading,
    this.provinces = const [],
    this.province,
    this.cities = const [],
    this.query = '',
    this.errorMessage,
  });

  final CityPickerStep step;

  /// The state of the current step's list.
  final CatalogLoadStatus status;
  final List<Province> provinces;

  /// The province whose cities are showing.
  final Province? province;
  final List<City> cities;

  /// The current step's search, as typed.
  final String query;
  final String? errorMessage;

  /// The provinces matching [query].
  List<Province> get visibleProvinces => [
    for (final province in provinces)
      if (PersianText.matches(province.name, query)) province,
  ];

  /// The cities matching [query], in the server's order (those with clubs first).
  List<City> get visibleCities => [
    for (final city in cities)
      if (PersianText.matches(city.name, query)) city,
  ];

  CityPickerState copyWith({
    CityPickerStep? step,
    CatalogLoadStatus? status,
    List<Province>? provinces,
    Province? Function()? province,
    List<City>? cities,
    String? query,
    String? Function()? errorMessage,
  }) => CityPickerState(
    step: step ?? this.step,
    status: status ?? this.status,
    provinces: provinces ?? this.provinces,
    province: province == null ? this.province : province(),
    cities: cities ?? this.cities,
    query: query ?? this.query,
    errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
  );

  @override
  List<Object?> get props => [step, status, provinces, province, cities, query, errorMessage];
}
