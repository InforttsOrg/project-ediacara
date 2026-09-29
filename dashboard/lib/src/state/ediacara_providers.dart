import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/symphony_engine.dart';
import '../audio/symphony_engine_selector.dart';
import '../data/ediacara_api.dart';

/// Overridable so tests never touch the network.
final ediacaraApiProvider = Provider<EdiacaraApi>((ref) {
  final api = EdiacaraApi();
  ref.onDispose(api.close);
  return api;
});

/// Overridable so widget tests run against the silent engine.
final symphonyEngineProvider = Provider<SymphonyEngine>((ref) {
  final engine = createSymphonyEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// The selected market, one of `ediacaraTickers`.
final tickerProvider = StateProvider<String>((ref) => 'GLOBAL');

/// True between Play and Stop.
final isPlayingProvider = StateProvider<bool>((ref) => false);

/// The status line under the title — "Ready to Compose...", a mood summary,
/// an error, or "Symphony Paused.".
final statusProvider = StateProvider<String>((ref) => 'Ready to Compose...');
