import 'dart:convert';

import 'package:dejapoo/data/sync/drive_snapshot_store.dart';
import 'package:dejapoo/data/sync/snapshot_exceptions.dart';

/// In-memory fake of [DriveSnapshotStore] for testing.
///
/// Stores a single snapshot with an auto-incrementing etag. Supports injecting
/// conflict and network failure modes to exercise error paths.
class InMemoryDriveSnapshotStore implements DriveSnapshotStore {
  /// The stored snapshot JSON (deep-copied on read/write to prevent aliasing).
  Map<String, dynamic>? _snapshot;

  /// Current etag, auto-incremented on each write.
  String? _etag;

  int _nextEtag = 1;

  /// How many times [writeSnapshot] has been called successfully.
  int writeCount = 0;

  /// When `true`, the next [writeSnapshot] with a non-null [ifMatch] will
  /// throw [SnapshotConflictException] regardless of the actual etag.
  /// Resets to `false` after firing.
  bool forceConflictOnNextWrite = false;

  /// When `true`, the next [readSnapshot] or [writeSnapshot] call will throw
  /// [SnapshotNetworkException]. Resets to `false` after firing.
  bool forceNetworkFailureOnNextOperation = false;

  /// The currently stored snapshot (read-only view for test assertions).
  Map<String, dynamic>? get storedSnapshot => _snapshot;

  /// The current etag (read-only view for test assertions).
  String? get currentEtag => _etag;

  @override
  Future<(Map<String, dynamic>?, String?)> readSnapshot() async {
    if (forceNetworkFailureOnNextOperation) {
      forceNetworkFailureOnNextOperation = false;
      throw const SnapshotNetworkException('Simulated network failure');
    }
    if (_snapshot == null) {
      return (null, null);
    }
    // Deep-copy to prevent test code from mutating internal state.
    final copy =
        jsonDecode(jsonEncode(_snapshot)) as Map<String, dynamic>;
    return (copy, _etag);
  }

  @override
  Future<String> writeSnapshot(
    Map<String, dynamic> json, {
    String? ifMatch,
  }) async {
    if (forceNetworkFailureOnNextOperation) {
      forceNetworkFailureOnNextOperation = false;
      throw const SnapshotNetworkException('Simulated network failure');
    }
    if (forceConflictOnNextWrite && ifMatch != null) {
      forceConflictOnNextWrite = false;
      throw SnapshotConflictException(
        localEtag: ifMatch,
        remoteEtag: _etag,
      );
    }
    if (ifMatch != null && _etag != null && ifMatch != _etag) {
      throw SnapshotConflictException(
        localEtag: ifMatch,
        remoteEtag: _etag,
      );
    }
    // Deep-copy to prevent test code from mutating internal state.
    _snapshot = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    _etag = 'etag-${_nextEtag++}';
    writeCount++;
    return _etag!;
  }

  @override
  Future<void> deleteSnapshot() async {
    if (forceNetworkFailureOnNextOperation) {
      forceNetworkFailureOnNextOperation = false;
      throw const SnapshotNetworkException('Simulated network failure');
    }
    _snapshot = null;
    _etag = null;
  }

  /// Resets the store to its initial empty state.
  void reset() {
    _snapshot = null;
    _etag = null;
    _nextEtag = 1;
    writeCount = 0;
    forceConflictOnNextWrite = false;
    forceNetworkFailureOnNextOperation = false;
  }
}
