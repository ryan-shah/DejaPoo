import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:dejapoo/ui/widgets/bristol_icon.dart';
import 'package:flutter/material.dart';

/// A horizontally scrollable row of tappable Bristol Stool Chart type
/// circles, following the Huckleberry-style icon picker pattern.
class BristolTypeSelector extends StatelessWidget {
  const BristolTypeSelector({
    super.key,
    this.selectedType,
    this.onTypeSelected,
  });

  /// The currently selected type, if any.
  final BristolType? selectedType;

  /// Called with the tapped type when the user selects one.
  final ValueChanged<BristolType>? onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: IconSizes.bristolCircle + Spacing.lg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        itemCount: BristolType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: Spacing.md),
        itemBuilder: (context, index) {
          final BristolType type = BristolType.values[index];
          final bool selected = type == selectedType;
          return _BristolTypeOption(
            type: type,
            selected: selected,
            onTap: () => onTypeSelected?.call(type),
          );
        },
      ),
    );
  }
}

class _BristolTypeOption extends StatelessWidget {
  const _BristolTypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BristolType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color borderColor = selected ? colors.primary : colors.outlineVariant;
    final Color backgroundColor =
        selected ? colors.primaryContainer : colors.surfaceContainer;
    final Color iconColor = selected ? colors.primary : colors.onSurfaceVariant;

    return Semantics(
      label: 'Bristol type ${type.number}: ${type.label}',
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: IconSizes.bristolCircle,
              height: IconSizes.bristolCircle,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2.0 : 1.0,
                ),
              ),
              child: Center(
                child: BristolIcon(type: type, color: iconColor),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Type ${type.number}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
