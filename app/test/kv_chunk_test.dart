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
