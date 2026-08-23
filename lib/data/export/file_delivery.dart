import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'export_download_stub.dart'
    if (dart.library.js_interop) 'export_download_web.dart';

/// Hands [bytes] to the user as a file named [fileName] of type [mimeType].
///
/// On web this triggers a browser download; on every other platform it opens
/// the native share sheet with the bytes attached as a single file.
///
/// Shared by every export path (XLSX, CSV, report images) so the delivery
/// behaviour stays identical across features.
Future<void> deliverFile(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  if (kIsWeb) {
    downloadFile(bytes, fileName, mimeType);
  } else {
    await Share.shareXFiles(
      <XFile>[XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
    );
  }
}
