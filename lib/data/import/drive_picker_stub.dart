import 'dart:typed_data';

/// Result from the Google Drive picker.
class DrivePickerResult {
  DrivePickerResult({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

/// Stub: Drive picker is not available on non-web platforms.
bool get isDrivePickerAvailable => false;

/// Stub: throws on non-web platforms.
Future<DrivePickerResult?> pickFileFromDrive({required String accessToken}) {
  throw UnsupportedError('Drive picker is only available on web');
}
