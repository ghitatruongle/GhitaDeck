import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/wifi_broadcaster_service.dart';

/// Track 40 tests — Real-time broadcast via SSE (FEAT 64 + OPT 33).
void main() {
  late WifiBroadcasterService svc;
  late String base;
  late String accessToken;

  setUp(() async {
    svc = WifiBroadcasterService();
    final url = await svc.startBroadcaster(port: 8050, allowControl: true);
    expect(url, isNotNull);
    accessToken = Uri.parse(url!).queryParameters['t']!;
    // Tests connect via loopback (the returned LAN IP may be unreachable in
    // the sandbox); the port is what matters.
    base = 'http://127.0.0.1:${svc.port}';
  });

  tearDown(() => svc.stopBroadcaster());

  HttpClient directClient() => HttpClient()..findProxy = (_) => 'DIRECT';

  Future<HttpClientResponse> get(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return directClient()
        .getUrl(Uri.parse('$base$path${separator}t=$accessToken'))
        .then((r) => r.close());
  }

  test('endpoints reject requests without an access token', () async {
    final resp = await directClient()
        .getUrl(Uri.parse('$base/view'))
        .then((r) => r.close());
    expect(resp.statusCode, 401);
  });

  /// Read SSE frames until the buffer contains [needle] (or timeout), then
  /// close. The server writes each frame as its own chunk, so accumulate.
  Future<String> readUntil(HttpClientResponse resp, String needle) async {
    final completer = Completer<String>();
    final sb = StringBuffer();
    final sub = resp.listen(
        (data) {
          sb.write(utf8.decode(data));
          if (sb.toString().contains(needle) && !completer.isCompleted) {
            completer.complete(sb.toString());
          }
        },
        onError: (_) {},
        onDone: () {
          if (!completer.isCompleted) completer.complete(sb.toString());
        });
    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () {
      sub.cancel();
      resp.detachSocket();
      return sb.toString();
    });
  }

  test('view page serves HTML with EventSource (no reload flicker)', () async {
    final resp = await get('/view');
    final body = await resp.transform(utf8.decoder).join();
    expect(resp.statusCode, 200);
    expect(body, contains('EventSource'));
    expect(body, contains('/events'));
  });

  test('SSE endpoint pushes current state on connect', () async {
    final resp = await get('/events');
    expect(resp.statusCode, 200);
    expect(resp.headers.contentType?.mimeType, 'text/event-stream');
    final text = await readUntil(resp, 'data:');
    expect(text, contains('data:'));
    expect(text, contains('currentSlide'));
  });

  test('SSE pushes slide updates live without reconnect', () async {
    final resp = await get('/events');
    final sb = StringBuffer();
    final sawInitial = Completer<String>();
    final sawUpdate = Completer<String>();
    final sub = resp.listen((data) {
      sb.write(utf8.decode(data));
      final t = sb.toString();
      if (t.contains('"currentSlide":0') && !sawInitial.isCompleted) {
        sawInitial.complete(t);
      }
      if (t.contains('"currentSlide":1') && !sawUpdate.isCompleted) {
        sawUpdate.complete(t);
      }
    }, onError: (_) {});
    final initial = await sawInitial.future
        .timeout(const Duration(seconds: 3), onTimeout: () => sb.toString());
    expect(initial, contains('"currentSlide":0'));
    svc.updateActiveSlide('<h1>s2</h1>', currentSlide: 1);
    final updated = await sawUpdate.future
        .timeout(const Duration(seconds: 3), onTimeout: () => sb.toString());
    expect(updated, contains('"currentSlide":1'));
    expect(updated, contains('"slideHtml":"<h1>s2</h1>"'));
    await sub.cancel();
    resp.detachSocket();
  });

  test('viewer count tracks connected SSE clients', () async {
    final before = svc.viewerCount;
    final resp = await get('/events');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(svc.viewerCount, greaterThanOrEqualTo(before + 1));
    resp.detachSocket();
  });

  test('control endpoint accepts next when allowControl is on', () async {
    final resp = await get('/control?action=next');
    final body = await resp.transform(utf8.decoder).join();
    expect(resp.statusCode, 200);
    expect(body, 'ok');
  });

  test('control blocked when disabled', () async {
    final svc2 = WifiBroadcasterService();
    final url = await svc2.startBroadcaster(port: 8060, allowControl: false);
    final token = Uri.parse(url!).queryParameters['t'];
    final resp = await directClient()
        .getUrl(Uri.parse('http://127.0.0.1:8060/control?action=next&t=$token'))
        .then((r) => r.close());
    expect(resp.statusCode, 403);
    await svc2.stopBroadcaster();
  });

  test('one-time link is single use', () async {
    final svc2 = WifiBroadcasterService();
    await svc2.startBroadcaster(port: 8070, allowControl: false);
    final token = svc2.createOneTimeLink();
    final res1 = await directClient()
        .getUrl(Uri.parse('http://127.0.0.1:8070/once?t=$token'))
        .then((r) => r.close());
    // Followed the redirect to the view page (and consumed the token).
    expect(res1.redirects.any((r) => r.location.path == '/view'), isTrue);
    final res2 = await directClient()
        .getUrl(Uri.parse('http://127.0.0.1:8070/once?t=$token'))
        .then((r) => r.close());
    expect(res2.statusCode, 403);
    await svc2.stopBroadcaster();
  });

  test('expired one-time link is rejected', () async {
    final svc2 = WifiBroadcasterService();
    await svc2.startBroadcaster(port: 8071, allowControl: false);
    final token =
        svc2.createOneTimeLink(expiresAfter: const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final res = await directClient()
        .getUrl(Uri.parse('http://127.0.0.1:8071/once?t=$token'))
        .then((r) => r.close());
    expect(res.statusCode, 403);
    await svc2.stopBroadcaster();
  });

  test('BroadcastState serializes notes only when included', () {
    const s = BroadcastState(
        currentSlide: 2,
        totalSlides: 5,
        allowControl: true,
        includeNotes: true,
        notes: 'hi');
    final map = jsonDecode(s.toJson()) as Map<String, dynamic>;
    expect(map['currentSlide'], 2);
    expect(map['notes'], 'hi');
    const withoutNotes = BroadcastState(currentSlide: 1, totalSlides: 2);
    final map2 = jsonDecode(withoutNotes.toJson()) as Map<String, dynamic>;
    expect(map2.containsKey('notes'), isFalse);
  });
}
