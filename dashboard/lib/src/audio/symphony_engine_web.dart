import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../data/composition.dart';
import 'symphony_engine.dart';

/// Native Web Audio synthesiser — the replacement for the Tone.js CDN build.
///
/// One oscillator per note through an ADSR gain into a master bus, with an
/// `AnalyserNode` on the bus driving the visualiser. The scheduler runs a
/// 25 ms lookahead loop and books notes onto the audio clock, so timing does
/// not drift when the UI drops a frame.
class WebAudioSymphonyEngine with SymphonyScheduling implements SymphonyEngine {
  WebAudioSymphonyEngine({math.Random? random})
    : _random = random ?? math.Random();

  final math.Random _random;
  final StreamController<List<double>> _levels =
      StreamController<List<double>>.broadcast();

  web.AudioContext? _context;
  web.GainNode? _master;
  web.AnalyserNode? _analyser;
  late final Uint8List _spectrum;
  Timer? _meter;

  Composition? _composition;
  double _nextNoteTime = 0;

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
    await stop();

    final context = web.AudioContext();
    _context = context;
    // Chrome starts contexts suspended until a gesture; the Play button is
    // that gesture, but resume() is still the only reliable way to be heard.
    await context.resume().toDart;

    final master = context.createGain();
    master.gain.value = 0.25;

    final analyser = context.createAnalyser();
    analyser.fftSize = 128;
    analyser.smoothingTimeConstant = 0.75;
    _spectrum = Uint8List(analyser.frequencyBinCount);

    master.connect(analyser);
    analyser.connect(context.destination);

    _master = master;
    _analyser = analyser;
    _composition = composition;
    _nextNoteTime = context.currentTime;
    isPlaying = true;

    startClock(tick: const Duration(milliseconds: 25), onTick: _scheduleAhead);
    _scheduleAhead();
    _meter = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _readSpectrum();
    });
  }

  /// Books every eighth note that falls inside the lookahead window.
  void _scheduleAhead() {
    final context = _context;
    final master = _master;
    final composition = _composition;
    if (context == null || master == null || composition == null) return;

    final horizon =
        context.currentTime + scheduleLookahead.inMilliseconds / 1000;
    final step = eighthNote(composition.tempo).inMicroseconds / 1000000 / 2;
    if (step <= 0) return;

    var guard = 0;
    while (_nextNoteTime < horizon && guard++ < 32) {
      _playNote(master, pickNote(composition, _random), _nextNoteTime, step);
      _nextNoteTime += step;
    }
  }

  /// Triangle by default, sawtooth when the market is panicking.
  void _playNote(web.GainNode master, String note, double at, double duration) {
    final context = _context!;
    final frequency = _frequencies[note] ?? 261.63;

    final oscillator = context.createOscillator();
    oscillator.type = (_composition?.isPanic ?? false)
        ? 'sawtooth'
        : 'triangle';
    oscillator.frequency.value = frequency;

    final envelope = context.createGain();
    final peak = 0.3;
    final attack = 0.1;
    final release = 1.0;
    final hold = math.max(0.01, duration - attack - release * 0.35);

    final params = envelope.gain;
    params.setValueAtTime(0, at);
    params.linearRampToValueAtTime(peak, at + attack);
    params.setValueAtTime(peak, at + attack + hold);
    params.exponentialRampToValueAtTime(0.0001, at + attack + hold + release);

    oscillator.connect(envelope);
    envelope.connect(master);
    oscillator.start(at);
    oscillator.stop(at + attack + hold + release + 0.05);
  }

  /// Folds the FFT bins down into [visualizerBars] normalised heights.
  void _readSpectrum() {
    final analyser = _analyser;
    if (analyser == null) return;
    analyser.getByteFrequencyData(_spectrum.toJS);

    final bins = _spectrum.length;
    final perBar = bins / visualizerBars;
    final heights = <double>[];
    for (var bar = 0; bar < visualizerBars; bar++) {
      final start = (bar * perBar).floor();
      final end = math.min(bins, ((bar + 1) * perBar).ceil());
      var total = 0;
      for (var i = start; i < end; i++) {
        total += _spectrum[i];
      }
      final average = end > start ? total / (end - start) : 0;
      heights.add((average / 255).clamp(0.0, 1.0));
    }
    emitLevels(heights);
  }

  @override
  Future<void> stop() async {
    _meter?.cancel();
    _meter = null;
    stopClock();
    isPlaying = false;
    _composition = null;
    // Ramping the bus down rather than closing the context keeps the click out
    // of the tail of a sustained note.
    final master = _master;
    if (master != null) {
      final now = _context?.currentTime ?? 0;
      final gain = master.gain;
      gain.cancelScheduledValues(now);
      gain.setValueAtTime(gain.value, now);
      gain.linearRampToValueAtTime(0, now + 0.15);
    }
    _master = null;
    _analyser = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _levels.close();
    final context = _context;
    if (context != null) await context.close().toDart;
    _context = null;
  }
}

/// MIDI note numbers for the two seventh chords the player draws from.
const _frequencies = <String, double>{
  'C3': 130.81,
  'Eb3': 155.56,
  'G3': 196.0,
  'Bb3': 233.08,
  'C4': 261.63,
  'E4': 329.63,
  'G4': 392.0,
  'B4': 493.88,
};

/// Factory used by the conditional export.
SymphonyEngine createSymphonyEngine() => WebAudioSymphonyEngine();
