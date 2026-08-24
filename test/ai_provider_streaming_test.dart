// T04 (v2.0.1-beta.2) — AI provider streaming & multi-slide tests (phases 1–3).
//
// Deliberately NO TestWidgetsFlutterBinding: the Flutter test binding swaps
// in _MockHttpOverrides which answers every request with a 400, and these
// tests drive real loopback HTTP servers.
//
// The headline regression covered here: SSE buffering must split on real
// newlines. The pre-T04 code split on the literal two-character string '\n',
// so glued events in one chunk were never parsed and JSON cut across a chunk
// boundary was dropped until end-of-stream.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: avoid_types_on_closure_parameters
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';

/// Serves a scripted sequence of raw byte-chunks as an SSE response.
Future<HttpServer> _serveChunks(List<List<int>> chunks,
    {int dripMs = 0, int status = 200, String contentType = 'text/event-stream'}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.set('Content-Type', contentType);
    request.response.statusCode = status;
    for (final chunk in chunks) {
      if (dripMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: dripMs));
      }
      request.response.add(chunk);
      await request.response.flush();
    }
    await request.response.close();
  });
  return server;
}

Future<HttpServer> _serveJson(Map<String, Object?> payload,
    {int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType.json;
    request.response.statusCode = status;
    request.response.add(utf8.encode(jsonEncode(payload)));
    await request.response.close();
  });
  return server;
}

AIProviderConfig _config(int port, {String formatType = 'openai'}) =>
    AIProviderConfig(
      id: 'loopback',
      name: 'Loopback',
      baseUrl: 'http://127.0.0.1:$port',
      apiKey: 'sk-test',
      availableModels: const ['test-model'],
      selectedModel: 'test-model',
      contextWindow: 8192,
      formatType: formatType,
    );

String _openAiData(String text) =>
    'data: ${jsonEncode({'choices': [
          {'delta': {'content': text}}
        ]})}\n\n';

void main() {
  tearDown(() {
    AIProviderManager.streamDeadlineOverride = null;
  });

  group('SSE chunking (openai format)', () {
    test('glued events in one chunk all parse in order', () async {
      // Two complete events arrive glued into a single network write.
      final glued = utf8.encode('${_openAiData('Hello ')}${_openAiData('World ')}');
      final done = utf8.encode('data: [DONE]\n\n');
      final server = await _serveChunks([glued, done]);
      try {
        final deltas = await AIProviderManager()
            .generateSlideStream(_config(server.port), 'hi')
            .toList();
        expect(deltas.join(), 'Hello World ');
      } finally {
        await server.close(force: true);
      }
    });

    test('a JSON payload cut across chunk boundaries still parses', () async {
      final event = _openAiData('SplitToken');
      // Cut the single event into three arbitrary slices.
      final bytes = utf8.encode(event);
      final server = await _serveChunks([
        bytes.sublist(0, 9),
        bytes.sublist(9, 25),
        bytes.sublist(25),
      ]);
      try {
        final deltas = await AIProviderManager()
            .generateSlideStream(_config(server.port), 'hi')
            .toList();
        expect(deltas.join(), 'SplitToken');
      } finally {
        await server.close(force: true);
      }
    });

    test('multi-byte UTF-8 split across chunks decodes correctly', () async {
      final event = utf8.encode(_openAiData('Tiếng Việt 🎉'));
      // Cut inside the multi-byte sequences on purpose.
      final server = await _serveChunks([
        event.sublist(0, 14),
        event.sublist(14, 30),
        event.sublist(30),
      ]);
      try {
        final deltas = await AIProviderManager()
            .generateSlideStream(_config(server.port), 'hi')
            .toList();
        expect(deltas.join(), 'Tiếng Việt 🎉');
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('SSE chunking (anthropic format)', () {
    test('event/data pairs glued in one chunk stream the text deltas',
        () async {
      String dataEvent(String text) =>
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': text}
          })}\n\n';
      final glued = utf8.encode(
          'event: content_block_delta\n${dataEvent('Anthropic ')}'
          'event: content_block_delta\n${dataEvent('works')}');
      final server = await _serveChunks([glued]);
      try {
        final deltas = await AIProviderManager()
            .generateSlideStream(_config(server.port, formatType: 'anthropic'), 'hi')
            .toList();
        expect(deltas.join(), 'Anthropic works');
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('SSE chunking (gemini format)', () {
    test('glued candidate chunks stream their part text', () async {
      String dataEvent(String text) =>
          'data: ${jsonEncode({
            'candidates': [
              {'content': {'parts': [
                    {'text': text}
                  ]}}
            ]
          })}\n\n';
      final glued = utf8.encode('${dataEvent('Gemini ')}${dataEvent('rocks')}');
      final server = await _serveChunks([glued]);
      try {
        final deltas = await AIProviderManager()
            .generateSlideStream(_config(server.port, formatType: 'gemini'), 'hi')
            .toList();
        expect(deltas.join(), 'Gemini rocks');
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('stream error paths', () {
    test('a non-200 stream surfaces the friendly provider error', () async {
      final server = await _serveChunks(
        [utf8.encode('{"error":"quota exceeded"}')],
        status: 429,
        contentType: 'application/json',
      );
      try {
        await expectLater(
          AIProviderManager()
              .generateSlideStream(_config(server.port), 'hi')
              .toList(),
          throwsA(predicate((e) => e.toString().contains('Rate limit'))),
        );
      } finally {
        await server.close(force: true);
      }
    });

    test('overall deadline expiry throws TimeoutException', () async {
      AIProviderManager.streamDeadlineOverride = const Duration(milliseconds: 250);
      // Drip one chunk every 150 ms — the third lands past the 250 ms cap.
      final server = await _serveChunks(
        [utf8.encode(_openAiData('a')), utf8.encode(_openAiData('b')),
         utf8.encode(_openAiData('c')), utf8.encode(_openAiData('d'))],
        dripMs: 150,
      );
      try {
        await expectLater(
          AIProviderManager()
              .generateSlideStream(_config(server.port), 'hi')
              .toList(),
          throwsA(isA<TimeoutException>()),
        );
      } finally {
        await server.close(force: true);
      }
    });

    test('cancelStream mid-stream stops delivery without throwing', () async {
      // 30 chunks at 200 ms each — far more than the consumer will read
      // before cancelling, so the socket is guaranteed to still be live.
      final server = await _serveChunks(
        [for (var i = 0; i < 30; i++) utf8.encode(_openAiData('x$i '))],
        dripMs: 200,
      );
      try {
        final manager = AIProviderManager();
        final deltas = <String>[];
        Future<void> consume() async {
          await for (final d
              in manager.generateSlideStream(_config(server.port), 'hi')) {
            deltas.add(d);
            if (deltas.length == 1) manager.cancelStream();
          }
        }

        // The ClientException raised by closing the client mid-stream is
        // swallowed because the cancellation was user-initiated.
        await expectLater(consume(), completes);
        expect(deltas.length, lessThan(30),
            reason: 'cancellation must stop the stream early');
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('multi-slide generation', () {
    test('"Create 3 slides" returns three ordered slide objects', () async {
      final slides = [
        {'title': 'Machine Learning', 'html': '<h1>ML</h1>'},
        {'title': 'Deep Learning', 'html': '<h2>DL</h2>'},
        {'title': 'Applications', 'html': '<ul><li>vision</li></ul>'},
      ];
      // The model wraps its JSON in chatter — extraction must cope.
      final content =
          'Here are your slides:\n```json\n${jsonEncode(slides)}\n```';
      final server = await _serveJson({
        'choices': [
          {'message': {'content': content}}
        ]
      });
      try {
        final manager = AIProviderManager();
        manager.selectProvider(_config(server.port));
        final result = await manager.generateMultipleSlides('ML', slideCount: 3);

        expect(result, hasLength(3));
        expect(result.map((s) => s['title']).toList(),
            ['Machine Learning', 'Deep Learning', 'Applications']);
        expect(result.first['htmlContent'], '<h1>ML</h1>');
      } finally {
        await server.close(force: true);
      }
    });

    test('gemini multi-slide path reads candidates[0] content', () async {
      final slides = [
        {'title': 'One', 'html': '<p>1</p>'},
        {'title': 'Two', 'html': '<p>2</p>'},
      ];
      final server = await _serveJson({
        'candidates': [
          {'content': {'parts': [
                {'text': jsonEncode(slides)}
              ]}}
        ]
      });
      try {
        final manager = AIProviderManager();
        manager.selectProvider(_config(server.port, formatType: 'gemini'));
        final result = await manager.generateMultipleSlides('T', slideCount: 2);
        expect(result.map((s) => s['title']).toList(), ['One', 'Two']);
      } finally {
        await server.close(force: true);
      }
    });

    test('generateOutline returns the parsed outline entries', () async {
      final outline = [
        {'title': 'Intro', 'bullets': ['a', 'b']},
        {'title': 'Body', 'bullets': ['c']},
      ];
      final server = await _serveJson({
        'choices': [
          {'message': {'content': jsonEncode(outline)}}
        ]
      });
      try {
        final manager = AIProviderManager();
        manager.selectProvider(_config(server.port));
        final result = await manager.generateOutline('Demo', slideCount: 2);
        expect(result.map((e) => e['title']), ['Intro', 'Body']);
        expect(result.last['bullets'], ['c']);
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('deck context & validation edges', () {
    test('deck context prompt bounds each oversized section', () {
      final prompt = AIProviderManager.buildDeckContextPrompt(
        layoutType: 'title' * 5000,
        themeSummary: 'x' * 30000,
        uiLanguage: 'vi',
        currentSlideSummary: 'y' * 30000,
        deckOutline: 'z' * 30000,
      );
      // Each section is clamped independently (not the prompt as a whole).
      expect(prompt, contains('[context truncated]'));
      expect(('x' * 30000).length, greaterThan(AIProviderManager.maxDeckContextCharacters));
      expect(prompt.length, lessThan(4 * AIProviderManager.maxDeckContextCharacters + 1024));
    });

    test('validateProvider rejects an incomplete configuration', () {
      final base = _config(1);
      expect(AIProviderManager.validateProvider(base), isNull);
      expect(
        AIProviderManager.validateProvider(
            base.copyWith(selectedModel: '')),
        isNotNull,
        reason: 'a provider without a model cannot generate',
      );
      // Reality check: the validator only rejects unparseable URLs — any
      // scheme with an authority (even ftp://) passes and would fail later
      // at request time. Pinned here so a future tightening is deliberate.
      expect(
        AIProviderManager.validateProvider(base.copyWith(baseUrl: 'ftp://x')),
        isNull,
      );
      expect(
        AIProviderManager.validateProvider(base.copyWith(baseUrl: 'not a url')),
        isNotNull,
      );
    });
  });
}
