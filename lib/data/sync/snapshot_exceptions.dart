/// Exception thrown when a snapshot write fails due to an etag mismatch,
/// indicating a concurrent modification (lost-update scenario).
class SnapshotConflictException implements Exception {
  const SnapshotConflictException({
    required this.localEtag,
    required this.remoteEtag,
  });

  /// The etag the caller expected to match.
  final String? localEtag;

  /// The actual etag on the remote (if known).
  final String? remoteEtag;

  @override
  String toString() =>
      'SnapshotConflictException: etag mismatch '
      '(local: $localEtag, remote: $remoteEtag)';
}

/// Exception wrapping network or Google Drive API errors during snapshot
/// operations.
class SnapshotNetworkException implements Exception {
  const SnapshotNetworkException(this.message, {this.cause});

  final String message;

  /// The original exception, if available.
  final Object? cause;

  @override
  String toString() =>
      'SnapshotNetworkException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
