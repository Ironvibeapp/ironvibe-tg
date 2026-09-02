import 'dart:typed_data';

Future<void> ironVibeDownloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  throw UnsupportedError('Download is web-only ($filename, $mimeType, ${bytes.length})');
}
