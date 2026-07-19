// Generates the master app icon assets used by flutter_launcher_icons /
// flutter_native_splash, since we have no designer-made artwork yet.
//
// Draws a simple, recognizable mark in the app's sage palette: a stack of
// three rounded "log" shapes echoing the Bristol Stool Chart iconography
// already used in assets/icons/bristol_type_*.svg (type 4, the healthy
// reference shape, is a single rounded capsule).
//
// Run with: dart run tool/generate_icon.dart
//
// Outputs:
//   assets/icon/app_icon.png            1024x1024, sage background + mark
//   assets/icon/app_icon_foreground.png 1024x1024, transparent bg, mark only
//     (sized to Android's adaptive-icon safe zone, ~66% of canvas centered)
import 'dart:io';

import 'package:image/image.dart' as img;

// Sage palette (see designs/DESIGN.md).
const _bg = 0xFF6FAE8D; // adaptive_icon_background
const _fg = 0xFFFAFAF7; // near-white mark, matches splash background
const _accent = 0xFF3E6B48; // dark sage accent

img.Color _c(int argb) => img.ColorRgba8(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (argb >> 24) & 0xFF,
    );

/// Draws a horizontal rounded capsule (stadium shape) centered at [cx],[cy].
void _drawCapsule(
  img.Image image, {
  required double cx,
  required double cy,
  required double length,
  required double thickness,
  required img.Color color,
}) {
  final halfLen = length / 2;
  final r = thickness / 2;
  // Rectangle body.
  img.fillRect(
    image,
    x1: (cx - halfLen + r).round(),
    y1: (cy - r).round(),
    x2: (cx + halfLen - r).round(),
    y2: (cy + r).round(),
    color: color,
  );
  // Rounded end caps.
  img.fillCircle(
    image,
    x: (cx - halfLen + r).round(),
    y: cy.round(),
    radius: r.round(),
    color: color,
  );
  img.fillCircle(
    image,
    x: (cx + halfLen - r).round(),
    y: cy.round(),
    radius: r.round(),
    color: color,
  );
}

void _drawMark(img.Image image, {required double scale, required double centerY}) {
  // Three stacked capsules, slightly offset, evoking a coiled Bristol type 4
  // shape without depicting anything literal.
  final thickness = 150.0 * scale;
  final gap = 24.0 * scale;
  final lengths = [560.0 * scale, 620.0 * scale, 480.0 * scale];
  final offsets = [-60.0 * scale, 40.0 * scale, -20.0 * scale];
  final rowHeight = thickness + gap;
  final totalHeight = rowHeight * lengths.length - gap;
  final top = centerY - totalHeight / 2 + thickness / 2;

  for (var i = 0; i < lengths.length; i++) {
    _drawCapsule(
      image,
      cx: 512.0 + offsets[i],
      cy: top + rowHeight * i,
      length: lengths[i],
      thickness: thickness,
      color: i == 1 ? _c(_accent) : _c(_fg),
    );
  }
}

void main() {
  const size = 1024;

  // 1. Full icon: sage background + mark (used for android/ios/web icons and
  //    as the splash image).
  final full = img.Image(width: size, height: size, numChannels: 4);
  img.fill(full, color: _c(_bg));
  _drawMark(full, scale: 1.0, centerY: 512);
  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(full));

  // 2. Foreground-only layer for Android adaptive icons: transparent
  //    background, mark scaled down to fit the ~66% safe zone so it isn't
  //    clipped by launcher icon masks.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  _drawMark(fg, scale: 0.62, centerY: 512);
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/app_icon.png and app_icon_foreground.png');
}
