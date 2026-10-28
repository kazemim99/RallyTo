// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SportModel _$SportModelFromJson(Map<String, dynamic> json) => SportModel(
  id: json['id'] as String,
  code: json['code'] as String,
  nameFa: json['nameFa'] as String,
  nameEn: json['nameEn'] as String? ?? '',
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  isActive: json['isActive'] as bool? ?? true,
  defaultSessionMinutes: (json['defaultSessionMinutes'] as num?)?.toInt() ?? 90,
  formats:
      (json['formats'] as List<dynamic>?)?.map((e) => SportFormatModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  levels:
      (json['levels'] as List<dynamic>?)?.map((e) => SportLevelModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  surfaces: (json['surfaces'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
);

Map<String, dynamic> _$SportModelToJson(SportModel instance) => <String, dynamic>{
  'id': instance.id,
  'code': instance.code,
  'nameFa': instance.nameFa,
  'nameEn': instance.nameEn,
  'sortOrder': instance.sortOrder,
  'isActive': instance.isActive,
  'defaultSessionMinutes': instance.defaultSessionMinutes,
  'formats': instance.formats.map((e) => e.toJson()).toList(),
  'levels': instance.levels.map((e) => e.toJson()).toList(),
  'surfaces': instance.surfaces,
};

SportFormatModel _$SportFormatModelFromJson(Map<String, dynamic> json) => SportFormatModel(
  format: json['format'] as String,
  playersPerSide: (json['playersPerSide'] as num).toInt(),
  capacity: (json['capacity'] as num).toInt(),
);

Map<String, dynamic> _$SportFormatModelToJson(SportFormatModel instance) => <String, dynamic>{
  'format': instance.format,
  'playersPerSide': instance.playersPerSide,
  'capacity': instance.capacity,
};

SportLevelModel _$SportLevelModelFromJson(Map<String, dynamic> json) => SportLevelModel(
  tier: json['tier'] as String,
  order: (json['order'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
);

Map<String, dynamic> _$SportLevelModelToJson(SportLevelModel instance) => <String, dynamic>{
  'tier': instance.tier,
  'order': instance.order,
  'name': instance.name,
  'description': instance.description,
};

ProvinceModel _$ProvinceModelFromJson(Map<String, dynamic> json) =>
    ProvinceModel(id: (json['id'] as num).toInt(), name: json['name'] as String);

CityModel _$CityModelFromJson(Map<String, dynamic> json) => CityModel(
  id: (json['id'] as num).toInt(),
  provinceId: (json['provinceId'] as num).toInt(),
  name: json['name'] as String,
  activeVenueCount: (json['activeVenueCount'] as num?)?.toInt() ?? 0,
);

VenueModel _$VenueModelFromJson(Map<String, dynamic> json) => VenueModel(
  id: json['id'] as String,
  name: json['name'] as String,
  cityId: (json['cityId'] as num).toInt(),
  cityName: json['cityName'] as String? ?? '',
  address: json['address'] as String?,
  phone: json['phone'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  status: json['status'] as String?,
  googlePlaceId: json['googlePlaceId'] as String?,
  sports:
      (json['sports'] as List<dynamic>?)?.map((e) => VenueSportModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
);

VenueSportModel _$VenueSportModelFromJson(Map<String, dynamic> json) => VenueSportModel(
  sportCode: json['sportCode'] as String,
  courtCount: (json['courtCount'] as num?)?.toInt(),
  setting: json['setting'] as String?,
  surface: json['surface'] as String?,
  hasLighting: json['hasLighting'] as bool? ?? false,
);
