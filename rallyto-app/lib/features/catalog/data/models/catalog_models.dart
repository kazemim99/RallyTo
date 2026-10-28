import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/place.dart';
import '../../domain/entities/sport.dart';
import '../../domain/entities/venue.dart';

part 'catalog_models.g.dart';

// The catalog's wire shapes. Enums arrive as strings («Singles», «Advanced», «Indoor»); they are kept as strings
// here and parsed into the domain's enums by `toEntity`, where a value this app does not know is dropped instead of
// failing the whole response.

/// An item of `GET /api/v1/sports`. Also written to the device as the persisted sports cache, hence [toJson].
@JsonSerializable(explicitToJson: true)
class SportModel {
  const SportModel({
    required this.id,
    required this.code,
    required this.nameFa,
    this.nameEn = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.defaultSessionMinutes = 90,
    this.formats = const [],
    this.levels = const [],
    this.surfaces = const [],
  });

  factory SportModel.fromJson(Map<String, dynamic> json) => _$SportModelFromJson(json);

  final String id;
  final String code;
  final String nameFa;
  final String nameEn;
  final int sortOrder;
  final bool isActive;
  final int defaultSessionMinutes;
  final List<SportFormatModel> formats;
  final List<SportLevelModel> levels;
  final List<String> surfaces;

  Map<String, dynamic> toJson() => _$SportModelToJson(this);

  Sport toEntity() {
    final levels = [for (final level in this.levels) ?level.toEntity()]..sort((a, b) => a.order.compareTo(b.order));
    return Sport(
      id: id,
      code: code,
      nameFa: nameFa,
      nameEn: nameEn,
      sortOrder: sortOrder,
      isActive: isActive,
      defaultSessionMinutes: defaultSessionMinutes,
      formats: [for (final format in formats) ?format.toEntity()],
      levels: levels,
      surfaces: [for (final surface in surfaces) ?CourtSurface.tryParse(surface)],
    );
  }
}

@JsonSerializable()
class SportFormatModel {
  const SportFormatModel({required this.format, required this.playersPerSide, required this.capacity});

  factory SportFormatModel.fromJson(Map<String, dynamic> json) => _$SportFormatModelFromJson(json);

  final String format;
  final int playersPerSide;
  final int capacity;

  Map<String, dynamic> toJson() => _$SportFormatModelToJson(this);

  SportFormat? toEntity() {
    final parsed = PlayFormat.tryParse(format);
    return parsed == null ? null : SportFormat(format: parsed, playersPerSide: playersPerSide, capacity: capacity);
  }
}

@JsonSerializable()
class SportLevelModel {
  const SportLevelModel({required this.tier, required this.order, required this.name, this.description = ''});

  factory SportLevelModel.fromJson(Map<String, dynamic> json) => _$SportLevelModelFromJson(json);

  final String tier;
  final int order;

  /// Persian, e.g. «مبتدی».
  final String name;

  /// Persian, written per sport.
  final String description;

  Map<String, dynamic> toJson() => _$SportLevelModelToJson(this);

  SportLevel? toEntity() {
    final parsed = LevelTier.tryParse(tier);
    return parsed == null ? null : SportLevel(tier: parsed, order: order, name: name, description: description);
  }
}

/// An item of `GET /api/v1/provinces`.
@JsonSerializable(createToJson: false)
class ProvinceModel {
  const ProvinceModel({required this.id, required this.name});

  factory ProvinceModel.fromJson(Map<String, dynamic> json) => _$ProvinceModelFromJson(json);

  final int id;
  final String name;

  Province toEntity() => Province(id: id, name: name);
}

/// An item of `GET /api/v1/provinces/{id}/cities`.
@JsonSerializable(createToJson: false)
class CityModel {
  const CityModel({required this.id, required this.provinceId, required this.name, this.activeVenueCount = 0});

  factory CityModel.fromJson(Map<String, dynamic> json) => _$CityModelFromJson(json);

  final int id;
  final int provinceId;
  final String name;
  final int activeVenueCount;

  City toEntity() => City(id: id, provinceId: provinceId, name: name, activeVenueCount: activeVenueCount);
}

/// An item of `GET /api/v1/venues`, and the body of `GET /api/v1/venues/{id}`.
@JsonSerializable(createToJson: false)
class VenueModel {
  const VenueModel({
    required this.id,
    required this.name,
    required this.cityId,
    this.cityName = '',
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.status,
    this.googlePlaceId,
    this.sports = const [],
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) => _$VenueModelFromJson(json);

  final String id;
  final String name;
  final int cityId;
  final String cityName;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? status;
  final String? googlePlaceId;
  final List<VenueSportModel> sports;

  Venue toEntity() => Venue(
    id: id,
    name: name,
    cityId: cityId,
    cityName: cityName,
    address: _blankToNull(address),
    phone: _blankToNull(phone),
    latitude: latitude,
    longitude: longitude,
    status: status,
    googlePlaceId: googlePlaceId,
    sports: [for (final sport in sports) sport.toEntity()],
  );
}

@JsonSerializable(createToJson: false)
class VenueSportModel {
  const VenueSportModel({
    required this.sportCode,
    this.courtCount,
    this.setting,
    this.surface,
    this.hasLighting = false,
  });

  factory VenueSportModel.fromJson(Map<String, dynamic> json) => _$VenueSportModelFromJson(json);

  final String sportCode;
  final int? courtCount;
  final String? setting;
  final String? surface;
  final bool hasLighting;

  VenueSport toEntity() => VenueSport(
    sportCode: sportCode,
    courtCount: courtCount,
    setting: CourtSetting.tryParse(setting),
    surface: CourtSurface.tryParse(surface),
    hasLighting: hasLighting,
  );
}

String? _blankToNull(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
