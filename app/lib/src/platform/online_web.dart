import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool ironVibeIsOnline() {
  try {
    return web.window.navigator.onLine;
  } catch (_) {
    return true;
  }
}

void ironVibeOnOnline(void Function() callback) {
  try {
    web.window.addEventListener(
      'online',
      (web.Event _) {
        callback();
      }.toJS,
    );
  } catch (_) {}
}
