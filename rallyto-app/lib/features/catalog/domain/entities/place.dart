import 'package:equatable/equatable.dart';

/// One of Iran's provinces.
class Province extends Equatable {
  const Province({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// A city, with how many active clubs it has.
class City extends Equatable {
  const City({required this.id, required this.provinceId, required this.name, this.activeVenueCount = 0});

  final int id;
  final int provinceId;
  final String name;
  final int activeVenueCount;

  @override
  List<Object?> get props => [id, provinceId, name, activeVenueCount];
}

/// What `CityPicker` returns.
class CitySelection extends Equatable {
  const CitySelection({required this.cityId, required this.cityName, this.provinceName});

  final int cityId;
  final String cityName;

  /// The province the city was picked from; null when the selection did not come from the picker.
  final String? provinceName;

  @override
  List<Object?> get props => [cityId, cityName, provinceName];
}
