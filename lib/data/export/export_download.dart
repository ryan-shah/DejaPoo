import 'dart:typed_data';

/// Downloads [bytes] as a file in the browser. Only available on web.
///
/// This is the interface file — the actual implementation is selected via
/// conditional imports:
///   import 'export_download_stub.dart'
///       if (dart.library.js_interop) 'export_download_web.dart';
void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('downloadFile is only supported on web');
}
