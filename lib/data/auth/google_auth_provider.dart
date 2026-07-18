import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
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

/// Scopes needed for Drive sync and export upload.
const List<String> _driveScopes = <String>[
  DriveApi.driveAppdataScope,
  DriveApi.driveFileScope,
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
    GoogleSignIn.instance.initialize().then((_) {
      // Attempt lightweight (silent) authentication for returning users.
      GoogleSignIn.instance.attemptLightweightAuthentication();

      // Listen for auth events.
      GoogleSignIn.instance.authenticationEvents.listen(
        _handleAuthEvent,
        // ignore errors — the stream never errors in practice
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
