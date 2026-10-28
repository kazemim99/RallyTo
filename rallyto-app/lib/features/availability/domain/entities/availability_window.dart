import 'package:equatable/equatable.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/domain/entities/player_profile.dart';
import '../../../profile/domain/entities/profile_enums.dart';

/// Days of the Iranian week, Saturday first, as the server spells them.
enum Weekday {
  saturday('Saturday'),
  sunday('Sunday'),
  monday('Monday'),
  tuesday('Tuesday'),
  wednesday('Wednesday'),
  thursday('Thursday'),
  friday('Friday');

  const Weekday(this.wire);

  final String wire;

  static Weekday? tryParse(String? value) => parseWire(values, value, (d) => d.wire);
}

/// Every week on the chosen days, or once on one date.
enum AvailabilityKind {
  recurring('Recurring'),
  oneOff('OneOff');

  const AvailabilityKind(this.wire);

  final String wire;

  static AvailabilityKind? tryParse(String? value) => parseWire(values, value, (k) => k.wire);
}

/// A recurring window not confirmed for 30 days pauses itself; a one-off expires once its date has passed.
enum AvailabilityStatus {
  active('Active'),
  paused('Paused'),
  expired('Expired');

  const AvailabilityStatus(this.wire);

  final String wire;

  static AvailabilityStatus? tryParse(String? value) => parseWire(values, value, (s) => s.wire);
}

/// When and where a player is free to play a sport, as the server returns it.
class AvailabilityWindow extends Equatable {
  const AvailabilityWindow({
    required this.id,
    required this.sportId,
    required this.sportCode,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.venues = const [],
    this.weekdays = const [],
    this.date,
    this.formats = const [],
    this.note,
    this.validUntil,
    this.needsReconfirmation = false,
    this.pausesOn,
  });

  final String id;
  final String sportId;
  final String sportCode;
  final List<NamedRef> venues;
  final AvailabilityKind kind;

  /// Recurring only, Saturday first.
  final List<Weekday> weekdays;

  /// One-off only: Jalali «1405/08/08».
  final String? date;

  /// «HH:mm» on Tehran's clock; [endTime] may be «24:00».
  final String startTime;
  final String endTime;
  final List<PlayFormat> formats;
  final String? note;
  final AvailabilityStatus status;

  /// Recurring only, optional: Jalali «1405/12/29».
  final String? validUntil;

  /// An active weekly window 27 or more days after its last confirmation: «هنوز آزادم» keeps it from pausing itself.
  final bool needsReconfirmation;

  /// An active weekly window only: the Jalali day («1405/08/30») it pauses itself unless confirmed; null otherwise.
  final String? pausesOn;

  @override
  List<Object?> get props => [
    id,
    sportId,
    sportCode,
    venues,
    kind,
    weekdays,
    date,
    startTime,
    endTime,
    formats,
    note,
    status,
    validUntil,
    needsReconfirmation,
    pausesOn,
  ];
}

/// A window as the player fills it in, sent as `AvailabilityInput`. Times are minutes from midnight on Tehran's
/// clock (1440 is «24:00», allowed only as the end).
class AvailabilityDraft extends Equatable {
  const AvailabilityDraft({
    required this.sportId,
    required this.venueIds,
    required this.kind,
    required this.startMinute,
    required this.endMinute,
    required this.formats,
    this.weekdays = const {},
    this.date,
    this.note,
    this.validUntil,
  });

  final String sportId;
  final List<String> venueIds;
  final AvailabilityKind kind;
  final Set<Weekday> weekdays;
  final Jalali? date;
  final int startMinute;
  final int endMinute;
  final Set<PlayFormat> formats;
  final String? note;
  final Jalali? validUntil;

  @override
  List<Object?> get props => [
    sportId,
    venueIds,
    kind,
    weekdays,
    date,
    startMinute,
    endMinute,
    formats,
    note,
    validUntil,
  ];
}
