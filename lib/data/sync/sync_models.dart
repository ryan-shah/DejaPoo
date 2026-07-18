import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/domain/stool_color.dart';
import 'package:dejapoo/domain/stool_size.dart';

/// The current snapshot schema version. Bump when the on-disk/on-Drive JSON
/// shape changes in a way older app versions cannot read.
const int syncSnapshotVersion = 1;

/// A versioned, JSON-transportable snapshot of all bowel movement records,
/// used for Google Drive sync.
class SyncSnapshot {
  const SyncSnapshot({
    required this.version,
    required this.generatedAt,
    required this.records,
  });

  /// Schema version. Always [syncSnapshotVersion] for snapshots this app
  /// version writes.
  final int version;

  /// When this snapshot was generated (UTC).
  final DateTime generatedAt;

  final List<SyncRecord> records;

  Map<String, dynamic> toJson() => {
        'version': version,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      };

  /// Parses a snapshot from JSON. Throws a [FormatException] if the
  /// snapshot's [version] is newer than this app understands.
  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int;
    if (version > syncSnapshotVersion) {
      throw FormatException(
        'Please update the app to sync with this snapshot (version $version)',
      );
    }
    final rawRecords = json['records'] as List<dynamic>;
    return SyncSnapshot(
      version: version,
      generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
      records: rawRecords
          .map((r) => SyncRecord.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A JSON-transportable representation of a [BowelMovement].
class SyncRecord {
  const SyncRecord({
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
  });

  final String id;

  /// Local wall time of the event (no timezone conversion applied).
  final DateTime occurredAt;

  final bool dateOnly;

  /// Bristol Stool Chart type number (1-7).
  final int bristolType;

  /// [StoolSize] enum index, or null.
  final int? size;

  /// [StoolColor] enum index, or null.
  final int? color;

  final int? urgency;
  final int? strain;
  final bool? blood;
  final String? note;

  /// UTC.
  final DateTime createdAt;

  /// UTC. Drives last-write-wins merge.
  final DateTime updatedAt;

  /// UTC. Non-null means this record is a tombstone (soft-deleted).
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        // Local wall time: strip any zone info by using the raw ISO string
        // of a non-UTC DateTime (no trailing 'Z').
        'occurredAt': _isoLocal(occurredAt),
        'dateOnly': dateOnly,
        'bristolType': bristolType,
        'size': size,
        'color': color,
        'urgency': urgency,
        'strain': strain,
        'blood': blood,
        'note': note,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
      };

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    return SyncRecord(
      id: json['id'] as String,
      occurredAt: _parseLocal(json['occurredAt'] as String),
      dateOnly: json['dateOnly'] as bool,
      bristolType: json['bristolType'] as int,
      size: json['size'] as int?,
      color: json['color'] as int?,
      urgency: json['urgency'] as int?,
      strain: json['strain'] as int?,
      blood: json['blood'] as bool?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toUtc(),
    );
  }

  /// Builds a [SyncRecord] from a domain [BowelMovement].
  factory SyncRecord.fromBowelMovement(BowelMovement bm) {
    return SyncRecord(
      id: bm.id,
      occurredAt: bm.occurredAt,
      dateOnly: bm.dateOnly,
      bristolType: bm.bristolType.number,
      size: bm.size?.index,
      color: bm.color?.index,
      urgency: bm.urgency,
      strain: bm.strain,
      blood: bm.blood,
      note: bm.note,
      createdAt: bm.createdAt,
      updatedAt: bm.updatedAt,
      deletedAt: bm.deletedAt,
    );
  }

  /// Converts this sync record back into a domain [BowelMovement].
  BowelMovement toBowelMovement() {
    return BowelMovement(
      id: id,
      occurredAt: occurredAt,
      dateOnly: dateOnly,
      bristolType: BristolType.fromNumber(bristolType),
      size: size == null ? null : StoolSize.values[size!],
      color: color == null ? null : StoolColor.values[color!],
      urgency: urgency,
      strain: strain,
      blood: blood,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SyncRecord &&
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
      'SyncRecord($id, updatedAt=$updatedAt'
      '${deletedAt != null ? ', deleted' : ''})';
}

/// Formats [dt] as an ISO-8601 string with no timezone suffix, preserving
/// whatever wall-clock time it holds (local or otherwise) without applying
/// any UTC conversion.
String _isoLocal(DateTime dt) {
  final iso = dt.toIso8601String();
  // DateTime.toIso8601String() appends 'Z' only when the instance is UTC.
  // occurredAt is expected to be a local (non-UTC) DateTime already; if it
  // happens to be UTC, strip the 'Z' so round-tripping via fromJson (which
  // parses as local/naive) doesn't reinterpret it.
  return iso.endsWith('Z') ? iso.substring(0, iso.length - 1) : iso;
}

/// Parses an ISO-8601 string with no timezone suffix as a local (naive)
/// [DateTime], matching how [_isoLocal] writes it.
DateTime _parseLocal(String s) => DateTime.parse(s);
