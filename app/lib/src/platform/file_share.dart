import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'file_share_download_stub.dart'
    if (dart.library.js_interop) 'file_share_download_web.dart';

/// Share or download bytes. Never touches `dart:io` / temp files.
Future<void> ironVibeShareFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? text,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: mimeType, name: filename),
        ],
        text: text,
      ),
    );
  } catch (err) {
    debugPrint('IronVibe share failed, falling back to download: $err');
    await ironVibeDownloadBytes(bytes, filename, mimeType);
  }
}
