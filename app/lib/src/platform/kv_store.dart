import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny key/value API used by [DataService] and sync.
/// Telegram DeviceStorage/CloudStorage only store strings, so lists/bools are encoded.
abstract class IronVibeKvStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);

  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> values);

  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

/// Browser / test fallback. On web this is localStorage — not trusted inside
/// Telegram iOS WebView, but fine for `flutter test` and opening the URL in a
/// regular browser.
class IronVibePrefsKvStore implements IronVibeKvStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final prefs = await _prefs;
    final list = prefs.getStringList(key);
    if (list != null) return list;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> setStringList(String key, List<String> values) async {
    await (await _prefs).setStringList(key, values);
  }

  @override
  Future<bool?> getBool(String key) async => (await _prefs).getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await (await _prefs).setBool(key, value);
  }
}

/// Raw string bucket (DeviceStorage / CloudStorage / in-memory).
abstract class IronVibeRawStringStore {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
  Future<void> removeItem(String key);
}

/// In-memory backend for unit tests.
class IronVibeMemoryRawStore implements IronVibeRawStringStore {
  final Map<String, String> data = {};

  @override
  Future<String?> getItem(String key) async => data[key];

  @override
  Future<void> setItem(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    data.remove(key);
  }
}

/// Splits values so they fit Telegram CloudStorage (4096 chars) and stay
/// conservative on DeviceStorage.
const int kIronVibeKvChunkSize = 3500;

/// Telegram CloudStorage / DeviceStorage keys: 1–128 chars of A–Z a–z 0–9 _ -
final RegExp kIronVibeTelegramStorageKeyPattern = RegExp(
  r'^[A-Za-z0-9_-]{1,128}$',
);

bool ironVibeIsTelegramStorageKey(String key) =>
    kIronVibeTelegramStorageKeyPattern.hasMatch(key);

class IronVibeChunkedKvStore implements IronVibeKvStore {
  IronVibeChunkedKvStore(this._raw, {this.chunkSize = kIronVibeKvChunkSize});

  final IronVibeRawStringStore _raw;
  final int chunkSize;

  /// Telegram CloudStorage/DeviceStorage keys: 1–128 chars of A–Z a–z 0–9 _ -
  static String _nKey(String key) => '${key}__n';
  static String _partKey(String key, int i) => '${key}__$i';
  static String _legacyNKey(String key) => '$key\u{1e}n';
  static String _legacyPartKey(String key, int i) => '$key\u{1e}$i';

  Future<int> _partCount(String nKey) async {
    final nRaw = await _raw.getItem(nKey);
    return int.tryParse(nRaw ?? '') ?? 0;
  }

  Future<void> _clearScheme(
    String key, {
    required String Function(String) nKeyOf,
    required String Function(String, int) partKeyOf,
  }) async {
    final nKey = nKeyOf(key);
    final n = await _partCount(nKey);
    for (var i = 0; i < n; i++) {
      await _raw.removeItem(partKeyOf(key, i));
    }
    await _raw.removeItem(nKey);
  }

  Future<void> _clearParts(String key) async {
    await _clearScheme(key, nKeyOf: _nKey, partKeyOf: _partKey);
    await _clearScheme(key, nKeyOf: _legacyNKey, partKeyOf: _legacyPartKey);
  }

  Future<String?> _readChunks(
    String key, {
    required String Function(String) nKeyOf,
    required String Function(String, int) partKeyOf,
  }) async {
    final n = await _partCount(nKeyOf(key));
    if (n <= 0) return null;
    final buf = StringBuffer();
    for (var i = 0; i < n; i++) {
      buf.write(await _raw.getItem(partKeyOf(key, i)) ?? '');
    }
    return buf.toString();
  }

  @override
  Future<String?> getString(String key) async {
    final modern = await _readChunks(key, nKeyOf: _nKey, partKeyOf: _partKey);
    if (modern != null) return modern;
    final legacy = await _readChunks(
      key,
      nKeyOf: _legacyNKey,
      partKeyOf: _legacyPartKey,
    );
    if (legacy != null) return legacy;
    return _raw.getItem(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _clearParts(key);
    if (value.length <= chunkSize) {
      await _raw.setItem(key, value);
      return;
    }
    await _raw.removeItem(key);
    final n = (value.length / chunkSize).ceil();
    await _raw.setItem(_nKey(key), '$n');
    for (var i = 0; i < n; i++) {
      final start = i * chunkSize;
      final end = start + chunkSize > value.length
          ? value.length
          : start + chunkSize;
      await _raw.setItem(_partKey(key, i), value.substring(start, end));
    }
  }

  @override
  Future<void> remove(String key) async {
    await _clearParts(key);
    await _raw.removeItem(key);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final raw = await getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> setStringList(String key, List<String> values) async {
    await setString(key, jsonEncode(values));
  }

  @override
  Future<bool?> getBool(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    if (raw == '1' || raw == 'true') return true;
    if (raw == '0' || raw == 'false') return false;
    return null;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await setString(key, value ? '1' : '0');
  }
}

/// Keys persisted by the app (local + cloud snapshot).
class IronVibePersistKeys {
  static const exerciseBank = 'exerciseBank';
  static const workoutHistory = 'workoutHistory';
  static const clients = 'clients';
  static const trainerSchedule = 'trainerSchedule';
  static const activeWorkoutDraft = 'activeWorkoutDraft';
  static const athleteFavoriteExercises = 'athleteFavoriteExercises';
  static const exerciseMuscleGroups = 'exerciseMuscleGroups';
  static const lightTheme = 'ironvibe_light_theme';
  static const backupNudgeAt = 'ironvibe_backup_nudge_at';
  static const deloadNudgeAt = 'ironvibe_deload_nudge_at';
  static const updatedAt = 'iv_updated_at';
  static const pendingSync = 'iv_pending_sync';
  static const manifest = 'iv_manifest';

  /// Synced across devices. Draft stays on-device only.
  static const List<String> syncedStringKeys = [
    workoutHistory,
    clients,
    trainerSchedule,
    exerciseMuscleGroups,
    backupNudgeAt,
    deloadNudgeAt,
    updatedAt,
  ];

  static const List<String> syncedListKeys = [
    exerciseBank,
    athleteFavoriteExercises,
  ];

  static const List<String> syncedBoolKeys = [lightTheme];
}

class IronVibeStore {
  static IronVibeKvStore kv = IronVibePrefsKvStore();
  static String backendName = 'shared_preferences';

  static Future<void> init({IronVibeKvStore? override}) async {
    if (override != null) {
      kv = override;
      backendName = 'override';
      return;
    }
    kv = IronVibePrefsKvStore();
    backendName = 'shared_preferences';
  }

  static Future<void> useChunked(IronVibeRawStringStore raw, {String name = 'device'}) async {
    final device = IronVibeChunkedKvStore(raw);
    await _migrateFromPrefsIfDeviceEmpty(device);
    kv = device;
    backendName = name;
  }

  static Future<void> _migrateFromPrefsIfDeviceEmpty(IronVibeKvStore device) async {
    final existing = await device.getString(IronVibePersistKeys.workoutHistory);
    if (existing != null && existing.isNotEmpty && existing != '[]') return;
    final prefs = IronVibePrefsKvStore();
    final history = await prefs.getString(IronVibePersistKeys.workoutHistory);
    if (history == null || history.isEmpty || history == '[]') {
      final clients = await prefs.getString(IronVibePersistKeys.clients);
      if (clients == null || clients.isEmpty || clients == '[]') return;
    }
    for (final key in IronVibePersistKeys.syncedStringKeys) {
      final v = await prefs.getString(key);
      if (v != null) await device.setString(key, v);
    }
    for (final key in IronVibePersistKeys.syncedListKeys) {
      final v = await prefs.getStringList(key);
      if (v != null) await device.setStringList(key, v);
    }
    for (final key in IronVibePersistKeys.syncedBoolKeys) {
      final v = await prefs.getBool(key);
      if (v != null) await device.setBool(key, v);
    }
    final draft = await prefs.getString(IronVibePersistKeys.activeWorkoutDraft);
    if (draft != null) {
      await device.setString(IronVibePersistKeys.activeWorkoutDraft, draft);
    }
  }
}
