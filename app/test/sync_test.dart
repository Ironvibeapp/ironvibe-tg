import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/src/platform/kv_store.dart';
import 'package:fitness_app/src/platform/sync.dart';

void main() {
  late IronVibeChunkedKvStore local;
  late IronVibeChunkedKvStore cloud;
  var online = true;

  setUp(() {
    local = IronVibeChunkedKvStore(IronVibeMemoryRawStore());
    cloud = IronVibeChunkedKvStore(IronVibeMemoryRawStore());
    online = true;
    IronVibeSync.localOf = () => local;
    IronVibeSync.cloudOf = () => cloud;
    IronVibeSync.onlineOf = () => online;
    IronVibeSync.onRemoteApplied = null;
    IronVibeSync.ui.value = IronVibeSyncUi.localOnly;
  });

  tearDown(() {
    IronVibeSync.localOf = () => IronVibeStore.kv;
    IronVibeSync.cloudOf = () => null;
    IronVibeSync.onlineOf = () => true;
  });

  test('offline save stays pending and does not write cloud', () async {
    online = false;
    await local.setString(IronVibePersistKeys.workoutHistory, '[{"id":"1"}]');
    await IronVibeSync.markLocalDirty();
    expect(IronVibeSync.ui.value, IronVibeSyncUi.pending);
    expect(await cloud.getString(IronVibePersistKeys.workoutHistory), isNull);
  });

  test('coming online flushes the outbox to cloud', () async {
    online = false;
    await local.setString(IronVibePersistKeys.workoutHistory, '[{"id":"1"}]');
    await IronVibeSync.markLocalDirty();
    online = true;
    await IronVibeSync.flush();
    expect(await cloud.getString(IronVibePersistKeys.workoutHistory), '[{"id":"1"}]');
    expect(IronVibeSync.ui.value, IronVibeSyncUi.synced);
    expect(await local.getString(IronVibePersistKeys.pendingSync), '0');
  });

  test('pull uses last-write-wins by timestamp', () async {
    await local.setString(IronVibePersistKeys.updatedAt, '2026-01-01T00:00:00.000Z');
    await local.setString(IronVibePersistKeys.workoutHistory, 'local');
    await cloud.setString(IronVibePersistKeys.updatedAt, '2026-06-01T00:00:00.000Z');
    await cloud.setString(IronVibePersistKeys.workoutHistory, 'remote');
    var reloaded = false;
    IronVibeSync.onRemoteApplied = () async {
      reloaded = true;
    };
    await IronVibeSync.pullIfRemoteNewer();
    expect(await local.getString(IronVibePersistKeys.workoutHistory), 'remote');
    expect(reloaded, isTrue);
  });
}
