// T03 (v2.0.1-beta.2) — LocalAIDetectorService tests (phase 6).
//
// The detector probes fixed loopback ports (Ollama 11434, LM Studio 1234,
// vLLM/LocalAI 8000) with a 1.2 s timeout each. These tests bind real servers
// on those ports to emulate Ollama/LM Studio responses and rely on
// connection-refused for the offline endpoints.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/local_ai_detector_service.dart';

Future<HttpServer> _serve(int port, Map<String, Object?> Function() payload) =>
    HttpServer.bind(InternetAddress.anyIPv6, port, v6Only: false).then((server) {
      server.listen((request) async {
        final body = utf8.encode(jsonEncode(payload()));
        request.response.headers.contentType = ContentType.json;
        await request.response.addStream(Stream.value(body));
        await request.response.close();
      });
      return server;
    });

Future<HttpServer> _serveBroken(int port) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv6, port, v6Only: false);
  server.listen((request) async {
    await request.drain<void>();
    // Garbage body: valid HTTP, invalid JSON.
    request.response.add([0x00, 0x01]);
    await request.response.close();
  });
  return server;
}

// NOTE: deliberately NO TestWidgetsFlutterBinding here. Installing the
// Flutter test binding swaps in _MockHttpOverrides, which answers every
// request with a 400 instead of reaching the loopback servers below. This
// file only exercises pure dart:io networking + the detector.
void main() {
  group('all endpoints offline', () {
    test('scan finds nothing when no local AI is running', () async {
      final results = await LocalAIDetectorService().scanLocalAIServices();
      expect(results, isEmpty);
    });
  });

  group('with Ollama and LM Studio emulated', () {
    late HttpServer ollama;
    late HttpServer lmStudio;

    setUp(() async {
      ollama = await _serve(11434, () => {
            'models': [
              {'name': 'llama3:8b'},
              {'name': 'phi3:latest'},
            ],
          });
      lmStudio = await _serve(1234, () => {
            'data': [
              {'id': 'gpt-4-32k'},
            ],
          });
    });

    tearDown(() async {
      await ollama.close(force: true);
      await lmStudio.close(force: true);
    });

    test('detects both services with their model lists', () async {
      final results = await LocalAIDetectorService().scanLocalAIServices();

      final byName = {for (final r in results) r.name: r};
      expect(byName, contains('Ollama (Local)'));
      expect(byName, contains('LM Studio'));

      final ollamaInfo = byName['Ollama (Local)']!;
      expect(ollamaInfo.baseUrl, 'http://localhost:11434');
      expect(ollamaInfo.models, ['llama3:8b', 'phi3:latest']);
      expect(ollamaInfo.isOnline, isTrue);

      // OpenAI-compatible endpoints read models from data[].id.
      expect(byName['LM Studio']!.models, ['gpt-4-32k']);

      // vLLM / LocalAI on 8000 stayed offline in this scenario.
      expect(byName.containsKey('vLLM / LocalAI'), isFalse);
    });
  });

  group('hostile responses', () {
    late HttpServer broken;

    setUp(() async {
      broken = await _serveBroken(11434);
    });

    tearDown(() async {
      await broken.close(force: true);
    });

    test('a malformed JSON body is skipped without crashing the scan',
        () async {
      final results = await LocalAIDetectorService().scanLocalAIServices();
      expect(results, isEmpty,
          reason: 'the broken endpoint must be excluded, not fail the scan');
    });
  });
}
