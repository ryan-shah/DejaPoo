/// The approximate size of a bowel movement.
///
/// Do not reorder values: they are persisted by index.
enum StoolSize {
  small('Small'),
  medium('Medium'),
  large('Large');

  const StoolSize(this.label);

  /// A short human-readable description of the size.
  final String label;
}
