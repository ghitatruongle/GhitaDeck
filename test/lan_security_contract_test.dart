import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/auth_service.dart';
import 'package:ghita_deck/services/collaboration_service.dart';
import 'package:ghita_deck/services/remote_control_service.dart';
import 'package:ghita_deck/services/wifi_broadcaster_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);
  tearDownAll(() => HttpOverrides.global = null);

  group('T1.5 shared secret comparison', () {
    test('secureEquals accepts equal secrets and rejects the rest', () {
      expect(AuthService.secureEquals('secret-a', 'secret-a'), isTrue);
      expect(AuthService.secureEquals('secret-a', 'secret-b'), isFalse);
      expect(AuthService.secureEquals('secret-a', 'secret-ab'), isFalse);
      expect(AuthService.secureEquals('', ''), isTrue);
    });

    test('mintToken defaults to 16 random bytes with a role prefix', () {
      final token = AuthService.mintToken('editor');
      expect(token.length, 2 + 16 * 2);
      expect(AuthService.roleOfToken(token), 'editor');
      expect(token, isNot(AuthService.mintToken('editor')));
    });
  });

  group('T1.3 opaque session id', () {
    test('/join returns a sha256-derived id without token material', () async {
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final sessionToken = await _exchangeAndJoinToken(host);
      final join = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/join'),
        headers: {'x-ghita-session-token': sessionToken},
        body: jsonEncode({'name': 'Probe', 'color': '#123456'}),
      );
      expect(join.statusCode, 200);
      final data = jsonDecode(join.body) as Map<String, dynamic>;
      final expected = 'ghita_${crypto.sha256
          .convert(utf8.encode(sessionToken))
          .toString()
          .substring(0, 12)}';
      expect(data['sessionId'], expected);
      expect(data['sessionId'], isNot(contains(sessionToken.substring(0, 12))));
    });
  });

  group('T1.4 one-time bootstrap share URL', () {
    test('share URL never embeds the long-lived edit token', () async {
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final bootstrap = Uri.parse(host.getShareUrl()!)
          .queryParameters['token']!;
      expect(bootstrap, isNot(host.sessionTokenForDisplay));
      expect(bootstrap.length, greaterThanOrEqualTo(32));
    });

    test('bootstrap redeems once; replays are rejected', () async {
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final bootstrap = Uri.parse(host.getShareUrl()!)
          .queryParameters['token']!;

      final first = await _exchange(host.port, bootstrap);
      expect(first.statusCode, 200);
      final sessionToken =
          (jsonDecode(first.body) as Map<String, dynamic>)['sessionToken']
              as String;
      expect(sessionToken.length, greaterThanOrEqualTo(32));

      final replay = await _exchange(host.port, bootstrap);
      expect(replay.statusCode, 401);
      expect(jsonDecode(replay.body)['error'], 'invalid_bootstrap_token');

      final join = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/join'),
        headers: {'x-ghita-session-token': sessionToken},
        body: jsonEncode({'name': 'Editor', 'color': '#123456'}),
      );
      expect(join.statusCode, 200);

      final refreshed = Uri.parse(host.getShareUrl()!)
          .queryParameters['token']!;
      expect(refreshed, isNot(bootstrap));
      final second = await _exchange(host.port, refreshed);
      expect(second.statusCode, 200);
    });

    test('rotateShareLink invalidates the outstanding bootstrap', () async {
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final before = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      final rotated =
          Uri.parse(host.rotateShareLink()!).queryParameters['token']!;
      expect(rotated, isNot(before));
      final stale = await _exchange(host.port, before);
      expect(stale.statusCode, 401);
      final fresh = await _exchange(host.port, rotated);
      expect(fresh.statusCode, 200);
    });

    test('session lifetime is 60 minutes and slides on activity', () async {
      expect(
        CollaborationService.sessionLifetime,
        const Duration(minutes: 60),
      );
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final before = await _expiresAt(host.port);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final bootstrap = Uri.parse(host.getShareUrl()!)
          .queryParameters['token']!;
      final exchangeBody = await _exchange(host.port, bootstrap);
      final sessionToken =
          (jsonDecode(exchangeBody.body) as Map<String, dynamic>)['sessionToken']
              as String;
      final join = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/join'),
        headers: {'x-ghita-session-token': sessionToken},
        body: jsonEncode({'name': 'Slider', 'color': '#123456'}),
      );
      expect(join.statusCode, 200);
      final accessToken =
          (jsonDecode(join.body) as Map<String, dynamic>)['accessToken']
              as String;
      final poll = await _request(
        'GET',
        Uri.parse('http://127.0.0.1:${host.port}/slides'),
        headers: {'authorization': 'Bearer $accessToken'},
      );
      expect(poll.statusCode, 200);
      final after = await _expiresAt(host.port);
      expect(after.isAfter(before), isTrue);
    });
  });

  group('T1.6 rate limiting', () {
    test('/join throttles repeated failures and recovers', () async {
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final joinUri = Uri.parse('http://127.0.0.1:${host.port}/join');
      for (var i = 0; i < 3; i++) {
        final rejected = await _request(
          'POST',
          joinUri,
          headers: {'x-ghita-session-token': 'wrong-token-value'},
          body: jsonEncode({'name': 'X', 'color': '#123456'}),
        );
        expect(rejected.statusCode, 401);
      }
      final throttled = await _request(
        'POST',
        joinUri,
        headers: {'x-ghita-session-token': 'wrong-token-value'},
        body: jsonEncode({'name': 'X', 'color': '#123456'}),
      );
      expect(throttled.statusCode, 429);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final recovered = await _request(
        'POST',
        joinUri,
        headers: {'x-ghita-session-token': 'wrong-token-value'},
        body: jsonEncode({'name': 'X', 'color': '#123456'}),
      );
      expect(recovered.statusCode, 401);
    });

    test('broadcaster throttles repeated unauthorized views', () async {
      final svc = WifiBroadcasterService();
      final url = await svc.startBroadcaster(
        port: 8055,
        maxPort: 8059,
        bindAddress: '127.0.0.1',
      );
      expect(url, isNotNull);
      addTearDown(svc.stopBroadcaster);
      final view = Uri.parse('http://127.0.0.1:${svc.port}/view');
      for (var i = 0; i < 3; i++) {
        final rejected = await _request('GET', view);
        expect(rejected.statusCode, 401);
      }
      final throttled = await _request('GET', view);
      expect(throttled.statusCode, 429);
    });

    test('remote /ws throttles repeated bad handshakes', () async {
      final svc = RemoteControlService();
      final url = await svc.start(
        port: 8095,
        maxPort: 8099,
        requireToken: true,
        bindAddress: '127.0.0.1',
      );
      expect(url, isNotNull);
      addTearDown(svc.stop);
      final client = HttpClient()..findProxy = (u) => 'DIRECT';
      try {
        for (var i = 0; i < 3; i++) {
          final ws = await WebSocket.connect(
            'ws://127.0.0.1:${svc.port}/ws',
            customClient: client,
          ).timeout(const Duration(seconds: 5));
          final message = await ws.first.timeout(const Duration(seconds: 5));
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          expect(data['message'], 'bad_token');
          await ws.close();
        }
        final handshake = await client
            .get('127.0.0.1', svc.port, '/ws')
            .timeout(const Duration(seconds: 5));
        final response = await handshake.close();
        expect(response.statusCode, 429);
      } finally {
        client.close(force: true);
      }
    });
  });

  group('T1.7 health disclosure', () {
    test('/health hides app identity but keeps the protocol version',
        () async {
      final host = _makeHost();
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final health = await _request(
        'GET',
        Uri.parse('http://127.0.0.1:${host.port}/health'),
      );
      expect(health.statusCode, 200);
      final data = jsonDecode(health.body) as Map<String, dynamic>;
      expect(data['app'], isNull);
      expect(data['version'], isNull);
      expect(data['protocol'], isNotNull);
      expect(data['status'], 'ok');
    });
  });

  group('T2.4 slide html guard', () {
    test('client sanitizes dirty slide html received on join', () async {
      const dirty = '<p onclick="evil()">hi</p><script>alert(1)</script>';
      final hostSlides = [
        {'title': 'Dirty', 'htmlContent': dirty, 'timestamp': 1},
      ];
      final host = CollaborationService()
        ..bindDocument(
          readSlides: () => hostSlides,
          applySlides: (slides) {},
        );
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final bootstrap = Uri.parse(host.getShareUrl()!)
          .queryParameters['token']!;
      final store = <Map<String, dynamic>>[];
      final client = CollaborationService()
        ..bindDocument(
          readSlides: () => store,
          applySlides: (slides) => store
            ..clear()
            ..addAll(slides.map((e) => Map<String, dynamic>.from(e))),
        );
      addTearDown(() async {
        await client.stop();
        client.dispose();
      });
      expect(
        await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: bootstrap,
          name: 'Client',
        ),
        isTrue,
      );
      await _waitUntil(() => store.isNotEmpty);
      final html = store.single['htmlContent'] as String;
      expect(html.contains('script'), isFalse);
      expect(html.contains('onclick'), isFalse);
      expect(html.contains('hi'), isTrue);
    });

    test('server sanitizes dirty deltas before storing them', () async {
      final hostSlides = <Map<String, dynamic>>[
        {'title': 'S1', 'htmlContent': '<h1>One</h1>', 'timestamp': 1},
      ];
      final host = CollaborationService()
        ..bindDocument(
          readSlides: () => hostSlides,
          applySlides: (slides) => hostSlides
            ..clear()
            ..addAll(slides.map((e) => Map<String, dynamic>.from(e))),
        );
      addTearDown(() async {
        await host.stop();
        host.dispose();
      });
      expect(await host.startHosting(port: 0, bindAddress: '127.0.0.1'), isTrue);
      final sessionToken = await _exchangeAndJoinToken(host);
      final join = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/join'),
        headers: {'x-ghita-session-token': sessionToken},
        body: jsonEncode({'name': 'Editor', 'color': '#123456'}),
      );
      final joinData = jsonDecode(join.body) as Map<String, dynamic>;
      final accessToken = joinData['accessToken'] as String;
      final baseRevision = joinData['revision'] as int;

      final sync = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/sync'),
        headers: {'authorization': 'Bearer $accessToken'},
        body: jsonEncode({
          'baseRevision': baseRevision,
          'delta': [
            {
              'index': 1,
              'slide': {
                'title': 'Injected',
                'htmlContent':
                    '<img src="x" onerror="alert(1)"><script>bad()</script>',
                'timestamp': 1,
              },
            },
          ],
        }),
      );
      expect(sync.statusCode, 200);
      final stored = hostSlides[1]['htmlContent'] as String;
      expect(stored.contains('script'), isFalse);
      expect(stored.contains('onerror'), isFalse);
    });
  });
}

CollaborationService _makeHost() {
  final slides = <Map<String, dynamic>>[];
  return CollaborationService()
    ..bindDocument(
      readSlides: () => slides,
      applySlides: (incoming) => slides
        ..clear()
        ..addAll(incoming.map((e) => Map<String, dynamic>.from(e))),
    );
}

Future<_HttpResult> _exchange(int port, String bootstrap) async {
  return _request(
    'POST',
    Uri.parse('http://127.0.0.1:$port/exchange'),
    body: jsonEncode({'token': bootstrap}),
  );
}

Future<String> _exchangeAndJoinToken(CollaborationService host) async {
  final bootstrap =
      Uri.parse(host.getShareUrl()!).queryParameters['token']!;
  final data = await _bodyOf(await _exchange(host.port, bootstrap));
  return data['sessionToken'] as String;
}

Future<DateTime> _expiresAt(int port) async {
  final health = await _request(
    'GET',
    Uri.parse('http://127.0.0.1:$port/health'),
  );
  final data = jsonDecode(health.body) as Map<String, dynamic>;
  return DateTime.parse(data['expiresAt'] as String);
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
    await Future<void>.delayed(const Duration(milliseconds: 25));
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
    return _HttpResult(response.statusCode, responseBody);
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _bodyOf(_HttpResult result) async {
  return jsonDecode(result.body) as Map<String, dynamic>;
}

class _HttpResult {
  final int statusCode;
  final String body;

  const _HttpResult(this.statusCode, this.body);
}
