import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile_enums.dart';

/// What a report is about.
enum ReportTargetType {
  player('Player'),
  message('Message'),
  post('Post'),
  photo('Photo');

  const ReportTargetType(this.wire);

  final String wire;

  static ReportTargetType? tryParse(String? value) => parseWire(values, value, (t) => t.wire);
}

/// Why it is reported (spec trust-safety › Report content and behaviour).
enum ReportReason {
  harassment('Harassment'),
  inappropriateContent('InappropriateContent'),
  fakeProfile('FakeProfile'),
  spam('Spam'),
  unsafeBehaviour('UnsafeBehaviour'),
  underage('Underage'),
  other('Other');

  const ReportReason(this.wire);

  final String wire;

  static ReportReason? tryParse(String? value) => parseWire(values, value, (r) => r.wire);
}

/// What the reporter sees of a report: open, or resolved. Never the action taken.
enum ReportStatus {
  open('Open'),
  resolved('Resolved');

  const ReportStatus(this.wire);

  final String wire;

  static ReportStatus? tryParse(String? value) => parseWire(values, value, (s) => s.wire);
}

/// The thing being reported, and the player behind it when the screen knows their name.
class ReportTarget extends Equatable {
  /// A player's profile; [userId] is theirs.
  const ReportTarget.player(String userId, {this.playerName}) : type = ReportTargetType.player, targetId = userId;

  /// A chat message; [messageId] is the message's id, [senderName] who sent it.
  const ReportTarget.message(String messageId, {String? senderName})
    : type = ReportTargetType.message,
      targetId = messageId,
      playerName = senderName;

  /// A play post; [matchId] is the game's id, [hostName] who posted it.
  const ReportTarget.post(String matchId, {String? hostName})
    : type = ReportTargetType.post,
      targetId = matchId,
      playerName = hostName;

  /// A profile photo; [userId] is the owner's.
  const ReportTarget.photo(String userId, {this.playerName}) : type = ReportTargetType.photo, targetId = userId;

  final ReportTargetType type;
  final String targetId;

  /// The player who would be blocked with the report, when known.
  final String? playerName;

  @override
  List<Object?> get props => [type, targetId, playerName];
}

/// A report as the player fills it in, sent as `ReportRequest`.
class ReportDraft extends Equatable {
  const ReportDraft({required this.target, required this.reason, this.details, this.block = false});

  final ReportTarget target;
  final ReportReason reason;

  /// Up to 1000 characters.
  final String? details;

  /// Block the player behind the target in the same step.
  final bool block;

  @override
  List<Object?> get props => [target, reason, details, block];
}

/// The stored report (`ReportReceiptView`).
class ReportReceipt extends Equatable {
  const ReportReceipt({required this.id, required this.status});

  final String id;
  final ReportStatus status;

  @override
  List<Object?> get props => [id, status];
}

/// One of this player's reports (`MyReportView`). A type or reason this app does not know is null.
class MyReport extends Equatable {
  const MyReport({required this.id, required this.status, required this.createdAt, this.targetType, this.reason});

  final String id;
  final ReportTargetType? targetType;
  final ReportReason? reason;
  final ReportStatus status;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, targetType, reason, status, createdAt];
}
