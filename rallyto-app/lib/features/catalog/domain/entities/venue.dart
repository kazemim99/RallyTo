import 'package:equatable/equatable.dart';

import 'sport.dart';

/// Whether a venue's courts for a sport are under a roof.
enum CourtSetting {
  indoor('Indoor'),
  outdoor('Outdoor'),
  both('Both');

  const CourtSetting(this.wire);

  final String wire;

  static CourtSetting? tryParse(String? value) {
    for (final item in values) {
      if (item.wire.toLowerCase() == value?.toLowerCase()) return item;
    }
    return null;
  }
}

/// A club or sports complex.
class Venue extends Equatable {
  const Venue({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.status,
    this.googlePlaceId,
    this.sports = const [],
  });

  final String id;
  final String name;
  final int cityId;
  final String cityName;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;

  /// `Active` or `Hidden`, as the server writes it. The player's endpoints return active venues only.
  final String? status;
  final String? googlePlaceId;
  final List<VenueSport> sports;

  /// Whether the venue can be shown on a map.
  bool get hasLocation => latitude != null && longitude != null;

  @override
  List<Object?> get props => [
    id,
    name,
    cityId,
    cityName,
    address,
    phone,
    latitude,
    longitude,
    status,
    googlePlaceId,
    sports,
  ];
}

/// The courts a venue has for one sport.
class VenueSport extends Equatable {
  const VenueSport({required this.sportCode, this.courtCount, this.setting, this.surface, this.hasLighting = false});

  final String sportCode;

  /// Null when the club has not said.
  final int? courtCount;
  final CourtSetting? setting;
  final CourtSurface? surface;
  final bool hasLighting;

  @override
  List<Object?> get props => [sportCode, courtCount, setting, surface, hasLighting];
}
