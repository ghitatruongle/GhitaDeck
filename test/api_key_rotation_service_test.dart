// T03 (v2.0.1-beta.2) — APIKeyRotationService tests (phases 1–2).
//
// The validator talks real HTTP, so these tests run a throwaway loopback
// server and point baseUrl at it. Contract under test: which status codes
// count as valid (200 / documented 404), the three provider auth styles
// (OpenAI Bearer, Anthropic x-api-key, Gemini ?key=), and graceful failure
// when nothing answers (statusCode −1).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/api_key_rotation_service.dart';

void main() {
  late HttpServer server;
  late int port;
  final received = <HttpRequest>[];
  // Per-test behaviour knobs.
  var responseStatus = 200;

  setUp(() async {
    received.clear();
    responseStatus = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) async {
      received.add(request);
      final body = utf8.encode('{"data": []}');
      request.response.statusCode = responseStatus;
      await request.response.addStream(Stream.value(body));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  group('status-code contract', () {
    test('HTTP 200 validates the key', () async {
      final service = APIKeyRotationService();
      expect(await service.testAPIKey('http://localhost:$port', 'sk-x', 'openai'),
          isTrue);

      final detailed = await service.testAPIKeyDetailed(
          'http://localhost:$port', 'sk-x', 'openai');
      expect(detailed.isValid, isTrue);
      expect(detailed.statusCode, 200);
      expect(detailed.errorMessage, isNull);
      expect(detailed.latencyMs, greaterThanOrEqualTo(0));
    });

    test('HTTP 404 still counts as a valid connection (documented)', () async {
      responseStatus = 404;
      final service = APIKeyRotationService();
      expect(
        await service.testAPIKey('http://localhost:$port', 'sk-x', 'openai'),
        isTrue,
        reason: 'endpoint exists but lists no models — connection is fine',
      );
    });

    test('HTTP 401 rejects the key with the status recorded', () async {
      responseStatus = 401;
      final service = APIKeyRotationService();
      final result = await service.testAPIKeyDetailed(
          'http://localhost:$port', 'bad-key', 'openai');
      expect(result.isValid, isFalse);
      expect(result.statusCode, 401);
      expect(result.errorMessage, 'HTTP 401');
    });
  });

  group('provider auth styles', () {
    test('openai-style sends Authorization: Bearer <key>', () async {
      final service = APIKeyRotationService();
      await service.testAPIKey('http://localhost:$port', 'sk-openai', 'openai');

      expect(received.single.uri.path, '/v1/models');
      expect(received.single.headers.value('authorization'), 'Bearer sk-openai');
    });

    test('anthropic-style sends x-api-key plus version header', () async {
      final service = APIKeyRotationService();
      await service.testAPIKey(
          'http://localhost:$port', 'sk-ant', 'anthropic');

      expect(received.single.uri.path, '/v1/models');
      expect(received.single.headers.value('x-api-key'), 'sk-ant');
      expect(received.single.headers.value('anthropic-version'), '2023-06-01');
    });

    test('gemini-style puts the key in the query string', () async {
      final service = APIKeyRotationService();
      await service.testAPIKey('http://localhost:$port', 'g-key', 'google');

      expect(received.single.uri.path, '/v1beta/models');
      expect(received.single.uri.queryParameters['key'], 'g-key');
    });

    test('empty key sends no credential at all', () async {
      final service = APIKeyRotationService();
      await service.testAPIKey('http://localhost:$port', '', 'openai');

      expect(received.single.headers.value('authorization'), isNull);
    });
  });

  group('offline handling', () {
    test('connection refused yields statusCode −1 with an error message',
        () async {
      // Close the server first so the port refuses connections.
      final deadPort = port;
      await server.close(force: true);

      final service = APIKeyRotationService();
      expect(
        await service.testAPIKey('http://localhost:$deadPort', 'k', 'openai'),
        isFalse,
      );

      final result = await service.testAPIKeyDetailed(
          'http://localhost:$deadPort', 'k', 'openai');
      expect(result.isValid, isFalse);
      expect(result.statusCode, -1);
      expect(result.errorMessage, isNotNull);
    });
  });
}
