import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/ui/widgets/bristol_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSelector(
    WidgetTester tester, {
    BristolType? selectedType,
    ValueChanged<BristolType>? onTypeSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BristolTypeSelector(
            selectedType: selectedType,
            onTypeSelected: onTypeSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('each Bristol type circle announces its number and description',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await pumpSelector(tester);

    for (final BristolType type in BristolType.values) {
      expect(
        find.bySemanticsLabel('Bristol type ${type.number}: ${type.label}'),
        findsOneWidget,
        reason: 'Expected a semantics node for ${type.name}',
      );
    }

    handle.dispose();
  });

  testWidgets('selected type is announced as selected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await pumpSelector(tester, selectedType: BristolType.type4);

    final Finder selectedFinder = find.bySemanticsLabel(
      'Bristol type 4: ${BristolType.type4.label}',
    );
    expect(selectedFinder, findsOneWidget);

    final SemanticsNode selectedNode = tester.getSemantics(selectedFinder);
    // ignore: deprecated_member_use
    expect(selectedNode.hasFlag(SemanticsFlag.isSelected), isTrue);
    // ignore: deprecated_member_use
    expect(selectedNode.hasFlag(SemanticsFlag.isButton), isTrue);

    final Finder notSelectedFinder = find.bySemanticsLabel(
      'Bristol type 1: ${BristolType.type1.label}',
    );
    final SemanticsNode notSelectedNode = tester.getSemantics(
      notSelectedFinder,
    );
    // ignore: deprecated_member_use
    expect(notSelectedNode.hasFlag(SemanticsFlag.isSelected), isFalse);

    handle.dispose();
  });

  testWidgets('tapping a circle invokes onTypeSelected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    BristolType? tapped;

    await pumpSelector(
      tester,
      onTypeSelected: (BristolType type) => tapped = type,
    );

    await tester.tap(find.bySemanticsLabel('Bristol type 3: Sausage with cracks'));
    await tester.pump();

    expect(tapped, BristolType.type3);

    handle.dispose();
  });
}
