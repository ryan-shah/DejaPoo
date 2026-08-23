/// Stub implementation — non-web platforms are never "an Android browser".
///
/// The native Android build is the thing we would be advertising, so there is
/// nothing to prompt for here.
bool get isAndroidWebBrowser => false;
