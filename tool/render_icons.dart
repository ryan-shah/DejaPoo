// Rasterises the SVG icon masters in assets/icon/ to the PNGs that
// flutter_launcher_icons and flutter_native_splash consume.
//
// Full regeneration, in order:
//
//   flutter test tool/render_icons.dart      # masters -> assets/icon/*.png
//   dart run flutter_launcher_icons          # android + ios + web icons
//   dart run flutter_native_splash:create    # splash drawables and styles
//   flutter test tool/render_icons.dart      # re-runs; restores web/favicon.png,
//                                            # which flutter_launcher_icons rewrites at 16x16
//
// The last step is why favicon lives here: flutter_launcher_icons has no favicon
// size option and always emits 16x16, which is visibly mushy on a HiDPI tab strip.
//
// This file sits in tool/ rather than test/ on purpose — `flutter test` only globs
// test/, so an ordinary test run never rewrites committed artwork. It is still driven
// by `flutter test` because rasterising SVG needs a Flutter engine: flutter_svg
// (already a dependency) renders the vector to a ui.Picture, which is drawn to an
// offscreen image. That gives real anti-aliasing and real transforms. The previous
// tool/generate_icon.dart drew with package:image's fillRect/fillCircle, which has
// neither, and so could not express a rotated capsule at all.
//
// The SVGs are the artwork of record. Edit those, re-run, commit both.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Render = ({String svg, String png, int size});

const _renders = <_Render>[
  (svg: 'assets/icon/app_icon.svg', png: 'assets/icon/app_icon.png', size: 1024),
  (
    svg: 'assets/icon/app_icon_foreground.svg',
    png: 'assets/icon/app_icon_foreground.png',
    size: 1024,
  ),
  (
    svg: 'assets/icon/app_icon_monochrome.svg',
    png: 'assets/icon/app_icon_monochrome.png',
    size: 1024,
  ),
  (svg: 'assets/icon/app_splash.svg', png: 'assets/icon/app_splash.png', size: 1024),
  (svg: 'assets/icon/app_icon.svg', png: 'web/favicon.png', size: 64),
];

Future<void> _render(_Render r) async {
  final source = File(r.svg).readAsStringSync();
  final info = await vg.loadPicture(SvgStringLoader(source), null);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(r.size / info.size.width, r.size / info.size.height);
  canvas.drawPicture(info.picture);
  final picture = recorder.endRecording();

  final image = await picture.toImage(r.size, r.size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(r.png).writeAsBytesSync(bytes!.buffer.asUint8List());

  info.picture.dispose();
  picture.dispose();
  image.dispose();
}

void main() {
  testWidgets('rasterise icon masters', (tester) async {
    // runAsync escapes the fake-async zone; toImage needs real async.
    await tester.runAsync(() async {
      for (final r in _renders) {
        await _render(r);
        stdout.writeln('wrote ${r.png} (${r.size}px)');
      }
    });
  });
}
