import 'dart:math' as math;

/// The musical parameters the Worker derives from market sentiment.
///
/// Mirrors the `/api/composition` payload: mood, key, scale, tempo and the
/// instrumentation list.
class Composition {
  const Composition({
    required this.sentiment,
    required this.mood,
    required this.key,
    required this.scale,
    required this.tempo,
    required this.instrumentation,
    required this.timestamp,
    required this.seed,
  });

  factory Composition.fromJson(Map<String, dynamic> json) => Composition(
    sentiment: _toDouble(json['sentiment']),
    mood: (json['mood'] ?? 'Neutral').toString(),
    key: (json['key'] ?? 'C').toString(),
    scale: (json['scale'] ?? 'major').toString(),
    tempo: _toDouble(json['tempo']).toInt(),
    instrumentation: [
      for (final i in (json['instrumentation'] as List? ?? const [])) '$i',
    ],
    timestamp: (json['timestamp'] ?? '').toString(),
    seed: _toDouble(json['seed']),
  );

  final double sentiment;
  final String mood;
  final String key;
  final String scale;
  final int tempo;
  final List<String> instrumentation;
  final String timestamp;
  final double seed;

  bool get isMinor => scale == 'minor';

  /// Panic is the only mood that gets the raw, unsettled waveform — the rest
  /// stay rounded, exactly as the Tone.js client configured them.
  bool get isPanic => mood == 'Panic';

  /// The `Mood: … | Key: … | BPM: …` line.
  String get summary => 'Mood: $mood | Key: $key $scale | BPM: $tempo';

  /// The note pool the player draws from: a major seventh chord up top for
  /// rising sentiment, a minor seventh an octave lower when it sinks.
  List<String> get notes => isMinor
      ? const ['C3', 'Eb3', 'G3', 'Bb3']
      : const ['C4', 'E4', 'G4', 'B4'];

  static double _toDouble(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s) ?? 0,
    _ => 0,
  };
}

/// The three market presets the picker offers, in the original order.
const ediacaraTickers = <({String value, String label})>[
  (value: 'GLOBAL', label: 'Global Market'),
  (value: 'NASDAQ', label: 'NASDAQ (Bullish Example)'),
  (value: 'WAR', label: 'War Zone (Panic Example)'),
];

/// Picks a note for the next eighth. Seeded from the composition so a given
/// mood is reproducible rather than freshly random on every bar.
String pickNote(Composition composition, math.Random random) =>
    composition.notes[random.nextInt(composition.notes.length)];
