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
    r'2182ed86d895fe240acd43126189a2e2bde26941';

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
/// Activated by `ScaffoldWithNavBar`, the app shell widget, which watches it
/// for the lifetime of the app.

@ProviderFor(syncTrigger)
final syncTriggerProvider = SyncTriggerProvider._();

/// Triggers an initial sync on app open when the user is driveAuthorized.
///
/// Activated by `ScaffoldWithNavBar`, the app shell widget, which watches it
/// for the lifetime of the app.

final class SyncTriggerProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Triggers an initial sync on app open when the user is driveAuthorized.
  ///
  /// Activated by `ScaffoldWithNavBar`, the app shell widget, which watches it
  /// for the lifetime of the app.
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

String _$syncTriggerHash() => r'0ea8045d197790e7f4f1e989a7c0cb2f3693fcde';
