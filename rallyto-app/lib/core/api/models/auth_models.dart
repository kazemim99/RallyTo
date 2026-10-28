import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

/// Body of `POST /api/v1/auth/otp/send`.
@JsonSerializable(createFactory: false)
class OtpSendRequest {
  const OtpSendRequest({required this.phoneNumber});

  /// Canonical 11-digit form, «09xxxxxxxxx» (see `PersianDigits.canonicalMobile`).
  final String phoneNumber;

  Map<String, dynamic> toJson() => _$OtpSendRequestToJson(this);
}

/// `data` of `POST /api/v1/auth/otp/send`.
@JsonSerializable(createToJson: false)
class OtpSendResponse {
  const OtpSendResponse({required this.expiresInSeconds, required this.resendAfterSeconds});

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) => _$OtpSendResponseFromJson(json);

  /// How long the code stays valid.
  final int expiresInSeconds;

  /// How long before another code may be asked for.
  final int resendAfterSeconds;
}

/// Body of `POST /api/v1/auth/otp/verify`.
@JsonSerializable(createFactory: false)
class OtpVerifyRequest {
  const OtpVerifyRequest({required this.phoneNumber, required this.code});

  final String phoneNumber;
  final String code;

  Map<String, dynamic> toJson() => _$OtpVerifyRequestToJson(this);
}

/// Body of `POST /api/v1/auth/refresh`.
@JsonSerializable(createFactory: false)
class RefreshTokenRequest {
  const RefreshTokenRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

/// `data` of `POST /api/v1/auth/otp/verify` and `POST /api/v1/auth/refresh`.
@JsonSerializable(createToJson: false)
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
    this.profileCompleted = false,
    this.roles = const [],
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) => _$TokenResponseFromJson(json);

  final String accessToken;
  final DateTime? accessTokenExpiresAt;

  /// Single-use: the next refresh answers with a new one, and the old one is refused from then on.
  final String refreshToken;
  final DateTime? refreshTokenExpiresAt;

  /// False until the player has finished onboarding; the router holds them on `/onboarding` until then.
  final bool profileCompleted;

  final List<String> roles;
}
