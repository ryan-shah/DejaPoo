import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' show DriveApi;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'google_auth_provider.g.dart';

/// Authentication status for the Google Drive sync feature.
enum AuthStatus {
  /// Not signed in to any Google account.
  signedOut,

  /// Signed in with basic profile, but no Drive scope authorized.
  signedIn,

  /// Signed in and Drive appdata scope has been authorized.
  driveAuthorized,
}

/// OAuth **web** client ID of the DejaPoo Google Cloud project.
///
/// Android's Credential Manager flow (google_sign_in 7.x) authenticates against
/// the *web* client ID, passed as `serverClientId`; without it `authenticate()`
/// fails with `GoogleSignInExceptionCode.clientConfigurationError`. It is not a
/// secret (the same value is published in `web/index.html`), but it can be
/// overridden per-build with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
///
/// Note this only covers the *server* half of the config. The Cloud project
/// must also hold an **Android** OAuth client for the app's package name and
/// signing-key SHA-1, or sign-in fails with no credentials available. That
/// client's ID is never referenced in code (Android identifies apps by package
/// name + signing SHA-1), so it is recorded here for traceability:
///
///   client:  460206928839-89bupm334i8hqnpmh7muibmr2iekk8pe
///   package: com.dejapoo.dejapoo
///   SHA-1:   1C:E0:5C:A2:93:FF:78:6A:E8:6F:49:F7:CE:57:85:2E:FA:C7:21:78
///            (the local debug keystore; release builds fall back to it until
///            android/key.properties exists, which then needs its own client)
const String _serverClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '460206928839-cvl27ghr2k5nvtml6e5mc82i2v6o3b1l.apps.googleusercontent.com',
);

/// Scopes needed for Drive sync, export upload, and Drive import.
const List<String> _driveScopes = <String>[
  DriveApi.driveAppdataScope,
  DriveApi.driveFileScope,
  DriveApi.driveReadonlyScope,
];

/// Manages Google sign-in state and provides auth clients for googleapis.
///
/// Uses google_sign_in 7.x event-based API:
/// - [GoogleSignIn.initialize] called once (keepAlive provider)
/// - [GoogleSignIn.instance.authenticate] for interactive sign-in
/// - [GoogleSignInAccount.authorizationClient.authorizeScopes] for Drive scope
/// - Listens to [GoogleSignIn.instance.authenticationEvents] for state changes
@Riverpod(keepAlive: true)
class GoogleAuth extends _$GoogleAuth {
  GoogleSignInAccount? _currentUser;
  bool _initialized = false;

  @override
  AuthStatus build() {
    _initializeIfNeeded();
    return AuthStatus.signedOut;
  }

  void _initializeIfNeeded() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    // Initialize the sign-in SDK. This is safe to call even when no OAuth
    // client IDs are configured (it just won't be able to authenticate).
    //
    // `serverClientId` is required on Android and rejected on web (which reads
    // its client ID from the `google-signin-client_id` meta tag instead).
    GoogleSignIn.instance.initialize(
      serverClientId:
          kIsWeb || _serverClientId.isEmpty ? null : _serverClientId,
    ).then((_) {
      // Attempt lightweight (silent) authentication for returning users.
      GoogleSignIn.instance.attemptLightweightAuthentication();

      // Listen for auth events.
      GoogleSignIn.instance.authenticationEvents.listen(
        _handleAuthEvent,
        // `authenticate()` both rethrows and mirrors GoogleSignInException onto
        // this stream, so a listener without onError turns every cancelled
        // sign-in into an unhandled async error. Callers surface the rethrown
        // copy (see _handleSignIn in settings_screen.dart); drop this one.
        onError: (Object _) {},
      );
    }).catchError((_) {
      // Initialization can fail if the platform plugin is not available
      // (e.g., no web client ID configured). Degrade gracefully.
    });
  }

  Future<void> _handleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _currentUser = event.user;
        // Check whether we already have Drive scopes.
        await _refreshAuthStatus();
      case GoogleSignInAuthenticationEventSignOut():
        _currentUser = null;
        state = AuthStatus.signedOut;
    }
  }

  Future<void> _refreshAuthStatus() async {
    if (_currentUser == null) {
      state = AuthStatus.signedOut;
      return;
    }

    // Try to get existing authorization without user interaction.
    try {
      final GoogleSignInClientAuthorization? auth = await _currentUser!
          .authorizationClient
          .authorizationForScopes(_driveScopes);
      if (auth != null) {
        state = AuthStatus.driveAuthorized;
      } else {
        state = AuthStatus.signedIn;
      }
    } catch (_) {
      // If we can't check scopes, assume signed-in but not authorized.
      state = AuthStatus.signedIn;
    }
  }

  /// Starts an interactive sign-in flow.
  ///
  /// After sign-in, [state] moves to [AuthStatus.signedIn] or
  /// [AuthStatus.driveAuthorized] if Drive scopes were previously granted.
  Future<void> signIn() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException {
      // User cancelled or platform error — stay signed out.
      rethrow;
    }
  }

  /// Signs out the current user. [state] moves to [AuthStatus.signedOut].
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _currentUser = null;
    state = AuthStatus.signedOut;
  }

  /// Requests Drive appdata + file scopes from the signed-in user.
  ///
  /// On success, [state] moves to [AuthStatus.driveAuthorized].
  /// Throws [GoogleSignInException] if the user denies or an error occurs.
  Future<void> authorizeDriveScope() async {
    final GoogleSignInAccount? user = _currentUser;
    if (user == null) {
      throw StateError('Cannot authorize Drive scope: not signed in');
    }

    final GoogleSignInClientAuthorization authorization =
        await user.authorizationClient.authorizeScopes(_driveScopes);
    // If we get here without exception, scopes were granted.
    // ignore: unnecessary_null_comparison
    if (authorization != null) {
      state = AuthStatus.driveAuthorized;
    }
  }

  /// Returns an authenticated [gapis.AuthClient] for use with googleapis
  /// (e.g., Drive v3). Returns null if not signed in or not authorized.
  ///
  /// Callers should check [state] == [AuthStatus.driveAuthorized] first.
  Future<gapis.AuthClient?> getAuthClient() async {
    final GoogleSignInAccount? user = _currentUser;
    if (user == null) {
      return null;
    }

    try {
      final GoogleSignInClientAuthorization? auth =
          await user.authorizationClient.authorizationForScopes(_driveScopes);
      if (auth == null) {
        return null;
      }
      return auth.authClient(scopes: _driveScopes);
    } catch (_) {
      return null;
    }
  }

  /// The currently signed-in user, or null.
  GoogleSignInAccount? get currentUser => _currentUser;

  /// The email of the currently signed-in user, or null.
  String? get currentUserEmail => _currentUser?.email;
}
