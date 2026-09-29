import 'dart:async';

import '../data/composition.dart';
import 'symphony_engine.dart';

/// Non-browser fallback: schedules the same rhythm and the same level ticks as
/// the Web Audio engine, but makes no sound. `flutter test` runs on the Dart
/// VM, where `dart:js_interop` is not available.
class SymphonyEngineStub with SymphonyScheduling implements SymphonyEngine {
  final StreamController<List<double>> _levels =
      StreamController<List<double>>.broadcast();

  int _beats = 0;

  @override
  bool isPlaying = false;

  @override
  Stream<List<double>> get levels => _levels.stream;

  @override
  void emitLevels(List<double> heights) {
    if (!_levels.isClosed) _levels.add(heights);
  }

  @override
  Future<void> start(Composition composition) async {
    _beats = 0;
    isPlaying = true;
    final eighth = eighthNote(composition.tempo);
    startClock(
      tick: Duration(milliseconds: eighth.inMilliseconds ~/ 4 + 1),
      onTick: () {
        _beats++;
        emitSyntheticLevels();
      },
    );
  }

  @override
  Future<void> stop() async {
    stopClock();
    isPlaying = false;
  }

  /// Number of eighth notes scheduled since [start] — lets a test assert the
  /// clock really is running.
  int get beats => _beats;

  @override
  Future<void> dispose() async {
    await stop();
    await _levels.close();
  }
}

/// Factory used by the conditional export, so callers never name a concrete
/// engine — the web build only has the Web Audio one.
SymphonyEngine createSymphonyEngine() => SymphonyEngineStub();
