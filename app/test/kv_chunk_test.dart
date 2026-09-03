import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/src/platform/kv_store.dart';

void main() {
  test('chunked store round-trips a value larger than the chunk size', () async {
    final raw = IronVibeMemoryRawStore();
    final kv = IronVibeChunkedKvStore(raw, chunkSize: 8);
    const value = 'abcdefghijklmnopqrstuvwxyz';
    await kv.setString('history', value);
    expect(await kv.getString('history'), value);
    expect(raw.data.containsKey('history'), isFalse);
    expect(raw.data.length, greaterThan(2));
  });

  test('chunk part keys match Telegram CloudStorage charset', () async {
    final raw = IronVibeMemoryRawStore();
    final kv = IronVibeChunkedKvStore(raw, chunkSize: 4);
    await kv.setString('workoutHistory', 'abcdefghij');
    expect(raw.data.keys.every(ironVibeIsTelegramStorageKey), isTrue);
    expect(raw.data.containsKey('workoutHistory__n'), isTrue);
    expect(raw.data.containsKey('workoutHistory__0'), isTrue);
  });

  test('reads legacy record-separator chunk keys then rewrites safely', () async {
    final raw = IronVibeMemoryRawStore();
    raw.data['workoutHistory\u{1e}n'] = '2';
    raw.data['workoutHistory\u{1e}0'] = 'ab';
    raw.data['workoutHistory\u{1e}1'] = 'cd';
    final kv = IronVibeChunkedKvStore(raw, chunkSize: 4);
    expect(await kv.getString('workoutHistory'), 'abcd');
    await kv.setString('workoutHistory', 'abcd');
    expect(raw.data.keys.any((k) => k.contains('\u{1e}')), isFalse);
    expect(raw.data.keys.every(ironVibeIsTelegramStorageKey), isTrue);
  });

  test('replacing a chunked value with a short one clears leftover parts', () async {
    final raw = IronVibeMemoryRawStore();
    final kv = IronVibeChunkedKvStore(raw, chunkSize: 4);
    await kv.setString('k', 'abcdefghij');
    await kv.setString('k', 'ok');
    expect(await kv.getString('k'), 'ok');
    expect(raw.data.keys.where((k) => k.startsWith('k')), hasLength(1));
  });

  test('string lists and bools encode through the chunked store', () async {
    final kv = IronVibeChunkedKvStore(IronVibeMemoryRawStore());
    await kv.setStringList('bank', ['squat', 'bench']);
    await kv.setBool('light', false);
    expect(await kv.getStringList('bank'), ['squat', 'bench']);
    expect(await kv.getBool('light'), isFalse);
  });
}
