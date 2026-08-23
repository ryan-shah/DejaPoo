// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Whether the page is being viewed in a browser running on Android.
///
/// True only when the user agent identifies Android *and* the document is not
/// already running as an installed PWA: `display-mode: standalone` means the
/// user has added the web app to their home screen, and nagging them to
/// install the APK on top of that would be noise.
bool get isAndroidWebBrowser {
  final String userAgent = web.window.navigator.userAgent;
  if (!userAgent.contains('Android')) return false;
  if (web.window.matchMedia('(display-mode: standalone)').matches) {
    return false;
  }
  return true;
}
