/// The observed color of a bowel movement.
///
/// Do not reorder values: they are persisted by index.
enum StoolColor {
  brown('Brown'),
  darkBrown('Dark brown'),
  tan('Tan'),
  yellow('Yellow'),
  green('Green'),
  red('Red'),
  black('Black');

  const StoolColor(this.label);

  /// A short human-readable description of the color.
  final String label;
}
