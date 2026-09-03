import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'file_share_download_stub.dart'
    if (dart.library.js_interop) 'file_share_download_web.dart';

export 'file_share_download_stub.dart'
    if (dart.library.js_interop) 'file_share_download_web.dart'
    show ironVibeTriggerDownload, ironVibeDownloadBytes;

/// Share or download bytes. Never touches `dart:io` / temp files.
///
/// On web this must not `await` before the download click: Telegram's
/// WebView drops the user-gesture after the first yield, so SharePlus
/// and delayed `<a download>` look like dead buttons.
Future<void> ironVibeShareFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? text,
}) async {
  if (kIsWeb) {
    ironVibeTriggerDownload(bytes, filename, mimeType);
    return;
  }
  try {
    await SharePlus.instance
        .share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: mimeType, name: filename),
            ],
            text: text,
          ),
        )
        .timeout(const Duration(seconds: 20));
  } catch (err) {
    debugPrint('IronVibe share failed, falling back to download: $err');
    ironVibeTriggerDownload(bytes, filename, mimeType);
  }
}
