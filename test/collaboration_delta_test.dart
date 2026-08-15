import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/collaboration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  group('T46/T47 — delta sync & co-authoring', () {
    late CollaborationService host;
    late List<Map<String, dynamic>> hostSlides;

    CollaborationService makeClient(
        List<Map<String, dynamic>> store) {
      return CollaborationService()
        ..bindDocument(
          readSlides: () => store,
          applySlides: (slides) => store
            ..clear()
            ..addAll(_copySlides(slides)),
        );
    }

    setUp(() {
      hostSlides = [
        _slide('S1', '<h1>One</h1>'),
        _slide('S2', '<h1>Two</h1>'),
        _slide('S3', '<h1>Three</h1>'),
      ];
      host = CollaborationService()
        ..bindDocument(
          readSlides: () => hostSlides,
          applySlides: (slides) => hostSlides
            ..clear()
            ..addAll(_copySlides(slides)),
        );
    });

    tearDown(() async {
      await host.stop();
      host.dispose();
    });

    test('two editors on different slides merge per-slide without conflict',
        () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;

      final aStore = <Map<String, dynamic>>[];
      final bStore = <Map<String, dynamic>>[];
      final a = makeClient(aStore);
      final b = makeClient(bStore);
      addTearDown(() async {
        await a.stop();
        await b.stop();
        a.dispose();
        b.dispose();
      });
      expect(
        await a.joinSession(
            hostIp: '127.0.0.1',
            port: host.port,
            sessionToken: token,
            name: 'A'),
        isTrue,
      );
      expect(
        await b.joinSession(
            hostIp: '127.0.0.1',
            port: host.port,
            sessionToken: token,
            name: 'B'),
        isTrue,
      );

      // Both edit different slides concurrently.
      aStore[0] = _slide('A edited', '<h1>By A</h1>');
      a.notifyDocumentChanged();
      bStore[2] = _slide('B edited', '<h1>By B</h1>');
      b.notifyDocumentChanged();

      await _waitUntil(
          () => hostSlides[0]['title'] == 'A edited' &&
              hostSlides[2]['title'] == 'B edited');
      // The untouched middle slide is preserved.
      expect(hostSlides[1]['title'], 'S2');
      // No conflict events on either client.
      expect(host.lastWriters.keys.toSet(), {0, 2});
    });

    test('stale per-slide edit conflicts and reports who changed it',
        () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;

      // Raw join (like the legacy test) so we control the base revision.
      final join = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/join'),
        headers: {'x-ghita-session-token': token},
        body: jsonEncode({'name': 'Raw', 'color': '#123456'}),
      );
      final joinData = jsonDecode(join.body) as Map<String, dynamic>;
      final accessToken = joinData['accessToken'] as String;
      final baseRevision = joinData['revision'] as int;

      // Host rewrites slide 0 first (bumps its per-slide revision).
      hostSlides[0] = _slide('Host won', '<h1>New</h1>');
      host.notifyDocumentChanged();
      await _waitUntil(() => host.revision >= 2);

      // Client edits slide 0 based on an older base revision → conflict.
      final stale = await _request(
        'POST',
        Uri.parse('http://127.0.0.1:${host.port}/sync'),
        headers: {'authorization': 'Bearer $accessToken'},
        body: jsonEncode({
          'baseRevision': baseRevision,
          'delta': [
            {'index': 0, 'slide': _slide('Client stale', '<h1>Old</h1>')},
          ],
        }),
      );
      expect(stale.statusCode, 409);
      final conflict = jsonDecode(stale.body) as Map<String, dynamic>;
      expect(conflict['error'], 'revision_conflict');
      // The conflict payload names the slide + who changed it.
      final conflicts = (conflict['conflicts'] as List).cast<Map<String, dynamic>>();
      expect(conflicts, hasLength(1));
      expect(conflicts.first['index'], 0);
      expect(conflicts.first['name'], 'Host');
      // Host's authoritative slide wins.
      expect((conflict['slides'] as List).cast<Map<String, dynamic>>().first['title'],
          'Host won');
    });

    test('view-only join is read-only (server rejects sync)', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final viewUrl = host.getShareViewUrl()!;
      final viewUri = Uri.parse(viewUrl);
      final viewToken = viewUri.queryParameters['token']!;
      final store = <Map<String, dynamic>>[];
      final viewer = makeClient(store);
      addTearDown(() async {
        await viewer.stop();
        viewer.dispose();
      });
      expect(
        await viewer.joinSession(
          hostIp: '127.0.0.1',
          port: viewUri.port == 0 ? host.port : viewUri.port,
          sessionToken: viewToken,
          name: 'Viewer',
        ),
        isTrue,
      );
      expect(viewer.isViewer, isTrue);

      final rejected = <Map<String, dynamic>>[];
      final sub = viewer.eventStream.listen((e) {
        if (e.type == CollaborationEventType.readOnlyRejected) {
          rejected.add({'r': 1});
        }
      });
      addTearDown(() => sub.cancel());

      store[0] = _slide('Viewer edit', '<h1>Nope</h1>');
      viewer.notifyDocumentChanged();
      await _waitUntil(() => rejected.isNotEmpty);
      // Host state untouched.
      expect(hostSlides[0]['title'], 'S1');
    });

    test('soft lock blocks a second editor on the same slide', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;

      final aStore = <Map<String, dynamic>>[];
      final bStore = <Map<String, dynamic>>[];
      final a = makeClient(aStore);
      final b = makeClient(bStore);
      addTearDown(() async {
        await a.stop();
        await b.stop();
        a.dispose();
        b.dispose();
      });
      await a.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'A');
      await b.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'B');

      expect(await a.acquireSlideLock(1), isTrue);
      // B cannot lock the same slide.
      expect(await b.acquireSlideLock(1), isFalse);
      // B's sync on that slide is rejected with a lock error.
      final events = <Map<String, dynamic>>[];
      final sub = b.eventStream.listen((e) {
        if (e.type == CollaborationEventType.syncConflict) {
          events.add((e.data as Map?)?.cast<String, dynamic>() ?? {});
        }
      });
      addTearDown(() => sub.cancel());
      bStore[1] = _slide('B lock edit', '<h1>Blocked</h1>');
      b.notifyDocumentChanged();
      await _waitUntil(() => events.isNotEmpty);
      expect(events.first['error'], 'slide_locked');
      expect(events.first['lockOwner'], 'A');

      await a.releaseSlideLock(1);
      expect(await b.acquireSlideLock(1), isTrue);
    });

    test('presence tracks cursor and slide; history logs edits', () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      final store = <Map<String, dynamic>>[];
      final client = makeClient(store);
      addTearDown(() async {
        await client.stop();
        client.dispose();
      });
      await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'Cursor');

      await client.sendCursor(slideIndex: 2, x: 0.5, y: 0.25);
      final presence = await client.fetchPresence();
      expect(presence['presence'], isNotEmpty);
      final entry = (presence['presence'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == 'Cursor');
      expect(entry['slideIndex'], 2);

      store[1] = _slide('Hist edit', '<h1>Edited</h1>');
      client.notifyDocumentChanged();
      await _waitUntil(
          () => hostSlides[1]['title'] == 'Hist edit' && host.revision >= 2);
      final history = await client.fetchHistory();
      expect(history, isNotEmpty);
      expect(history.last['name'], 'Cursor');
      expect(history.last['slideIndex'], 1);
    });

    test('host can kick a collaborator (their token stops working)',
        () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      final store = <Map<String, dynamic>>[];
      final client = makeClient(store);
      addTearDown(() async {
        await client.stop();
        client.dispose();
      });
      await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'KickMe');
      expect(host.collaborators, hasLength(1));

      await host.kickCollaborator(host.collaborators.single.id);
      await _waitUntil(() => host.collaborators.isEmpty);
      // Their token is no longer authorized.
      final client2 = HttpClient();
      try {
        final request =
            await client2.get('127.0.0.1', host.port, '/slides');
        request.headers.set(
            HttpHeaders.authorizationHeader, 'Bearer ${'x' * 43}');
        final response = await request.close();
        expect(response.statusCode, 401);
      } finally {
        client2.close(force: true);
      }
    });

    test('gzip compresses the poll payload (T46 OPT 33)', () async {
      // A deck with a chunky repeating body compresses well; the poll
      // response must be gzip-encoded when the client advertises it.
      final bigHtml = List.filled(80, '<p>Lorem ipsum dolor sit amet '
              'consectetur adipiscing elit sed do eiusmod tempor incididunt '
              'ut labore et dolore magna aliqua.</p>')
          .join();
      hostSlides = [
        _slide('Big', bigHtml),
        _slide('Big 2', bigHtml),
      ];
      host.notifyDocumentChanged();
      await host.startHosting(port: 0);

      // Join to obtain an access token, then poll with gzip advertised.
      final store = <Map<String, dynamic>>[];
      final client = makeClient(store);
      addTearDown(() async {
        await client.stop();
        client.dispose();
      });
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'Gzip');
      // Force a poll (the join's fast poll may already have run).
      await _waitUntil(() => store.length >= 2);
      final accessToken = client.clientAccessToken!;

      final raw = HttpClient()..autoUncompress = false;
      try {
        final request = await raw
            .get('127.0.0.1', host.port, '/slides')
            .timeout(const Duration(seconds: 5));
        request.headers
            .set(HttpHeaders.acceptEncodingHeader, 'gzip');
        request.headers.set(HttpHeaders.authorizationHeader,
            'Bearer $accessToken');
        final response = await request.close();
        final body = await response.fold<List<int>>(
            <int>[], (acc, chunk) => acc..addAll(chunk));
        expect(response.statusCode, 200);
        final enc = response.headers.value(HttpHeaders.contentEncodingHeader);
        expect(enc, 'gzip');
        // The gzip stream is small; the inflated JSON is much larger.
        final inflated = gzip.decode(body);
        expect(body.length, lessThan(inflated.length ~/ 4));
        expect(inflated.length, greaterThan(20000));
      } finally {
        raw.close(force: true);
      }
    });

    test('session lock refuses new joins but keeps existing editors',
        () async {
      expect(await host.startHosting(port: 0), isTrue);
      final token = Uri.parse(host.getShareUrl()!).queryParameters['token']!;
      final store = <Map<String, dynamic>>[];
      final client = makeClient(store);
      addTearDown(() async {
        await client.stop();
        client.dispose();
      });
      await client.joinSession(
          hostIp: '127.0.0.1',
          port: host.port,
          sessionToken: token,
          name: 'Existing');
      host.setSessionLocked(true);

      final store2 = <Map<String, dynamic>>[];
      final latecomer = makeClient(store2);
      addTearDown(() async {
        await latecomer.stop();
        latecomer.dispose();
      });
      expect(
        await latecomer.joinSession(
            hostIp: '127.0.0.1',
            port: host.port,
            sessionToken: token,
            name: 'Late'),
        isFalse,
      );
      // Existing editor still syncs fine.
      store[0] = _slide('Still works', '<h1>Yes</h1>');
      client.notifyDocumentChanged();
      await _waitUntil(() => hostSlides[0]['title'] == 'Still works');
    });
  });
}

Map<String, dynamic> _slide(String title, String html) => {
      'title': title,
      'htmlContent': html,
      'timestamp': 1,
    };

List<Map<String, dynamic>> _copySlides(List<Map<String, dynamic>> slides) =>
    slides.map((e) => Map<String, dynamic>.from(e)).toList(growable: true);

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
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
    return _HttpResult(response.statusCode, responseBody);
  } finally {
    client.close(force: true);
  }
}

class _HttpResult {
  final int statusCode;
  final String body;
  const _HttpResult(this.statusCode, this.body);
}
