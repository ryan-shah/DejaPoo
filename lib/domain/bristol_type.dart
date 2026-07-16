/// The seven categories of the Bristol Stool Chart.
enum BristolType {
  type1(1, 'Separate hard lumps'),
  type2(2, 'Lumpy sausage'),
  type3(3, 'Sausage with cracks'),
  type4(4, 'Smooth sausage'),
  type5(5, 'Soft blobs'),
  type6(6, 'Fluffy, mushy'),
  type7(7, 'Liquid');

  const BristolType(this.number, this.label);

  /// The Bristol Stool Chart type number (1-7).
  final int number;

  /// A short human-readable description of the type.
  final String label;

  /// The asset path of this type's icon.
  String get assetPath => 'assets/icons/bristol_type_$number.svg';

  /// Looks up the type for a Bristol Stool Chart [number] (1-7).
  static BristolType fromNumber(int number) {
    assert(number >= 1 && number <= 7, 'Bristol type must be 1-7');
    return values[number - 1];
  }
}
