import 'dart:convert';

import 'package:dejapoo/data/sync/drive_snapshot_store.dart';
import 'package:dejapoo/data/sync/snapshot_exceptions.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Google Drive implementation of [DriveSnapshotStore].
///
/// Stores the sync snapshot as a single JSON file in the app-scoped
/// `appDataFolder` (invisible to the user in their Drive UI). Uses the Drive
/// file's `version` field for lost-update detection (the interface calls it
/// "etag" generically).
class DriveSnapshotStoreImpl implements DriveSnapshotStore {
  DriveSnapshotStoreImpl(this._client);

  final http.Client _client;

  static const _fileName = 'dejapoo_snapshot.json';
  static const _appDataFolder = 'appDataFolder';

  String? _cachedFileId;

  drive.DriveApi get _driveApi => drive.DriveApi(_client);

  Future<drive.File?> _findFile() async {
    try {
      final list = await _driveApi.files.list(
        spaces: _appDataFolder,
        q: "name = '$_fileName'",
        $fields: 'files(id, name)',
        pageSize: 1,
      );
      final files = list.files;
      if (files == null || files.isEmpty) {
        _cachedFileId = null;
        return null;
      }
      final file = files.first;
      _cachedFileId = file.id;
      return file;
    } on Exception catch (e) {
      throw SnapshotNetworkException(
        'Failed to search for snapshot file',
        cause: e,
      );
    }
  }

  @override
  Future<(Map<String, dynamic>?, String?)> readSnapshot() async {
    try {
      final fileInfo = await _findFile();
      if (fileInfo == null || fileInfo.id == null) {
        return (null, null);
      }

      // Get file metadata for the version field.
      final metadata = await _driveApi.files.get(
        fileInfo.id!,
        $fields: 'id, version',
      ) as drive.File;

      // Download the file content.
      final media = await _driveApi.files.get(
        fileInfo.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final content = utf8.decode(bytes);
      final json = jsonDecode(content) as Map<String, dynamic>;
      return (json, metadata.version);
    } on SnapshotNetworkException {
      rethrow;
    } on Exception catch (e) {
      throw SnapshotNetworkException(
        'Failed to read snapshot from Drive',
        cause: e,
      );
    }
  }

  @override
  Future<String> writeSnapshot(
    Map<String, dynamic> json, {
    String? ifMatch,
  }) async {
    final content = jsonEncode(json);
    final mediaStream = Stream<List<int>>.value(utf8.encode(content));
    final media = drive.Media(mediaStream, utf8.encode(content).length);

    try {
      final fileId = _cachedFileId ?? (await _findFile())?.id;

      if (fileId == null) {
        // Create new file in appDataFolder.
        final fileMetadata = drive.File()
          ..name = _fileName
          ..parents = [_appDataFolder];

        final created = await _driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
          $fields: 'id, version',
        );
        _cachedFileId = created.id;
        return created.version ?? '';
      }

      // Check version for lost-update guard before writing.
      if (ifMatch != null) {
        final currentMeta = await _driveApi.files.get(
          fileId,
          $fields: 'version',
        ) as drive.File;

        if (currentMeta.version != null && currentMeta.version != ifMatch) {
          throw SnapshotConflictException(
            localEtag: ifMatch,
            remoteEtag: currentMeta.version,
          );
        }
      }

      final updated = await _driveApi.files.update(
        drive.File(),
        fileId,
        uploadMedia: media,
        $fields: 'id, version',
      );
      _cachedFileId = updated.id;
      return updated.version ?? '';
    } on SnapshotConflictException {
      rethrow;
    } on SnapshotNetworkException {
      rethrow;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 412) {
        throw SnapshotConflictException(
          localEtag: ifMatch,
          remoteEtag: null,
        );
      }
      throw SnapshotNetworkException(
        'Drive API error (${e.status}): ${e.message}',
        cause: e,
      );
    } on Exception catch (e) {
      throw SnapshotNetworkException(
        'Failed to write snapshot to Drive',
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteSnapshot() async {
    try {
      final fileId = _cachedFileId ?? (await _findFile())?.id;
      if (fileId == null) return;

      await _driveApi.files.delete(fileId);
      _cachedFileId = null;
    } on Exception catch (e) {
      throw SnapshotNetworkException(
        'Failed to delete snapshot from Drive',
        cause: e,
      );
    }
  }
}
