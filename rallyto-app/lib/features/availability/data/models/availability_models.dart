import 'package:json_annotation/json_annotation.dart';

import '../../../../core/utils/jalali_date_text.dart';
import '../../../catalog/domain/entities/sport.dart';
import '../../../profile/data/models/profile_models.dart';
import '../../domain/availability_rules.dart';
import '../../domain/entities/availability_window.dart';

part 'availability_models.g.dart';

/// `AvailabilityView`. Enums arrive as strings; a value this app does not know is dropped.
@JsonSerializable(createToJson: false)
class AvailabilityViewModel {
  const AvailabilityViewModel({
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

  factory AvailabilityViewModel.fromJson(Map<String, dynamic> json) => _$AvailabilityViewModelFromJson(json);

  final String id;
  final String sportId;
  final String sportCode;
  final List<NamedRefModel> venues;
  final String kind;
  final List<String> weekdays;
  final String? date;
  final String startTime;
  final String endTime;
  final List<String> formats;
  final String? note;
  final String status;
  final String? validUntil;
  final bool needsReconfirmation;

  /// Jalali «1405/08/30», or null.
  final String? pausesOn;

  AvailabilityWindow toEntity() {
    final days = {for (final d in weekdays) ?Weekday.tryParse(d)};
    return AvailabilityWindow(
      id: id,
      sportId: sportId,
      sportCode: sportCode,
      venues: [for (final v in venues) v.toEntity()],
      kind: AvailabilityKind.tryParse(kind) ?? AvailabilityKind.recurring,
      weekdays: [
        for (final d in Weekday.values)
          if (days.contains(d)) d,
      ],
      date: date,
      startTime: startTime,
      endTime: endTime,
      formats: [for (final f in formats) ?PlayFormat.tryParse(f)],
      note: note == null || note!.trim().isEmpty ? null : note,
      status: AvailabilityStatus.tryParse(status) ?? AvailabilityStatus.paused,
      validUntil: validUntil,
      needsReconfirmation: needsReconfirmation,
      pausesOn: pausesOn == null || pausesOn!.trim().isEmpty ? null : pausesOn,
    );
  }
}

/// `AvailabilityInput`. Only the members of the window's kind are sent: weekdays and validUntil for a recurring
/// window, the date for a one-off.
@JsonSerializable(createFactory: false, includeIfNull: false)
class AvailabilityInputModel {
  const AvailabilityInputModel({
    required this.sportId,
    required this.venueIds,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.formats,
    this.weekdays,
    this.date,
    this.note,
    this.validUntil,
  });

  factory AvailabilityInputModel.fromDraft(AvailabilityDraft draft) {
    final recurring = draft.kind == AvailabilityKind.recurring;
    final note = draft.note?.trim();
    final date = draft.date;
    final validUntil = draft.validUntil;
    return AvailabilityInputModel(
      sportId: draft.sportId,
      venueIds: draft.venueIds,
      kind: draft.kind.wire,
      weekdays: recurring
          ? [
              for (final d in Weekday.values)
                if (draft.weekdays.contains(d)) d.wire,
            ]
          : null,
      date: !recurring && date != null ? JalaliDateText.toApi(date) : null,
      startTime: TimeOfDayText.toApi(draft.startMinute),
      endTime: TimeOfDayText.toApi(draft.endMinute),
      formats: [
        for (final f in PlayFormat.values)
          if (draft.formats.contains(f)) f.wire,
      ],
      note: note == null || note.isEmpty ? null : note,
      validUntil: recurring && validUntil != null ? JalaliDateText.toApi(validUntil) : null,
    );
  }

  final String sportId;
  final List<String> venueIds;
  final String kind;
  final List<String>? weekdays;
  final String? date;
  final String startTime;
  final String endTime;
  final List<String> formats;
  final String? note;
  final String? validUntil;

  Map<String, dynamic> toJson() => _$AvailabilityInputModelToJson(this);
}
