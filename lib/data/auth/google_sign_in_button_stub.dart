import 'package:flutter/widgets.dart';

/// Stub for non-web platforms. Returns null since mobile uses authenticate().
Widget? buildWebSignInButton() => null;

/// Whether the current platform requires the rendered GIS button for sign-in.
bool get isWebSignIn => false;
