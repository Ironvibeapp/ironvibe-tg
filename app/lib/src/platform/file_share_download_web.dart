import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'telegram.dart';

/// Must stay synchronous until the click so Telegram's WebView still
/// treats it as the user's tap. `target=_blank` is omitted: Telegram iOS
/// treats that as a blocked popup and the button appears to do nothing.
void ironVibeTriggerDownload(
  Uint8List bytes,
  String filename,
  String mimeType,
) {
  final payload = Uint8List.fromList(bytes);
  try {
    final blob = web.Blob(
      [payload.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final requested = IronVibeTelegram.requestFileDownload(
      url: url,
      fileName: filename,
    );
    if (!requested) {
      _clickAnchor(url, filename);
    }
    Future<void>.delayed(const Duration(seconds: 60), () {
      web.URL.revokeObjectURL(url);
    });
  } catch (_) {
    _clickAnchor('data:$mimeType;base64,${base64Encode(payload)}', filename);
  }
}

void _clickAnchor(String href, String filename) {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = href;
  anchor.download = filename;
  anchor.rel = 'noopener';
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

Future<void> ironVibeDownloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  ironVibeTriggerDownload(bytes, filename, mimeType);
}
