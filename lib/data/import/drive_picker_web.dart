import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Result from the Google Drive picker.
class DrivePickerResult {
  DrivePickerResult({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

/// Drive picker is available on web.
bool get isDrivePickerAvailable => true;

/// Opens the Google Picker UI and returns the selected file's bytes and name,
/// or null if the user cancelled.
Future<DrivePickerResult?> pickFileFromDrive({
  required String accessToken,
}) async {
  final completer = Completer<_PickerSelection?>();

  void callback(JSAny data) {
    final obj = data as JSObject;
    final action =
        (obj.getProperty('action'.toJS) as JSString).toDart;

    if (action == 'picked') {
      final docs = obj.getProperty('docs'.toJS) as JSArray;
      if (docs.length > 0) {
        final doc = docs[0] as JSObject;
        final id = (doc.getProperty('id'.toJS) as JSString).toDart;
        final name = (doc.getProperty('name'.toJS) as JSString).toDart;
        completer.complete(_PickerSelection(id: id, name: name));
      } else {
        completer.complete(null);
      }
    } else if (action == 'cancel') {
      completer.complete(null);
    }
  }

  _createAndShowPicker(accessToken.toJS, callback.toJS);

  final selection = await completer.future;
  if (selection == null) return null;

  final bytes = await _downloadFile(selection.id, accessToken);
  return DrivePickerResult(bytes: bytes, fileName: selection.name);
}

@JS('_createAndShowDrivePicker')
external void _createAndShowPicker(
  JSString accessToken,
  JSFunction callback,
);

Future<Uint8List> _downloadFile(String fileId, String accessToken) async {
  final url = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
  final headers = web.Headers();
  headers.set('Authorization', 'Bearer $accessToken');
  final response = await web.window.fetch(
    url.toJS,
    web.RequestInit(
      method: 'GET',
      headers: headers,
    ),
  ).toDart;

  if (!response.ok) {
    throw Exception('Failed to download file: ${response.status}');
  }

  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

class _PickerSelection {
  _PickerSelection({required this.id, required this.name});
  final String id;
  final String name;
}
