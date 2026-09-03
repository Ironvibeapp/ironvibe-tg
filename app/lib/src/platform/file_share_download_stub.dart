import 'dart:typed_data';

void ironVibeTriggerDownload(
  Uint8List bytes,
  String filename,
  String mimeType,
) {
  throw UnsupportedError(
    'Download is web-only ($filename, $mimeType, ${bytes.length})',
  );
}

Future<void> ironVibeDownloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  ironVibeTriggerDownload(bytes, filename, mimeType);
}
