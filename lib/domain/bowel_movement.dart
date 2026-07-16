import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/domain/stool_color.dart';
import 'package:dejapoo/domain/stool_size.dart';

/// A single logged bowel movement.
///
/// This is the app-wide domain entity; the Drift table binds to it directly
/// via `@UseRowClass`. See `designs/DESIGN.md` for the data model.
class BowelMovement {
  const BowelMovement({
    required this.id,
    required this.occurredAt,
    required this.dateOnly,
    required this.bristolType,
    required this.createdAt,
    required this.updatedAt,
    this.size,
    this.color,
    this.urgency,
    this.strain,
    this.blood,
    this.note,
    this.deletedAt,
  })  : assert(
          urgency == null || (urgency >= 1 && urgency <= 5),
          'urgency must be on a 1-5 scale',
        ),
        assert(
          strain == null || (strain >= 1 && strain <= 5),
          'strain must be on a 1-5 scale',
        );

  /// Unique identifier (UUID v4, or an importer/fixture-assigned id).
  final String id;

  /// Local time of the event. For [dateOnly] events only the calendar date
  /// is meaningful; the time-of-day component is arbitrary.
  final DateTime occurredAt;

  /// True for events imported from the historical spreadsheet, which records
  /// dates without times. Date-only events count toward daily stats but are
  /// excluded from time-of-day views.
  final bool dateOnly;

  /// The Bristol Stool Chart classification — the primary field.
  final BristolType bristolType;

  /// Optional approximate size.
  final StoolSize? size;

  /// Optional observed color.
  final StoolColor? color;

  /// Optional urgency on a 1-5 scale.
  final int? urgency;

  /// Optional straining effort on a 1-5 scale.
  final int? strain;

  /// Whether blood was observed, when recorded.
  final bool? blood;

  /// Optional free-text note.
  final String? note;

  /// When this record was first created (UTC).
  final DateTime createdAt;

  /// When this record was last modified (UTC). Drives sync merge
  /// (last-write-wins).
  final DateTime updatedAt;

  /// Soft-delete tombstone (UTC). Non-null means deleted; kept for sync.
  final DateTime? deletedAt;

  static const Object _unset = Object();

  /// Returns a copy with the given fields replaced. Nullable fields can be
  /// cleared by passing `null` explicitly.
  BowelMovement copyWith({
    String? id,
    DateTime? occurredAt,
    bool? dateOnly,
    BristolType? bristolType,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? size = _unset,
    Object? color = _unset,
    Object? urgency = _unset,
    Object? strain = _unset,
    Object? blood = _unset,
    Object? note = _unset,
    Object? deletedAt = _unset,
  }) {
    return BowelMovement(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      dateOnly: dateOnly ?? this.dateOnly,
      bristolType: bristolType ?? this.bristolType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      size: identical(size, _unset) ? this.size : size as StoolSize?,
      color: identical(color, _unset) ? this.color : color as StoolColor?,
      urgency: identical(urgency, _unset) ? this.urgency : urgency as int?,
      strain: identical(strain, _unset) ? this.strain : strain as int?,
      blood: identical(blood, _unset) ? this.blood : blood as bool?,
      note: identical(note, _unset) ? this.note : note as String?,
      deletedAt:
          identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BowelMovement &&
        other.id == id &&
        other.occurredAt == occurredAt &&
        other.dateOnly == dateOnly &&
        other.bristolType == bristolType &&
        other.size == size &&
        other.color == color &&
        other.urgency == urgency &&
        other.strain == strain &&
        other.blood == blood &&
        other.note == note &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        occurredAt,
        dateOnly,
        bristolType,
        size,
        color,
        urgency,
        strain,
        blood,
        note,
        createdAt,
        updatedAt,
        deletedAt,
      );

  @override
  String toString() =>
      'BowelMovement($id, $occurredAt, type ${bristolType.number}'
      '${deletedAt != null ? ', deleted' : ''})';
}
