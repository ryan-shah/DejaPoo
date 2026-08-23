import 'package:dejapoo/ui/widgets/install_prompt/android_web_detect_stub.dart'
    if (dart.library.js_interop)
        'package:dejapoo/ui/widgets/install_prompt/android_web_detect_web.dart'
    as impl;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'android_web_detect.g.dart';

/// Whether the app is being viewed in a browser running on Android.
///
/// Backed by a conditional import (`android_web_detect_stub.dart` /
/// `android_web_detect_web.dart`) so the `package:web` interop only compiles
/// into the web build. Always `false` off the web.
///
/// The [kIsWeb] guard lives here rather than at the call site so widget tests
/// (which run on the VM, where `kIsWeb` is always false) can exercise the
/// prompt by overriding this provider:
/// `isAndroidWebBrowserProvider.overrideWithValue(true)`.
@riverpod
bool isAndroidWebBrowser(Ref ref) => kIsWeb && impl.isAndroidWebBrowser;
