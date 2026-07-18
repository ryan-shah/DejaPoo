import 'dart:js_interop';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Downloads [bytes] as a file in the browser by creating a temporary
/// object URL, attaching it to an anchor element, and clicking it.
void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  final web.Blob blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor =
      web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
