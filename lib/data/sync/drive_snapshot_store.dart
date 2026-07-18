/// Abstract interface for reading and writing sync snapshots to a remote store
/// (e.g. Google Drive appDataFolder).
///
/// The store operates on raw JSON maps -- it does not parse or validate the
/// snapshot content. Parsing is the caller's responsibility.
abstract class DriveSnapshotStore {
  /// Reads the current snapshot from the remote store.
  ///
  /// Returns a record of `(json, etag)`:
  /// - `json` is the parsed JSON content, or `null` if no snapshot exists.
  /// - `etag` is the version tag for conflict detection, or `null` if no
  ///   snapshot exists.
  Future<(Map<String, dynamic>?, String?)> readSnapshot();

  /// Writes a snapshot to the remote store.
  ///
  /// If [ifMatch] is provided, the write only succeeds when the remote etag
  /// matches. On mismatch, throws a [SnapshotConflictException] so the caller
  /// can re-read and merge.
  ///
  /// When [ifMatch] is `null`, the write is unconditional (create-or-overwrite).
  ///
  /// Returns the new etag after a successful write.
  Future<String> writeSnapshot(
    Map<String, dynamic> json, {
    String? ifMatch,
  });

  /// Deletes the snapshot from the remote store.
  ///
  /// No-op if no snapshot exists. After deletion, [readSnapshot] returns
  /// `(null, null)`.
  Future<void> deleteSnapshot();
}
