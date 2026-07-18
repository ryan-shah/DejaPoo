import 'package:dejapoo/data/import/import_expander.dart';
import 'package:dejapoo/data/import/import_models.dart';
import 'package:dejapoo/domain/bristol_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ImportExpander expander;

  setUp(() {
    expander = ImportExpander();
  });

  test('empty input produces empty output', () {
    final (movements, issues) = expander.expand([]);
    expect(movements, isEmpty);
    expect(issues, isEmpty);
  });

  test('single day, single type, count=1 produces one movement with correct id', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {3: 1}),
    ];
    final (movements, issues) = expander.expand(rows);
    expect(issues, isEmpty);
    expect(movements, hasLength(1));
    expect(movements.single.id, 'imp-2024-01-15-t3-1');
    expect(movements.single.bristolType, BristolType.type3);
  });

  test('single day, single type, count>1 produces sequential ids', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {3: 2}),
    ];
    final (movements, issues) = expander.expand(rows);
    expect(issues, isEmpty);
    expect(movements, hasLength(2));
    expect(movements.map((m) => m.id), [
      'imp-2024-01-15-t3-1',
      'imp-2024-01-15-t3-2',
    ]);
  });

  test('single day, multiple types produces correct movements and ids', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {1: 1, 4: 2}),
    ];
    final (movements, issues) = expander.expand(rows);
    expect(issues, isEmpty);
    // Type order is ascending 1..7.
    expect(movements.map((m) => m.id), [
      'imp-2024-01-15-t1-1',
      'imp-2024-01-15-t4-1',
      'imp-2024-01-15-t4-2',
    ]);
    expect(movements[0].bristolType, BristolType.type1);
    expect(movements[1].bristolType, BristolType.type4);
    expect(movements[2].bristolType, BristolType.type4);
  });

  test('multiple days are ordered by date', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 1, 20), typeCounts: {2: 1}),
      DailyCounts(date: DateTime(2024, 1, 10), typeCounts: {2: 1}),
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {2: 1}),
    ];
    final (movements, issues) = expander.expand(rows);
    expect(issues, isEmpty);
    expect(movements.map((m) => m.id), [
      'imp-2024-01-10-t2-1',
      'imp-2024-01-15-t2-1',
      'imp-2024-01-20-t2-1',
    ]);
  });

  test('duplicate dates are merged and a warning is issued', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {3: 1}),
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {3: 1, 5: 1}),
    ];
    final (movements, issues) = expander.expand(rows);
    expect(issues, hasLength(1));
    expect(issues.single.severity, ImportIssueSeverity.warning);
    expect(issues.single.message, contains('2024-01-15'));
    // Merged: type3 count=2, type5 count=1 -> 3 movements, no id collisions.
    expect(movements.map((m) => m.id).toSet(), {
      'imp-2024-01-15-t3-1',
      'imp-2024-01-15-t3-2',
      'imp-2024-01-15-t5-1',
    });
    expect(movements, hasLength(3));
  });

  test('zero-count types produce no movements', () {
    final rows = [
      DailyCounts(
        date: DateTime(2024, 1, 15),
        typeCounts: {1: 0, 2: 0, 3: 1},
      ),
    ];
    final (movements, issues) = expander.expand(rows);
    expect(issues, isEmpty);
    expect(movements, hasLength(1));
    expect(movements.single.id, 'imp-2024-01-15-t3-1');
  });

  test('all movements have dateOnly=true and occurredAt at noon local', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 1, 15), typeCounts: {1: 1, 7: 1}),
    ];
    final (movements, _) = expander.expand(rows);
    for (final m in movements) {
      expect(m.dateOnly, isTrue);
      expect(m.occurredAt, DateTime(2024, 1, 15, 12));
      expect(m.occurredAt.isUtc, isFalse);
    }
  });

  test('id format matches imp-yyyy-MM-dd-tN-k', () {
    final rows = [
      DailyCounts(date: DateTime(2024, 3, 5), typeCounts: {6: 1}),
    ];
    final (movements, _) = expander.expand(rows);
    expect(
      movements.single.id,
      matches(RegExp(r'^imp-\d{4}-\d{2}-\d{2}-t\d-\d+$')),
    );
    expect(movements.single.id, 'imp-2024-03-05-t6-1');
  });
}
