import 'package:dejapoo/data/sync/sync_models.dart';
import 'package:dejapoo/domain/bowel_movement.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/domain/stool_color.dart';
import 'package:dejapoo/domain/stool_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncRecord JSON round-trip', () {
    test('round-trips all fields when fully populated', () {
      final record = SyncRecord(
        id: 'abc-123',
        occurredAt: DateTime(2026, 7, 17, 8, 30, 15),
        dateOnly: false,
        bristolType: 4,
        size: StoolSize.medium.index,
        color: StoolColor.brown.index,
        urgency: 3,
        strain: 2,
        blood: false,
        note: 'a note',
        createdAt: DateTime.utc(2026, 7, 17, 8, 30, 20),
        updatedAt: DateTime.utc(2026, 7, 17, 9, 0, 0),
        deletedAt: DateTime.utc(2026, 7, 18, 0, 0, 0),
      );

      final json = record.toJson();
      final restored = SyncRecord.fromJson(json);

      expect(restored.id, record.id);
      expect(restored.occurredAt, record.occurredAt);
      expect(restored.dateOnly, record.dateOnly);
      expect(restored.bristolType, record.bristolType);
      expect(restored.size, record.size);
      expect(restored.color, record.color);
      expect(restored.urgency, record.urgency);
      expect(restored.strain, record.strain);
      expect(restored.blood, record.blood);
      expect(restored.note, record.note);
      expect(restored.createdAt, record.createdAt);
      expect(restored.updatedAt, record.updatedAt);
      expect(restored.deletedAt, record.deletedAt);
    });

    test('round-trips with all nullable fields null', () {
      final record = SyncRecord(
        id: 'no-optionals',
        occurredAt: DateTime(2026, 1, 1, 12),
        dateOnly: true,
        bristolType: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final restored = SyncRecord.fromJson(record.toJson());

      expect(restored.size, isNull);
      expect(restored.color, isNull);
      expect(restored.urgency, isNull);
      expect(restored.strain, isNull);
      expect(restored.blood, isNull);
      expect(restored.note, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.dateOnly, true);
    });

    test('occurredAt is stored as local ISO string with no Z suffix', () {
      final record = SyncRecord(
        id: 'x',
        occurredAt: DateTime(2026, 7, 17, 8, 30),
        dateOnly: false,
        bristolType: 3,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      );

      final json = record.toJson();
      final occurredAtString = json['occurredAt'] as String;

      expect(occurredAtString.endsWith('Z'), isFalse);
      // Round-trips to the exact same wall-clock time, no zone shift.
      expect(
        SyncRecord.fromJson(json).occurredAt,
        DateTime(2026, 7, 17, 8, 30),
      );
    });

    test('createdAt/updatedAt/deletedAt are stored as UTC ISO strings', () {
      final record = SyncRecord(
        id: 'x',
        occurredAt: DateTime(2026, 7, 17, 8, 30),
        dateOnly: false,
        bristolType: 3,
        createdAt: DateTime.utc(2026, 7, 17, 1),
        updatedAt: DateTime.utc(2026, 7, 17, 2),
        deletedAt: DateTime.utc(2026, 7, 17, 3),
      );

      final json = record.toJson();

      expect((json['createdAt'] as String).endsWith('Z'), isTrue);
      expect((json['updatedAt'] as String).endsWith('Z'), isTrue);
      expect((json['deletedAt'] as String).endsWith('Z'), isTrue);
    });
  });

  group('SyncSnapshot JSON round-trip', () {
    test('round-trips version, generatedAt, and records', () {
      final snapshot = SyncSnapshot(
        version: 1,
        generatedAt: DateTime.utc(2026, 7, 17, 12),
        records: [
          SyncRecord(
            id: 'r1',
            occurredAt: DateTime(2026, 7, 1, 9),
            dateOnly: false,
            bristolType: 4,
            createdAt: DateTime.utc(2026, 7, 1, 9),
            updatedAt: DateTime.utc(2026, 7, 1, 9),
          ),
          SyncRecord(
            id: 'r2',
            occurredAt: DateTime(2026, 7, 2, 10),
            dateOnly: true,
            bristolType: 6,
            createdAt: DateTime.utc(2026, 7, 2, 10),
            updatedAt: DateTime.utc(2026, 7, 3, 10),
            deletedAt: DateTime.utc(2026, 7, 4, 10),
          ),
        ],
      );

      final restored = SyncSnapshot.fromJson(snapshot.toJson());

      expect(restored.version, snapshot.version);
      expect(restored.generatedAt, snapshot.generatedAt);
      expect(restored.records.length, 2);
      expect(restored.records[0].id, 'r1');
      expect(restored.records[1].id, 'r2');
      expect(restored.records[1].deletedAt, snapshot.records[1].deletedAt);
    });

    test('fromJson rejects a version newer than supported', () {
      final json = {
        'version': 2,
        'generatedAt': DateTime.utc(2026, 7, 17).toIso8601String(),
        'records': <dynamic>[],
      };

      expect(
        () => SyncSnapshot.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Please update the app'),
          ),
        ),
      );
    });

    test('fromJson accepts the current version', () {
      final json = {
        'version': 1,
        'generatedAt': DateTime.utc(2026, 7, 17).toIso8601String(),
        'records': <dynamic>[],
      };

      final snapshot = SyncSnapshot.fromJson(json);
      expect(snapshot.version, 1);
      expect(snapshot.records, isEmpty);
    });
  });

  group('SyncRecord <-> BowelMovement conversion', () {
    test('round-trips a fully populated BowelMovement', () {
      final bm = BowelMovement(
        id: 'bm-1',
        occurredAt: DateTime(2026, 7, 17, 8, 30),
        dateOnly: false,
        bristolType: BristolType.type5,
        size: StoolSize.large,
        color: StoolColor.green,
        urgency: 4,
        strain: 1,
        blood: true,
        note: 'note here',
        createdAt: DateTime.utc(2026, 7, 17, 8, 31),
        updatedAt: DateTime.utc(2026, 7, 17, 8, 32),
        deletedAt: DateTime.utc(2026, 7, 18),
      );

      final restored = SyncRecord.fromBowelMovement(bm).toBowelMovement();

      expect(restored, bm);
    });

    test('round-trips a minimal BowelMovement with nullable fields unset',
        () {
      final bm = BowelMovement(
        id: 'bm-2',
        occurredAt: DateTime(2026, 1, 1),
        dateOnly: true,
        bristolType: BristolType.type1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final restored = SyncRecord.fromBowelMovement(bm).toBowelMovement();

      expect(restored, bm);
    });
  });
}
