// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages Google sign-in state and provides auth clients for googleapis.
///
/// Uses google_sign_in 7.x event-based API:
/// - [GoogleSignIn.initialize] called once (keepAlive provider)
/// - [GoogleSignIn.instance.authenticate] for interactive sign-in
/// - [GoogleSignInAccount.authorizationClient.authorizeScopes] for Drive scope
/// - Listens to [GoogleSignIn.instance.authenticationEvents] for state changes

@ProviderFor(GoogleAuth)
final googleAuthProvider = GoogleAuthProvider._();

/// Manages Google sign-in state and provides auth clients for googleapis.
///
/// Uses google_sign_in 7.x event-based API:
/// - [GoogleSignIn.initialize] called once (keepAlive provider)
/// - [GoogleSignIn.instance.authenticate] for interactive sign-in
/// - [GoogleSignInAccount.authorizationClient.authorizeScopes] for Drive scope
/// - Listens to [GoogleSignIn.instance.authenticationEvents] for state changes
final class GoogleAuthProvider
    extends $NotifierProvider<GoogleAuth, AuthStatus> {
  /// Manages Google sign-in state and provides auth clients for googleapis.
  ///
  /// Uses google_sign_in 7.x event-based API:
  /// - [GoogleSignIn.initialize] called once (keepAlive provider)
  /// - [GoogleSignIn.instance.authenticate] for interactive sign-in
  /// - [GoogleSignInAccount.authorizationClient.authorizeScopes] for Drive scope
  /// - Listens to [GoogleSignIn.instance.authenticationEvents] for state changes
  GoogleAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleAuthHash();

  @$internal
  @override
  GoogleAuth create() => GoogleAuth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthStatus>(value),
    );
  }
}

String _$googleAuthHash() => r'1dcfd27c06952b2047122fdbd56c7a6835c20310';

/// Manages Google sign-in state and provides auth clients for googleapis.
///
/// Uses google_sign_in 7.x event-based API:
/// - [GoogleSignIn.initialize] called once (keepAlive provider)
/// - [GoogleSignIn.instance.authenticate] for interactive sign-in
/// - [GoogleSignInAccount.authorizationClient.authorizeScopes] for Drive scope
/// - Listens to [GoogleSignIn.instance.authenticationEvents] for state changes

abstract class _$GoogleAuth extends $Notifier<AuthStatus> {
  AuthStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthStatus, AuthStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthStatus, AuthStatus>,
              AuthStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
