import 'dart:convert';

import 'package:dejapoo/data/sync/sync_models.dart';

/// The result of merging two [SyncRecord] lists.
class MergeResult {
  const MergeResult({
    required this.merged,
    required this.added,
    required this.updated,
  });

  /// The full merged record list (union, conflicts resolved).
  final List<SyncRecord> merged;

  /// Records present in the remote list but not in the local list.
  final List<SyncRecord> added;

  /// Records where the remote version won over an existing local version.
  final List<SyncRecord> updated;

  /// True if remote introduced any new or updated records relative to local.
  bool get hasChanges => added.isNotEmpty || updated.isNotEmpty;
}

/// Pure, deterministic last-write-wins merge engine for [SyncRecord] lists.
class MergeEngine {
  const MergeEngine._();

  /// Merges [local] and [remote] record lists.
  ///
  /// Rules, keyed by record id:
  /// - Newer `updatedAt` (compared in UTC) wins.
  /// - On an exact `updatedAt` tie, a tombstone (`deletedAt != null`) wins.
  /// - On an exact tie with the same tombstone status, the
  ///   lexicographically greater `id` wins (deterministic on both devices).
  static MergeResult merge(List<SyncRecord> local, List<SyncRecord> remote) {
    final byId = <String, SyncRecord>{
      for (final r in local) r.id: r,
    };

    final added = <SyncRecord>[];
    final updated = <SyncRecord>[];

    for (final remoteRecord in remote) {
      final localRecord = byId[remoteRecord.id];
      if (localRecord == null) {
        byId[remoteRecord.id] = remoteRecord;
        added.add(remoteRecord);
        continue;
      }
      final winner = _resolve(localRecord, remoteRecord);
      if (!identical(winner, localRecord)) {
        byId[remoteRecord.id] = winner;
        updated.add(winner);
      }
    }

    return MergeResult(
      merged: byId.values.toList(),
      added: added,
      updated: updated,
    );
  }

  /// Resolves a conflict between two records sharing the same id, returning
  /// whichever one wins per the last-write-wins rules.
  static SyncRecord _resolve(SyncRecord a, SyncRecord b) {
    final aTime = a.updatedAt.toUtc();
    final bTime = b.updatedAt.toUtc();

    if (aTime.isAfter(bTime)) return a;
    if (bTime.isAfter(aTime)) return b;

    // Exact tie on updatedAt: tombstone wins.
    final aTombstone = a.deletedAt != null;
    final bTombstone = b.deletedAt != null;
    if (aTombstone != bTombstone) {
      return aTombstone ? a : b;
    }

    // Exact tie, same tombstone status: fall back to a deterministic,
    // order-independent comparison so both devices converge on the same
    // winner regardless of which copy each device calls "local" vs
    // "remote". Since `a.id == b.id` always holds here (records are keyed
    // by id), the record id itself cannot break the tie; instead compare
    // the full canonical JSON representation of each record — this is the
    // "lexicographically greater" comparison the merge rule refers to,
    // applied to the only content that can actually differ.
    final aCanonical = jsonEncode(a.toJson());
    final bCanonical = jsonEncode(b.toJson());
    if (aCanonical == bCanonical) return a; // truly identical, order-safe
    return aCanonical.compareTo(bCanonical) >= 0 ? a : b;
  }
}
