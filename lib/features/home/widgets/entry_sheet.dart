import 'package:dejapoo/data/providers.dart';
import 'package:dejapoo/data/sync/sync_providers.dart';
import 'package:dejapoo/domain/domain.dart';
import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:dejapoo/ui/widgets/bristol_icon.dart';
import 'package:dejapoo/ui/widgets/bristol_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the add/edit entry bottom sheet.
///
/// In **create mode** (no [existing] passed), all optional fields default to
/// null and date/time default to now. In **edit mode**, all fields are
/// prefilled from the existing [BowelMovement].
Future<void> showEntrySheet(
  BuildContext context, {
  BowelMovement? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => EntrySheet(existing: existing),
  );
}

/// A modal bottom sheet form for creating or editing a bowel movement entry.
class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({super.key, this.existing});

  /// When non-null the sheet opens in edit mode with prefilled values.
  final BowelMovement? existing;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  BristolType? _bristolType;
  late DateTime _date;
  late TimeOfDay _time;
  StoolSize? _size;
  StoolColor? _color;
  int? _urgency;
  int? _strain;
  bool? _blood;
  late TextEditingController _noteController;
  bool _saving = false;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final BowelMovement? existing = widget.existing;
    if (existing != null) {
      _bristolType = existing.bristolType;
      _date = DateTime(
        existing.occurredAt.year,
        existing.occurredAt.month,
        existing.occurredAt.day,
      );
      _time = TimeOfDay(
        hour: existing.occurredAt.hour,
        minute: existing.occurredAt.minute,
      );
      _size = existing.size;
      _color = existing.color;
      _urgency = existing.urgency;
      _strain = existing.strain;
      _blood = existing.blood;
      _noteController = TextEditingController(text: existing.note ?? '');
    } else {
      final DateTime now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _time = TimeOfDay(hour: now.hour, minute: now.minute);
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
      });
    }
  }

  DateTime get _occurredAt => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _save() async {
    if (_bristolType == null || _saving) return;
    setState(() {
      _saving = true;
    });

    final BowelMovementRepository repo =
        ref.read(bowelMovementRepositoryProvider);
    final String? noteText =
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    try {
      if (_isEditMode) {
        await repo.update(
          widget.existing!.copyWith(
            occurredAt: _occurredAt,
            bristolType: _bristolType,
            size: _size,
            color: _color,
            urgency: _urgency,
            strain: _strain,
            blood: _blood,
            note: noteText,
          ),
        );
      } else {
        await repo.create(
          occurredAt: _occurredAt,
          bristolType: _bristolType!,
          size: _size,
          color: _color,
          urgency: _urgency,
          strain: _strain,
          blood: _blood,
          note: noteText,
        );
      }
      ref.read(syncServiceProvider.notifier).scheduleDebouncedSync();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Title
              Text(
                _isEditMode ? 'Edit Entry' : 'New Entry',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.lg),

              // Bristol type selector
              _SectionLabelWithHelp(
                label: 'Bristol Type',
                onHelp: () => _showBristolTypeHelp(context),
              ),
              const SizedBox(height: Spacing.sm),
              BristolTypeSelector(
                selectedType: _bristolType,
                onTypeSelected: (BristolType type) {
                  setState(() {
                    _bristolType = type;
                  });
                },
              ),
              const SizedBox(height: Spacing.lg),

              // Date and time pickers
              const _SectionLabel(label: 'Date & Time'),
              const SizedBox(height: Spacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateTimeTile(
                      icon: Icons.calendar_today,
                      label: _formatDate(_date),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: _DateTimeTile(
                      icon: Icons.access_time,
                      label: _time.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),

              // Size chips
              const _SectionLabel(label: 'Size'),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                children: StoolSize.values.map((StoolSize s) {
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: _size == s,
                    onSelected: (bool selected) {
                      setState(() {
                        _size = selected ? s : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.lg),

              // Color swatches
              const _SectionLabel(label: 'Color'),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                children: StoolColor.values.map((StoolColor c) {
                  return ChoiceChip(
                    label: Text(c.label),
                    selected: _color == c,
                    onSelected: (bool selected) {
                      setState(() {
                        _color = selected ? c : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.lg),

              // Urgency selector (1-5)
              const _SectionLabel(label: 'Urgency'),
              const SizedBox(height: Spacing.sm),
              _ScaleSelector(
                value: _urgency,
                onChanged: (int? value) {
                  setState(() {
                    _urgency = value;
                  });
                },
              ),
              const SizedBox(height: Spacing.lg),

              // Strain selector (1-5)
              const _SectionLabel(label: 'Strain'),
              const SizedBox(height: Spacing.sm),
              _ScaleSelector(
                value: _strain,
                onChanged: (int? value) {
                  setState(() {
                    _strain = value;
                  });
                },
              ),
              const SizedBox(height: Spacing.lg),

              // Blood toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Blood', style: theme.textTheme.titleSmall),
                  Switch(
                    value: _blood ?? false,
                    onChanged: (bool value) {
                      setState(() {
                        _blood = value ? true : null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),

              // Note text field
              const _SectionLabel(label: 'Note'),
              const SizedBox(height: Spacing.sm),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'Optional note...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: Spacing.xl),

              // Save button
              FilledButton(
                onPressed: _bristolType != null && !_saving ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Spacing.xxl),
                ),
                child: Text(_saving
                    ? 'Saving...'
                    : _isEditMode
                        ? 'Update'
                        : 'Save'),
              ),
              const SizedBox(height: Spacing.md),
            ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    // Simple date formatting without intl package
    final List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// A small section label for form groups.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

/// A section label with a trailing help icon button.
class _SectionLabelWithHelp extends StatelessWidget {
  const _SectionLabelWithHelp({
    required this.label,
    required this.onHelp,
  });

  final String label;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: Spacing.xs),
        GestureDetector(
          onTap: onHelp,
          child: Icon(
            Icons.help_outline,
            size: IconSizes.navIcon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

const Map<BristolType, String> _bristolDescriptions = <BristolType, String>{
  BristolType.type1:
      'Hard, separate lumps that are difficult to pass. May indicate constipation.',
  BristolType.type2:
      'Sausage-shaped but lumpy. Slightly constipated.',
  BristolType.type3:
      'Sausage-shaped with cracks on the surface. Considered normal.',
  BristolType.type4:
      'Smooth, soft sausage or snake. The ideal stool.',
  BristolType.type5:
      'Soft blobs with clear-cut edges, passed easily. Tending toward diarrhea.',
  BristolType.type6:
      'Fluffy, mushy pieces with ragged edges. Mild diarrhea.',
  BristolType.type7:
      'Entirely liquid with no solid pieces. Diarrhea.',
};

void _showBristolTypeHelp(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final ColorScheme colors = theme.colorScheme;

  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Bristol Stool Chart'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: BristolType.values.length,
            separatorBuilder: (_, _) => const Divider(height: Spacing.lg),
            itemBuilder: (BuildContext context, int index) {
              final BristolType type = BristolType.values[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  BristolIcon(
                    type: type,
                    size: 32,
                    color: colors.onSurface,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Type ${type.number} — ${type.label}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bristolDescriptions[type]!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

/// A tappable tile showing an icon and a label, used for date/time pickers.
class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: IconSizes.navIcon, color: colors.onSurfaceVariant),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of 1-5 choice chips for urgency/strain scales.
class _ScaleSelector extends StatelessWidget {
  const _ScaleSelector({
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      children: List<Widget>.generate(5, (int index) {
        final int scaleValue = index + 1;
        return ChoiceChip(
          label: Text('$scaleValue'),
          selected: value == scaleValue,
          onSelected: (bool selected) {
            onChanged(selected ? scaleValue : null);
          },
        );
      }),
    );
  }
}
