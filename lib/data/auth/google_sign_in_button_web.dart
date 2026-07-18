import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Returns the Google Identity Services rendered sign-in button for web.
Widget? buildWebSignInButton() {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.signinWith,
      shape: web.GSIButtonShape.rectangular,
    ),
  );
}

/// Whether the current platform requires the rendered GIS button for sign-in.
bool get isWebSignIn => true;
