import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
}

/// Renders the icon for a [BristolType], tinted with [color].
class BristolIcon extends StatelessWidget {
  const BristolIcon({
    required this.type,
    super.key,
    this.size = IconSizes.bristolIcon,
    this.color,
  });

  /// Which Bristol Stool Chart type to render.
  final BristolType type;

  /// The rendered size (width and height) of the icon.
  final double size;

  /// The tint color applied to the icon. Defaults to the theme's
  /// `onSurface` color when not provided.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'Bristol type ${type.number}: ${type.label}',
      child: SvgPicture.asset(
        type.assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}
