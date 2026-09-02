import 'package:flutter/material.dart';

import 'platform/kv_store.dart';
import 'platform/online.dart';
import 'platform/sync.dart';
import 'platform/telegram.dart';

/// Go/no-go harness: keyboard, DeviceStorage, online flag.
/// Open via `?spike=1` or long-press the version label on Home.
class IronVibeSpikeScreen extends StatefulWidget {
  const IronVibeSpikeScreen({super.key});

  @override
  State<IronVibeSpikeScreen> createState() => _IronVibeSpikeScreenState();
}

class _IronVibeSpikeScreenState extends State<IronVibeSpikeScreen> {
  final _weight = TextEditingController();
  final _note = TextEditingController();
  String _status = 'idle';

  static const _kSpikeKey = 'iv_spike_weight';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await IronVibeStore.kv.getString(_kSpikeKey);
    if (!mounted) return;
    setState(() {
      _weight.text = stored ?? '';
      _status = stored == null ? 'empty' : 'loaded from ${IronVibeStore.backendName}';
    });
  }

  Future<void> _save() async {
    await IronVibeStore.kv.setString(_kSpikeKey, _weight.text);
    if (!mounted) return;
    setState(() => _status = 'saved locally (${IronVibeStore.backendName})');
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('IronVibe spike')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Telegram: ${IronVibeTelegram.isSupported ? "yes" : "no"}  ·  '
            '${IronVibeTelegram.platform}  ·  API ${IronVibeTelegram.version}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'DeviceStorage: ${IronVibeTelegram.hasDeviceStorage}  ·  '
            'CloudStorage: ${IronVibeTelegram.hasCloudStorage}  ·  '
            'online: ${ironVibeIsOnline()}  ·  kv: ${IronVibeStore.backendName}',
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: IronVibeSync.ui,
            builder: (context, value, _) => Text('sync: $value'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight (keyboard test)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (text keyboard)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save locally')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: const Text('Reload from device')),
          const SizedBox(height: 16),
          Text('Status: $_status'),
          const SizedBox(height: 24),
          Text(
            'iPhone protocol: type a number, save, airplane mode, kill Telegram, '
            'reopen Mini App. The number must still be here and this screen must '
            'open without a network spinner. If either fails — stop, do not scale.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
