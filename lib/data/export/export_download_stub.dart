import 'dart:typed_data';

/// Stub implementation — throws on non-web platforms.
void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('downloadFile is only supported on web');
}
