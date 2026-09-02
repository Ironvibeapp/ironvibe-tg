import 'package:flutter/foundation.dart';

import 'kv_store.dart';
import 'online.dart';
import 'telegram.dart';

enum IronVibeSyncUi { localOnly, pending, syncing, synced }

/// Local write is always DeviceStorage / prefs. Cloud flush happens only when
/// [ironVibeIsOnline] and Telegram CloudStorage exists. Never blocks logging.
class IronVibeSync {
  static final ValueNotifier<IronVibeSyncUi> ui = ValueNotifier(
    IronVibeSyncUi.localOnly,
  );

  static Future<void> Function()? onRemoteApplied;

  /// Test seams.
  static IronVibeKvStore Function() localOf = () => IronVibeStore.kv;
  static IronVibeKvStore? Function() cloudOf = () => IronVibeTelegram.cloudStore;
  static bool Function() onlineOf = ironVibeIsOnline;

  static Future<void> start() async {
    ironVibeOnOnline(() {
      unawaitedFlush();
    });
    final cloud = cloudOf();
    if (cloud == null) {
      ui.value = IronVibeSyncUi.localOnly;
      return;
    }
    if (!onlineOf()) {
      final pending = await localOf().getString(IronVibePersistKeys.pendingSync);
      ui.value = pending == '1' ? IronVibeSyncUi.pending : IronVibeSyncUi.synced;
      return;
    }
    final pending = await localOf().getString(IronVibePersistKeys.pendingSync);
    if (pending == '1') {
      await flush();
      return;
    }
    await pullIfRemoteNewer();
  }

  static void unawaitedFlush() {
    flush();
  }

  static Future<void> markLocalDirty() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await localOf().setString(IronVibePersistKeys.updatedAt, now);
    await localOf().setString(IronVibePersistKeys.pendingSync, '1');
    final cloud = cloudOf();
    if (cloud == null) {
      ui.value = IronVibeSyncUi.localOnly;
      return;
    }
    if (!onlineOf()) {
      ui.value = IronVibeSyncUi.pending;
      return;
    }
    await flush();
  }

  static Future<void> flush() async {
    final cloud = cloudOf();
    if (cloud == null) {
      ui.value = IronVibeSyncUi.localOnly;
      return;
    }
    if (!onlineOf()) {
      ui.value = IronVibeSyncUi.pending;
      return;
    }
    ui.value = IronVibeSyncUi.syncing;
    try {
      await _copySnapshot(from: localOf(), to: cloud);
      await localOf().setString(IronVibePersistKeys.pendingSync, '0');
      ui.value = IronVibeSyncUi.synced;
    } catch (err, st) {
      debugPrint('IronVibe sync flush failed: $err\n$st');
      ui.value = IronVibeSyncUi.pending;
    }
  }

  static Future<void> pullIfRemoteNewer() async {
    final cloud = cloudOf();
    if (cloud == null || !onlineOf()) return;
    try {
      final remoteAt = await cloud.getString(IronVibePersistKeys.updatedAt);
      final localAt = await localOf().getString(IronVibePersistKeys.updatedAt);
      if (remoteAt == null || remoteAt.isEmpty) return;
      if (localAt != null &&
          localAt.isNotEmpty &&
          !_isRemoteNewer(localAt, remoteAt)) {
        ui.value = IronVibeSyncUi.synced;
        return;
      }
      await _copySnapshot(from: cloud, to: localOf());
      await localOf().setString(IronVibePersistKeys.pendingSync, '0');
      ui.value = IronVibeSyncUi.synced;
      await onRemoteApplied?.call();
    } catch (err, st) {
      debugPrint('IronVibe sync pull failed: $err\n$st');
    }
  }

  static bool _isRemoteNewer(String localIso, String remoteIso) {
    final local = DateTime.tryParse(localIso);
    final remote = DateTime.tryParse(remoteIso);
    if (local == null || remote == null) return remoteIso.compareTo(localIso) > 0;
    return remote.isAfter(local);
  }

  static Future<void> _copySnapshot({
    required IronVibeKvStore from,
    required IronVibeKvStore to,
  }) async {
    for (final key in IronVibePersistKeys.syncedStringKeys) {
      final v = await from.getString(key);
      if (v == null) {
        await to.remove(key);
      } else {
        await to.setString(key, v);
      }
    }
    for (final key in IronVibePersistKeys.syncedListKeys) {
      final v = await from.getStringList(key);
      if (v == null) {
        await to.remove(key);
      } else {
        await to.setStringList(key, v);
      }
    }
    for (final key in IronVibePersistKeys.syncedBoolKeys) {
      final v = await from.getBool(key);
      if (v == null) {
        await to.remove(key);
      } else {
        await to.setBool(key, v);
      }
    }
    await to.setString(
      IronVibePersistKeys.manifest,
      IronVibePersistKeys.syncedStringKeys.join(','),
    );
  }
}
