import 'package:dejapoo/domain/bristol_type.dart';
import 'package:flutter/material.dart';

/// Chart color palette for the seven Bristol Stool Chart types.
///
/// Used for bar segments, donut sections, legend chips, and filter chips.
/// Types 1-2 use warm tones, 3-5 (the "healthy range") use the app's
/// green/teal family, and 6-7 use cool tones. Distinct light and dark
/// variants keep contrast against the app's light (#FAFAF7) and dark
/// (#1A1F1A) surfaces.
abstract final class BristolPalette {
  /// Chart color for [type] on a surface of the given [brightness].
  static Color colorFor(BristolType type, Brightness brightness) {
    return brightness == Brightness.light
        ? _lightColors[type.number - 1]
        : _darkColors[type.number - 1];
  }

  static const List<Color> _lightColors = <Color>[
    Color(0xFF8B6914), // Type 1 - dark gold/brown
    Color(0xFFC4883D), // Type 2 - amber/caramel
    Color(0xFF6FAE8D), // Type 3 - sage green (healthy)
    Color(0xFF4A9B6E), // Type 4 - deeper green (healthy)
    Color(0xFF3E8A8F), // Type 5 - teal (healthy)
    Color(0xFF5B7FC7), // Type 6 - blue
    Color(0xFF8B5EC7), // Type 7 - purple
  ];

  static const List<Color> _darkColors = <Color>[
    Color(0xFFD4A84B), // Type 1
    Color(0xFFE0A85C), // Type 2
    Color(0xFF8FD4AD), // Type 3 (matches dark primary)
    Color(0xFF6BC48E), // Type 4
    Color(0xFF5BBBC0), // Type 5
    Color(0xFF7FA0E0), // Type 6
    Color(0xFFAB82E0), // Type 7
  ];
}
