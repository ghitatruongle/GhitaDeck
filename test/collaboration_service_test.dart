import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/collaboration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Flutter's test binding blocks all HttpClient traffic by default. These
  // integration tests intentionally use only a loopback shelf server.
  setUpAll(() => HttpOverrides.global = null);

  group('CollaborationService security and real sync', () {
    late CollaborationService host;
    late CollaborationService client;
    late List<Map<String, dynamic>> hostSlides;
    late List<Map<String, dynamic>> clientSlides;

    setUp(() {
      hostSlides = [_slide('Host title', '<h1>Host</h1>')];
      clientSlides = [];
      host = CollaborationService()
        ..bindDocument(
          readSlides: () => hostSlides,
          applySlides: (slides) => hostSlides = _copySlides(slides),
        );
      client = CollaborationService()
        ..bindDocument(
          readSlides: () => clientSlides,
          applySlides: (slides) => clientSlides = _copySlides(slides),
        );
    });

    tearDown(() async {
      await client.stop();
      await host.stop();
      client.dispose();
      host.dispose();
    });

    test('requires authentication and does not expose wildcard CORS', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final shareUri = Uri.parse(host.getShareUrl()!);

      final unauthenticated = await _request(
        'GET',
        Uri.parse('http://127.0.0.1:${host.port}/slides'),
      );
      expect(unauthenticated.statusCode, 401);
      expect(
        unauthenticated.headers['access-control-allow-origin'],
        isNull,
      );

      final wrongToken = await client.joinSession(
        hostIp: '127.0.0.1',
        port: host.port,
        sessionToken: 'x' * 43,
        name: 'Invalid client',
      );
      expect(wrongToken, isFalse);

      final validToken = shareUri.queryParameters['token']!;
      expect(validToken.length, greaterThanOrEqualTo(32));
      expect(
        await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: validToken,
          name: 'Alice',
        ),
        isTrue,
      );
      expect(clientSlides.single['title'], 'Host title');
      expect(host.collaborators.single.name, 'Alice');
    });

    test('synchronizes complete slide snapshots in both directions', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      expect(
        await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'Editor',
        ),
        isTrue,
      );

      hostSlides = [
        _slide('Host changed', '<h1>Revision 2</h1>', notes: 'Speaker note'),
        _slide('Second slide', '<p>More content</p>'),
      ];
      host.notifyDocumentChanged();
      await _waitUntil(() => clientSlides.length == 2);
      expect(clientSlides.first['notes'], 'Speaker note');

      clientSlides = [
        _slide('Client changed', '<h1>Revision 3</h1>'),
        _slide('Second slide', '<p>More content</p>'),
      ];
      client.notifyDocumentChanged();
      // Delta sync semantics: the client changed slide 0; the untouched
      // slide 1 keeps its content (the merge is per-slide, not full replace).
      await _waitUntil(() => hostSlides.first['title'] == 'Client changed');
      expect(hostSlides.length, 2);
      expect(hostSlides[1]['title'], 'Second slide');
      expect(host.revision, greaterThanOrEqualTo(3));
    });

    test('rejects oversized request bodies before JSON processing', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      final oversizedName = 'a' * (CollaborationService.maxPayloadBytes + 1);
      try {
        final response = await _request(
          'POST',
          Uri.parse('http://127.0.0.1:${host.port}/join'),
          headers: {'x-ghita-session-token': token},
          body: jsonEncode({'name': oversizedName}),
        );
        expect(response.statusCode, 413);
        expect(jsonDecode(response.body)['error'], 'payload_too_large');
      } on HttpException catch (error) {
        // dart:io may close a connection whose declared body is rejected
        // before it finishes uploading. That is still a successful rejection.
        expect(error.message, contains('Connection closed'));
      }
    });

    test('rejects invalid slide schemas and stale revisions', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      final join = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/join'),
        headers: {'x-ghita-session-token': token},
        body: jsonEncode({'name': 'Raw client', 'color': '#123456'}),
      );
      final joinData = jsonDecode(join.body) as Map<String, dynamic>;
      final accessToken = joinData['accessToken'] as String;
      final initialRevision = joinData['revision'] as int;

      final invalid = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/sync'),
        headers: {'authorization': 'Bearer $accessToken'},
        body: jsonEncode({
          'baseRevision': initialRevision,
          'slides': [
            {'title': 'Missing HTML'}
          ],
        }),
      );
      expect(invalid.statusCode, 422);

      hostSlides = [_slide('New host revision', '<p>Authoritative</p>')];
      host.notifyDocumentChanged();
      final stale = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/sync'),
        headers: {'authorization': 'Bearer $accessToken'},
        body: jsonEncode({
          'baseRevision': initialRevision,
          'slides': [_slide('Stale edit', '<p>Must lose</p>')],
        }),
      );
      expect(stale.statusCode, 409);
      final conflict = jsonDecode(stale.body) as Map<String, dynamic>;
      expect(conflict['error'], 'revision_conflict');
      expect((conflict['slides'] as List).single['title'], 'New host revision');
    });
  });
}

Map<String, dynamic> _slide(
  String title,
  String html, {
  String? notes,
}) {
  return {
    'title': title,
    'htmlContent': html,
    'timestamp': 1,
    if (notes != null) 'notes': notes,
  };
}

List<Map<String, dynamic>> _copySlides(List<Map<String, dynamic>> slides) {
  return slides
      .map((slide) => Map<String, dynamic>.from(slide))
      .toList(growable: true);
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met within ${timeout.inSeconds} seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<_HttpResult> _request(
  String method,
  Uri uri, {
  Map<String, String> headers = const {},
  String? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(',');
    });
    return _HttpResult(response.statusCode, responseBody, responseHeaders);
  } finally {
    client.close(force: true);
  }
}

class _HttpResult {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const _HttpResult(this.statusCode, this.body, this.headers);
}
