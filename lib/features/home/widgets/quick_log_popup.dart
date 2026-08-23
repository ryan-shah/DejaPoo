import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:dejapoo/ui/widgets/bristol_icon.dart';
import 'package:flutter/material.dart';

/// Shows a compact popup with the 7 Bristol type icons for quick logging.
///
/// Returns the selected [BristolType], or null if dismissed without selection.
Future<BristolType?> showQuickLogPopup(BuildContext context) {
  return showDialog<BristolType>(
    context: context,
    barrierColor: Colors.black26,
    builder: (BuildContext context) => const _QuickLogPopup(),
  );
}

class _QuickLogPopup extends StatelessWidget {
  const _QuickLogPopup();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 88, // above the FAB
          left: Spacing.md,
          right: Spacing.md,
        ),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(Radii.lg),
          color: colors.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Quick log',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: BristolType.values.map((BristolType type) {
                    return Semantics(
                      label:
                          'Log Bristol type ${type.number}: ${type.label}',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: () => Navigator.of(context).pop(type),
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.xs),
                          child: BristolIcon(
                            type: type,
                            size: 36,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
