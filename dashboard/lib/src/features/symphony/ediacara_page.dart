import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/symphony_engine.dart';
import '../../data/composition.dart';
import '../../data/ediacara_api.dart';
import '../../state/ediacara_providers.dart';
import '../../theme/ediacara_theme.dart';

class EdiacaraPage extends ConsumerStatefulWidget {
  const EdiacaraPage({super.key});

  @override
  ConsumerState<EdiacaraPage> createState() => _EdiacaraPageState();
}

class _EdiacaraPageState extends ConsumerState<EdiacaraPage> {
  /// 30 bars, seeded flat, then driven by the engine's level stream.
  late List<double> _levels;
  bool _busy = false;
  late final SymphonyEngine _engine;

  @override
  void initState() {
    super.initState();
    _levels = List<double>.filled(visualizerBars, 0);
    // Cached so dispose() can silence the synth without touching ref.
    _engine = ref.read(symphonyEngineProvider);
    _engine.levels.listen(_onLevels);
  }

  void _onLevels(List<double> heights) {
    if (!mounted) return;
    setState(() => _levels = heights);
  }

  @override
  void dispose() {
    // The scheduler keeps running behind a torn-down tree otherwise, and an
    // orphaned AudioContext would keep playing after navigation.
    unawaited(_engine.stop());
    super.dispose();
  }

  Future<void> _toggle({required bool start}) async {
    if (_busy) return;
    if (start && ref.read(isPlayingProvider)) return;
    if (!start && !ref.read(isPlayingProvider)) return;

    setState(() => _busy = true);
    try {
      if (start) {
        final ticker = ref.read(tickerProvider);
        final Composition composition;
        try {
          composition = await ref.read(ediacaraApiProvider).composition(ticker);
        } on ApiException catch (error) {
          ref.read(statusProvider.notifier).state = 'Error: ${error.message}';
          return;
        }
        await _engine.start(composition);
        ref.read(statusProvider.notifier).state = composition.summary;
        ref.read(isPlayingProvider.notifier).state = true;
      } else {
        await _engine.stop();
        ref.read(isPlayingProvider.notifier).state = false;
        ref.read(statusProvider.notifier).state = 'Symphony Paused.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(statusProvider);
    final ticker = ref.watch(tickerProvider);
    final playing = ref.watch(isPlayingProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: EdiacaraTheme.panel,
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EDIACARA',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Market Sentiment Symphony',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: EdiacaraTheme.accent),
                    ),
                    const SizedBox(height: 24),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1E),
                        border: Border.all(color: const Color(0xFF333333)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        key: const Key('ticker'),
                        value: ticker,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1A1E),
                        borderRadius: BorderRadius.circular(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        onChanged: playing
                            ? null
                            : (value) {
                                if (value != null) {
                                  ref.read(tickerProvider.notifier).state =
                                      value;
                                }
                              },
                        items: [
                          for (final ({String value, String label}) t
                              in ediacaraTickers)
                            DropdownMenuItem<String>(
                              value: t.value,
                              child: Text(t.label),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('start'),
                          onPressed: _busy || playing
                              ? null
                              : () => _toggle(start: true),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play Symphony'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const Key('stop'),
                          onPressed: _busy || !playing
                              ? null
                              : () => _toggle(start: false),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1E),
                          ),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Visualizer(levels: _levels),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Visualizer extends StatelessWidget {
  const _Visualizer({required this.levels});

  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('visualizer'),
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final level in levels)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: (4 + level * 96).clamp(4.0, 100.0),
                decoration: const BoxDecoration(
                  color: EdiacaraTheme.accent,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
