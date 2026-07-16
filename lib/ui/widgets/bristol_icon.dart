import 'package:dejapoo/domain/bristol_type.dart';
import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

export 'package:dejapoo/domain/bristol_type.dart';

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
