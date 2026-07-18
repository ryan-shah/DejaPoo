// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-wide [SyncService], wired to the real Drive snapshot store
/// when the user is authorized.
///
/// Returns `null` when the user is not driveAuthorized (no auth client
/// available).

@ProviderFor(SyncServiceNotifier)
final syncServiceProvider = SyncServiceNotifierProvider._();

/// The app-wide [SyncService], wired to the real Drive snapshot store
/// when the user is authorized.
///
/// Returns `null` when the user is not driveAuthorized (no auth client
/// available).
final class SyncServiceNotifierProvider
    extends $NotifierProvider<SyncServiceNotifier, SyncState> {
  /// The app-wide [SyncService], wired to the real Drive snapshot store
  /// when the user is authorized.
  ///
  /// Returns `null` when the user is not driveAuthorized (no auth client
  /// available).
  SyncServiceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServiceNotifierHash();

  @$internal
  @override
  SyncServiceNotifier create() => SyncServiceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncServiceNotifierHash() =>
    r'20b10913fa78fb3919944f6a072bb2e2edbb62a9';

/// The app-wide [SyncService], wired to the real Drive snapshot store
/// when the user is authorized.
///
/// Returns `null` when the user is not driveAuthorized (no auth client
/// available).

abstract class _$SyncServiceNotifier extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Triggers an initial sync on app open when the user is driveAuthorized.
///
/// Watch this provider from a top-level widget to activate it.

@ProviderFor(syncTrigger)
final syncTriggerProvider = SyncTriggerProvider._();

/// Triggers an initial sync on app open when the user is driveAuthorized.
///
/// Watch this provider from a top-level widget to activate it.

final class SyncTriggerProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Triggers an initial sync on app open when the user is driveAuthorized.
  ///
  /// Watch this provider from a top-level widget to activate it.
  SyncTriggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncTriggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncTriggerHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return syncTrigger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$syncTriggerHash() => r'61ab9e20f05b33aac703455f6278f6d87bb51a5a';
