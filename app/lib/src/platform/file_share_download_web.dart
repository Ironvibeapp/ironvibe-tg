import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> ironVibeDownloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final href = 'data:$mimeType;base64,${base64Encode(bytes)}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = href;
  anchor.download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
