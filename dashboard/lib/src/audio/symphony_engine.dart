import 'dart:async';
import 'dart:math' as math;

import '../data/composition.dart';

/// How many bars the visualiser draws — the original page built 30 `<div>`s.
const visualizerBars = 30;

/// How far ahead of the audio clock notes are booked. Large enough that a busy
/// frame cannot starve the synth, small enough that a tempo change is heard
/// within a frame or two.
const scheduleLookahead = Duration(milliseconds: 120);

/// A synthesiser that turns a [Composition] into sound plus level data.
///
/// The web implementation drives Web Audio directly; the stub keeps
/// `flutter test` (Dart VM) working without an audio device.
abstract class SymphonyEngine {
  bool get isPlaying;

  /// Fires ~20x/second while playing: one normalised 0..1 height per
  /// visualiser bar.
  Stream<List<double>> get levels;

  /// Begins the loop described by [composition].
  Future<void> start(Composition composition);

  /// Stops scheduling and silences anything still ringing.
  Future<void> stop();

  Future<void> dispose();
}

/// Owns the note choices and the tempo; the platform only makes sound.
mixin SymphonyScheduling {
  final math.Random _random = math.Random();
  Timer? _clock;

  /// Pushes bar heights onto [levels].
  void emitLevels(List<double> heights);

  /// Advances the visualiser without an audio device. The web engine replaces
  /// this with real FFT data; this keeps widget tests and non-browser targets
  /// from rendering a dead flat line.
  void emitSyntheticLevels() {
    emitLevels([for (var i = 0; i < visualizerBars; i++) _random.nextDouble()]);
  }

  /// A single eighth note at [tempo] BPM.
  Duration eighthNote(int tempo) => Duration(
    microseconds: (Duration.microsecondsPerMinute / tempo / 2).round(),
  );

  void startClock({required Duration tick, required void Function() onTick}) {
    _clock?.cancel();
    _clock = Timer.periodic(tick, (_) => onTick());
  }

  void stopClock() {
    _clock?.cancel();
    _clock = null;
  }
}
