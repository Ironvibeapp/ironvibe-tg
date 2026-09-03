import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kv_store.dart';

final GlobalKey<NavigatorState> ironVibeNavigatorKey =
    GlobalKey<NavigatorState>();

@JS('Telegram')
external JSObject? get _telegramNs;

JSObject? get _webApp {
  final ns = _telegramNs;
  if (ns == null) return null;
  final wa = ns.getProperty('WebApp'.toJS);
  if (wa == null || wa.isUndefinedOrNull) return null;
  return wa as JSObject;
}

class _JsRawStore implements IronVibeRawStringStore {
  _JsRawStore(this._storage);

  final JSObject _storage;

  @override
  Future<String?> getItem(String key) {
    if (!ironVibeIsTelegramStorageKey(key)) {
      return Future<String?>.value(null);
    }
    final c = Completer<String?>();
    void cb(JSAny? error, JSAny? result) {
      if (c.isCompleted) return;
      if (error != null && !error.isUndefinedOrNull) {
        c.completeError(StateError(error.toString()));
        return;
      }
      if (result == null || result.isUndefinedOrNull) {
        c.complete(null);
        return;
      }
      c.complete(result.toString());
    }

    _storage.callMethod('getItem'.toJS, key.toJS, cb.toJS);
    return c.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException('Telegram getItem $key'),
    );
  }

  @override
  Future<void> setItem(String key, String value) {
    if (!ironVibeIsTelegramStorageKey(key)) {
      return Future.error(ArgumentError.value(key, 'key', 'Telegram storage key'));
    }
    final c = Completer<void>();
    void cb(JSAny? error, JSAny? result) {
      if (c.isCompleted) return;
      if (error != null && !error.isUndefinedOrNull) {
        c.completeError(StateError(error.toString()));
        return;
      }
      c.complete();
    }

    _storage.callMethod('setItem'.toJS, key.toJS, value.toJS, cb.toJS);
    return c.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException('Telegram setItem $key'),
    );
  }

  @override
  Future<void> removeItem(String key) {
    if (!ironVibeIsTelegramStorageKey(key)) {
      return Future.value();
    }
    final c = Completer<void>();
    void cb(JSAny? error, JSAny? result) {
      if (c.isCompleted) return;
      if (error != null && !error.isUndefinedOrNull) {
        c.completeError(StateError(error.toString()));
        return;
      }
      c.complete();
    }

    _storage.callMethod('removeItem'.toJS, key.toJS, cb.toJS);
    return c.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException('Telegram removeItem $key'),
    );
  }
}

class _TelegramNavObserver extends NavigatorObserver {
  void _sync() {
    final canPop = ironVibeNavigatorKey.currentState?.canPop() ?? false;
    IronVibeTelegram.syncBackButton(canPop);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sync();
}

class IronVibeTelegram {
  static bool _booted = false;

  static bool get isSupported => _webApp != null;

  static bool _versionAtLeast(String want) {
    try {
      final wa = _webApp;
      if (wa == null) return false;
      final result = wa.callMethod('isVersionAtLeast'.toJS, want.toJS);
      if (result == null || result.isUndefinedOrNull) return false;
      if (result.isA<JSBoolean>()) return (result as JSBoolean).toDart;
      return result.toString() == 'true';
    } catch (_) {
      return false;
    }
  }

  static bool get hasDeviceStorage => isSupported && _versionAtLeast('9.0');

  static bool get hasCloudStorage => isSupported && _versionAtLeast('6.9');

  static bool get suggestsDark {
    try {
      final wa = _webApp;
      if (wa == null) return false;
      final scheme = wa.getProperty('colorScheme'.toJS)?.toString();
      return scheme == 'dark';
    } catch (_) {
      return false;
    }
  }

  static String get platform {
    try {
      return _webApp?.getProperty('platform'.toJS)?.toString() ?? 'browser';
    } catch (_) {
      return 'browser';
    }
  }

  static String get version {
    try {
      return _webApp?.getProperty('version'.toJS)?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static IronVibeKvStore? cloudStore;
  static IronVibeRawStringStore? deviceRaw;
  static final NavigatorObserver navObserver = _TelegramNavObserver();

  static JSObject? _storage(String name) {
    final wa = _webApp;
    if (wa == null) return null;
    final s = wa.getProperty(name.toJS);
    if (s == null || s.isUndefinedOrNull) return null;
    return s as JSObject;
  }

  static Future<void> boot() async {
    if (_booted) return;
    _booted = true;
    try {
      final wa = _webApp;
      if (wa == null) return;
      wa.callMethod('ready'.toJS);
      wa.callMethod('expand'.toJS);
      try {
        wa.callMethod('disableVerticalSwipes'.toJS);
      } catch (_) {}
      void onBack(JSAny? _) {
        ironVibeNavigatorKey.currentState?.maybePop();
      }

      wa.callMethod('onEvent'.toJS, 'backButtonClicked'.toJS, onBack.toJS);

      final device = _storage('DeviceStorage');
      if (hasDeviceStorage && device != null) {
        deviceRaw = _JsRawStore(device);
      }
      final cloud = _storage('CloudStorage');
      if (hasCloudStorage && cloud != null) {
        cloudStore = IronVibeChunkedKvStore(_JsRawStore(cloud));
      }
    } catch (err, st) {
      debugPrint('IronVibe Telegram boot failed: $err\n$st');
    }
  }

  /// Bot API 8.0+. Requires an HTTPS URL; blob/data URLs usually fail.
  static bool requestFileDownload({
    required String url,
    required String fileName,
  }) {
    try {
      if (!_versionAtLeast('8.0')) return false;
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') return false;
      final wa = _webApp;
      if (wa == null) return false;
      final params = JSObject();
      params.setProperty('url'.toJS, url.toJS);
      params.setProperty('file_name'.toJS, fileName.toJS);
      wa.callMethod('downloadFile'.toJS, params);
      return true;
    } catch (_) {
      return false;
    }
  }

  static void syncBackButton(bool canPop) {
    try {
      final wa = _webApp;
      if (wa == null) return;
      final btn = wa.getProperty('BackButton'.toJS);
      if (btn == null || btn.isUndefinedOrNull) return;
      final obj = btn as JSObject;
      obj.callMethod((canPop ? 'show' : 'hide').toJS);
    } catch (_) {}
  }

  static void applyChrome(ThemeMode mode) {
    try {
      final wa = _webApp;
      if (wa == null) return;
      final dark = mode == ThemeMode.dark;
      final hex = dark ? '#121212' : '#F4F1EA';
      wa.callMethod('setHeaderColor'.toJS, hex.toJS);
      wa.callMethod('setBackgroundColor'.toJS, hex.toJS);
      try {
        wa.callMethod('setBottomBarColor'.toJS, hex.toJS);
      } catch (_) {}
    } catch (_) {}
  }

  static Future<void> openUrl(Uri uri) async {
    try {
      final wa = _webApp;
      if (wa != null) {
        final url = uri.toString();
        if (uri.scheme == 'tg' ||
            uri.host == 't.me' ||
            uri.host.endsWith('.t.me')) {
          wa.callMethod('openTelegramLink'.toJS, url.toJS);
          return;
        }
        wa.callMethod('openLink'.toJS, url.toJS);
        return;
      }
    } catch (err) {
      debugPrint('IronVibe Telegram openUrl: $err');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
