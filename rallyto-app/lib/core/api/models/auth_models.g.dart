// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OtpSendRequestToJson(OtpSendRequest instance) => <String, dynamic>{
  'phoneNumber': instance.phoneNumber,
};

OtpSendResponse _$OtpSendResponseFromJson(Map<String, dynamic> json) => OtpSendResponse(
  expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
  resendAfterSeconds: (json['resendAfterSeconds'] as num).toInt(),
);

Map<String, dynamic> _$OtpVerifyRequestToJson(OtpVerifyRequest instance) => <String, dynamic>{
  'phoneNumber': instance.phoneNumber,
  'code': instance.code,
};

Map<String, dynamic> _$RefreshTokenRequestToJson(RefreshTokenRequest instance) => <String, dynamic>{
  'refreshToken': instance.refreshToken,
};

TokenResponse _$TokenResponseFromJson(Map<String, dynamic> json) => TokenResponse(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  accessTokenExpiresAt: json['accessTokenExpiresAt'] == null
      ? null
      : DateTime.parse(json['accessTokenExpiresAt'] as String),
  refreshTokenExpiresAt: json['refreshTokenExpiresAt'] == null
      ? null
      : DateTime.parse(json['refreshTokenExpiresAt'] as String),
  profileCompleted: json['profileCompleted'] as bool? ?? false,
  roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
);
