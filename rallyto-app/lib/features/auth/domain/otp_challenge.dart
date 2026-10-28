import 'package:equatable/equatable.dart';

/// A sign-in code on its way: the number it was sent to and the server's timings. Carried from phone entry to code
/// entry as the route's `extra`.
class OtpChallenge extends Equatable {
  const OtpChallenge({required this.phoneNumber, required this.expiresInSeconds, required this.resendAfterSeconds});

  /// Canonical «09xxxxxxxxx», as sent.
  final String phoneNumber;

  /// How long the code stays valid.
  final int expiresInSeconds;

  /// How long before another code may be asked for.
  final int resendAfterSeconds;

  @override
  List<Object?> get props => [phoneNumber, expiresInSeconds, resendAfterSeconds];
}
