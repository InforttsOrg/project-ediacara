import 'dart:convert';

import 'package:ediacara/src/audio/symphony_engine.dart';
import 'package:ediacara/src/audio/symphony_engine_stub.dart';
import 'package:ediacara/src/data/composition.dart';
import 'package:ediacara/src/data/ediacara_api.dart';
import 'package:ediacara/src/features/symphony/ediacara_page.dart';
import 'package:ediacara/src/state/ediacara_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Minimal echo of the Worker's `/api/composition` payload.
final panicJson = <String, Object?>{
  'sentiment': -0.9,
  'mood': 'Panic',
  'key': 'C',
  'scale': 'minor',
  'tempo': 40,
  'instrumentation': ['organ', 'cello', 'bassoon'],
  'timestamp': '2026-01-01T00:00:00.000Z',
  'seed': 123.5,
};

final euphoriaJson = <String, Object?>{
  'sentiment': 0.95,
  'mood': 'Euphoria',
  'key': 'E',
  'scale': 'major',
  'tempo': 160,
  'instrumentation': ['violin', 'trumpet', 'flute', 'timpani'],
  'timestamp': '2026-01-01T00:00:00.000Z',
  'seed': 7.0,
};

Composition compositionFrom(Map<String, Object?> json) =>
    Composition.fromJson(json as Map<String, dynamic>);

EdiacaraApi apiReturning(
  Object? body, {
  int status = 200,
  void Function(http.BaseRequest request)? onRequest,
}) {
  return EdiacaraApi(
    client: MockClient((request) async {
      if (onRequest != null) onRequest(request);
      return http.Response(
        body is String ? body : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Future<void> pumpConsole(
  WidgetTester tester, {
  required EdiacaraApi api,
  SymphonyEngine? engine,
  String ticker = 'GLOBAL',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ediacaraApiProvider.overrideWithValue(api),
        if (engine != null) symphonyEngineProvider.overrideWithValue(engine),
        tickerProvider.overrideWith((ref) => ticker),
      ],
      child: const MaterialApp(home: EdiacaraPage()),
    ),
  );
  await tester.pump();
}

void main() {
  group('Composition', () {
    test('parses the Worker payload', () {
      final composition = compositionFrom(panicJson);
      expect(composition.mood, 'Panic');
      expect(composition.key, 'C');
      expect(composition.scale, 'minor');
      expect(composition.isMinor, isTrue);
      expect(composition.tempo, 40);
      expect(composition.sentiment, -0.9);
      expect(composition.instrumentation, ['organ', 'cello', 'bassoon']);
      expect(composition.isPanic, isTrue);
    });

    test('summary line matches the original UI copy', () {
      expect(
        compositionFrom(euphoriaJson).summary,
        'Mood: Euphoria | Key: E major | BPM: 160',
      );
    });

    test('minor moods play the low seventh chord, major the high one', () {
      expect(compositionFrom(panicJson).notes, ['C3', 'Eb3', 'G3', 'Bb3']);
      expect(compositionFrom(euphoriaJson).notes, ['C4', 'E4', 'G4', 'B4']);
    });

    test('tolerates missing fields and string numbers', () {
      final composition = Composition.fromJson(<String, dynamic>{
        'sentiment': '0.5',
        'tempo': '90',
      });
      expect(composition.mood, 'Neutral');
      expect(composition.key, 'C');
      expect(composition.scale, 'major');
      expect(composition.tempo, 90);
      expect(composition.instrumentation, isEmpty);
    });
  });

  group('EdiacaraApi', () {
    test('requests the same-origin composition endpoint', () async {
      late Uri seen;
      final api = EdiacaraApi(
        client: MockClient((request) async {
          seen = request.url;
          return http.Response(jsonEncode(panicJson), 200);
        }),
      );
      final composition = await api.composition('WAR');
      expect(seen.path, '/api/composition');
      expect(seen.queryParameters['ticker'], 'WAR');
      expect(composition.mood, 'Panic');
    });

    test('honours an origin override', () {
      final api = EdiacaraApi(
        client: MockClient((_) async => http.Response('', 200)),
        origin: 'https://ediacara.infortts.site/app',
      );
      final uri = api.endpoint('/api/composition', {'ticker': 'NASDAQ'});
      expect(uri.host, 'ediacara.infortts.site');
      expect(uri.path, '/api/composition');
      expect(uri.queryParameters['ticker'], 'NASDAQ');
    });

    test('raises a typed error on a non-200', () {
      expect(
        () => apiReturning(panicJson, status: 502).composition('GLOBAL'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });

    test('raises a typed error on non-JSON', () {
      expect(
        () => apiReturning('<html>oops</html>').composition('GLOBAL'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('non-JSON'),
          ),
        ),
      );
    });
  });

  group('SymphonyEngineStub', () {
    test('runs the eighth-note clock and emits bar levels', () async {
      final engine = SymphonyEngineStub();
      final levels = <List<double>>[];
      final sub = engine.levels.listen(levels.add);

      await engine.start(compositionFrom(panicJson));
      expect(engine.isPlaying, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await engine.stop();

      expect(engine.isPlaying, isFalse);
      expect(engine.beats, greaterThan(0));
      expect(levels, isNotEmpty);
      expect(levels.first.length, visualizerBars);
      expect(levels.first.every((v) => v >= 0 && v <= 1), isTrue);

      await sub.cancel();
      await engine.dispose();
    });

    test('an eighth note at 120 BPM is a quarter second', () {
      final engine = SymphonyEngineStub();
      expect(engine.eighthNote(120).inMilliseconds, 250);
      expect(engine.eighthNote(40).inMilliseconds, 750);
      expect(engine.eighthNote(160).inMilliseconds, 187);
    });
  });

  group('EdiacaraPage', () {
    testWidgets('renders the original chrome', (tester) async {
      await pumpConsole(tester, api: apiReturning(panicJson));

      expect(find.text('EDIACARA'), findsOneWidget);
      expect(find.text('Market Sentiment Symphony'), findsOneWidget);
      expect(find.text('Ready to Compose...'), findsOneWidget);
      expect(find.byKey(const Key('start')), findsOneWidget);
      expect(find.byKey(const Key('stop')), findsOneWidget);
      expect(find.byKey(const Key('ticker')), findsOneWidget);
      expect(find.byKey(const Key('visualizer')), findsOneWidget);
    });

    testWidgets('offers the three market presets', (tester) async {
      await pumpConsole(tester, api: apiReturning(panicJson));

      await tester.tap(find.byKey(const Key('ticker')));
      await tester.pumpAndSettle();
      for (final ticker in ediacaraTickers) {
        expect(find.text(ticker.label).last, findsWidgets);
      }
    });

    testWidgets('Play fetches the composition and starts the engine', (
      tester,
    ) async {
      final engine = SymphonyEngineStub();
      final seen = <http.BaseRequest>[];
      await pumpConsole(
        tester,
        api: apiReturning(euphoriaJson, onRequest: seen.add),
        engine: engine,
        ticker: 'NASDAQ',
      );

      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(seen.single.url.queryParameters['ticker'], 'NASDAQ');
      expect(engine.isPlaying, isTrue);
      expect(
        find.text('Mood: Euphoria | Key: E major | BPM: 160'),
        findsOneWidget,
      );
      // Stop becomes available only while the symphony is running.
      final stop = tester.widget<FilledButton>(find.byKey(const Key('stop')));
      expect(stop.onPressed, isNotNull);
    });

    testWidgets('Stop halts the engine and says so', (tester) async {
      final engine = SymphonyEngineStub();
      await pumpConsole(tester, api: apiReturning(panicJson), engine: engine);

      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pump();

      expect(engine.isPlaying, isFalse);
      expect(find.text('Symphony Paused.'), findsOneWidget);
    });

    testWidgets('an API failure surfaces in the status line', (tester) async {
      final engine = SymphonyEngineStub();
      await pumpConsole(
        tester,
        api: apiReturning(panicJson, status: 500),
        engine: engine,
      );

      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(engine.isPlaying, isFalse);
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('the visualiser is 30 bars and animates', (tester) async {
      final engine = SymphonyEngineStub();
      await pumpConsole(tester, api: apiReturning(panicJson), engine: engine);

      final bars = find.descendant(
        of: find.byKey(const Key('visualizer')),
        matching: find.byType(AnimatedContainer),
      );
      expect(bars, findsNWidgets(visualizerBars));

      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(bars, findsNWidgets(visualizerBars));
    });
  });
}
