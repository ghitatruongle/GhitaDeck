import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'ai_html_guard.dart';

/// A live slide broadcast state (Track 40, OPT 33).
class BroadcastState {
  final int currentSlide;
  final int totalSlides;
  final bool allowControl;
  final bool includeNotes;
  final String notes;

  const BroadcastState({
    required this.currentSlide,
    required this.totalSlides,
    this.allowControl = false,
    this.includeNotes = false,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'currentSlide': currentSlide,
        'totalSlides': totalSlides,
        'allowControl': allowControl,
        'includeNotes': includeNotes,
        if (includeNotes && notes.isNotEmpty) 'notes': notes,
      };

  String toJson() => jsonEncode(toMap());
}

/// Local HTTP Broadcaster Service (Track 40).
///
/// Streams live slides over local Wi-Fi. Replaces the old 3s-poll page with
/// Server-Sent Events: the server pushes the current slide index the moment
/// it changes, so viewers see updates instantly with no reload flicker.
/// Optional control buttons (next/prev) when the host enables them, a viewer
/// counter, and an optional expiring one-time link.
///
/// Authentication model (T08): the share link (`?t=` or `/once?t=`) is a
/// bootstrap credential — the first page load mints an HttpOnly, SameSite=Strict
/// session cookie; all subsequent slide/SSE/control requests authenticate via
/// that cookie (or the `X-Ghita-Token` header for non-browser clients). The
/// access token is never accepted as a standing URL parameter on data endpoints.
class WifiBroadcasterService {
  HttpServer? _server;
  String _currentSlideHtml = '<h1>Waiting for presentation...</h1>';
  BroadcastState _state = const BroadcastState(
      currentSlide: 0, totalSlides: 0, allowControl: false);
  int _serverPort = 8090;
  final List<StreamController<String>> _sseClients = [];
  final List<Socket> _sseSockets = [];
  final _random = Random.secure();
  String? _accessToken;
  String? _oneTimeLink;
  DateTime? _oneTimeExpiry;

  bool get isRunning => _server != null;
  int get port => _serverPort;
  int get viewerCount => _sseClients.length;
  bool get hasOneTimeLink => _oneTimeLink != null;

  /// Callback fired when a viewer clicks next/prev on the broadcast page
  /// (only when [BroadcastState.allowControl] is true).
  void Function(String action)? onControl;

  /// Callback fired when the viewer count changes (Presenter View chip).
  void Function(int count)? onViewerCountChanged;

  /// Starts the local HTTP presentation server with automatic port fallback.
  /// [allowControl] enables next/prev buttons on the viewer page.
  Future<String?> startBroadcaster({
    int port = 8090,
    int maxPort = 8099,
    bool allowControl = false,
    bool includeNotes = false,
  }) async {
    if (port > maxPort) return null; // guard: invalid range
    await stopBroadcaster();
    _accessToken = _newToken(32);
    _state = BroadcastState(
      currentSlide: _state.currentSlide,
      totalSlides: _state.totalSlides,
      allowControl: allowControl,
      includeNotes: includeNotes,
    );
    for (int tryPort = port; tryPort <= maxPort; tryPort++) {
      try {
        _serverPort = tryPort;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _serverPort);
        debugPrint('WifiBroadcasterService running on port $_serverPort');

        _server!.listen(
          (HttpRequest request) {
            _handleBroadcastRequest(request).catchError((e) {
              debugPrint('WifiBroadcasterService: request error: $e');
            });
          },
          onError: (e) {
            debugPrint('WifiBroadcasterService: server error: $e');
          },
        );
        break;
      } catch (e) {
        debugPrint(
            'WifiBroadcasterService: Port $tryPort unavailable, trying next...');
        _server = null;
        if (tryPort == maxPort) {
          _accessToken = null;
          return null;
        }
      }
    }

    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return 'http://${addr.address}:$_serverPort/view?t=$_accessToken';
          }
        }
      }
    } catch (e) {
      debugPrint('WifiBroadcasterService Error listing interfaces: $e');
    }
    return 'http://localhost:$_serverPort/view?t=$_accessToken';
  }

  /// Create a one-time link with an expiry (Track 40, P5). The token is
  /// single-use: the first request consumes it.
  String createOneTimeLink({Duration? expiresAfter}) {
    final token = _newToken(32);
    _oneTimeLink = token;
    _oneTimeExpiry =
        expiresAfter == null ? null : DateTime.now().add(expiresAfter);
    return token;
  }

  String _newToken(int byteLength) =>
      List<int>.generate(byteLength, (_) => _random.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  bool _consumeOneTimeToken(String token) {
    if (_oneTimeLink == null) return false;
    if (_oneTimeExpiry != null && DateTime.now().isAfter(_oneTimeExpiry!)) {
      _oneTimeLink = null;
      return false;
    }
    if (token != _oneTimeLink) return false;
    final consumed = _oneTimeLink;
    _oneTimeLink = null; // single use
    return consumed != null;
  }

  /// Updates the active slide and pushes it to every SSE client instantly.
  void updateActiveSlide(
    String slideHtml, {
    int currentSlide = 0,
    int? totalSlides,
    String? notes,
  }) {
    _currentSlideHtml = AIHtmlGuard.guard(
      slideHtml,
      maxBytes: AIHtmlGuard.presentationMaxBytes,
    ).html;
    _state = BroadcastState(
      currentSlide: currentSlide,
      totalSlides: totalSlides ?? _state.totalSlides,
      allowControl: _state.allowControl,
      includeNotes: _state.includeNotes,
      notes: notes ?? _state.notes,
    );
    _broadcast();
  }

  void updateState(BroadcastState state) {
    _state = state;
    _broadcast();
  }

  void _broadcast() {
    final payload = 'data: ${jsonEncode(_payloadMap())}\n\n';
    for (final client in List.of(_sseClients)) {
      try {
        client.add(payload);
      } catch (_) {
        _sseClients.remove(client);
      }
    }
    onViewerCountChanged?.call(_sseClients.length);
  }

  Map<String, dynamic> _payloadMap() => {
        ..._state.toMap(),
        'slideHtml': _currentSlideHtml,
      };

  /// Stops the broadcast server.
  Future<void> stopBroadcaster() async {
    for (final c in List.of(_sseClients)) {
      try {
        await c.close();
      } catch (_) {}
    }
    _sseClients.clear();
    for (final s in List.of(_sseSockets)) {
      try {
        await s.close();
      } catch (_) {}
    }
    _sseSockets.clear();
    await _server?.close(force: true);
    _server = null;
    _accessToken = null;
    debugPrint('WifiBroadcasterService stopped.');
  }

  Future<void> _handleBroadcastRequest(HttpRequest request) async {
    final path = request.uri.path;
    // One-time link: must be consumed first; expired links are rejected.
    if (path == '/once') {
      final token = request.uri.queryParameters['t'] ?? '';
      if (!_consumeOneTimeToken(token)) {
        request.response
          ..statusCode = 403
          ..write('Link expired or already used');
        await request.response.close();
        return;
      }
      _setAccessCookie(request.response);
      request.response.redirect(Uri.parse('/view'));
      await request.response.close();
      return;
    }
    // T08: the share-link token (?t=) is a BOOTSTRAP credential only — valid
    // solely on the entry pages (/view or /), exactly once, to mint the
    // HttpOnly session cookie. Every later request (slide stream, control,
    // reload without the link) authenticates via the ghita_broadcast cookie
    // or the X-Ghita-Token header, so the access token stops recurring in
    // URLs, browser history and server logs.
    final viaBootstrapQuery = (path == '/view' || path == '/') &&
        _queryTokenValid(request);
    if (!viaBootstrapQuery && !_sessionAuthorized(request)) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
        ..write('Authentication required');
      await request.response.close();
      return;
    }
    if (viaBootstrapQuery) {
      _setAccessCookie(request.response);
    }
    // SSE stream (Track 40, OPT 33).
    if (path == '/events') {
      final controller = StreamController<String>();
      _sseClients.add(controller);
      onViewerCountChanged?.call(_sseClients.length);
      final response = request.response;
      response.headers.contentType = ContentType('text', 'event-stream');
      // NOTE: on this Dart build, HttpResponse.flush() never writes buffered
      // body bytes to the socket — only close() does — which would freeze the
      // stream. Workaround: detach the raw socket and write chunked frames
      // manually; Socket.flush() streams reliably and incrementally.
      Socket? detached;
      try {
        detached = await response.detachSocket();
      } catch (_) {
        _sseClients.remove(controller);
        onViewerCountChanged?.call(_sseClients.length);
        return;
      }
      final socket = detached;
      _sseSockets.add(socket);
      // Socket.flush() (this SDK) throws "StreamSink is bound to a stream" if
      // called while a previous flush is still in flight, so every frame must
      // be written through a serialized chain that awaits each flush.
      Future<void> writeChain = Future.value();
      void enqueue(String data) {
        writeChain = writeChain.then((_) async {
          try {
            final bytes = utf8.encode(data);
            socket.add(utf8.encode('${bytes.length.toRadixString(16)}\r\n'));
            socket.add(bytes);
            socket.add(utf8.encode('\r\n'));
            await socket.flush();
          } catch (e) {
            debugPrint('SSE send error: $e');
            _sseClients.remove(controller);
          }
        });
      }

      // Immediate retry hint + current state so the first push is instant.
      enqueue('retry: 2000\n\n');
      enqueue('data: ${jsonEncode(_payloadMap())}\n\n');
      final sub = controller.stream.listen(enqueue);
      socket.done.whenComplete(() {
        _sseSockets.remove(socket);
        _sseClients.remove(controller);
        onViewerCountChanged?.call(_sseClients.length);
        sub.cancel();
        controller.close();
      });
      return;
    }
    // Control endpoint (Track 40, P3) — only when the host allows it.
    if (path == '/control') {
      final action = request.uri.queryParameters['action'] ?? '';
      if (_state.allowControl && (action == 'next' || action == 'prev')) {
        onControl?.call(action);
        request.response.write('ok');
      } else {
        request.response
          ..statusCode = 403
          ..write('control disabled');
      }
      await request.response.close();
      return;
    }
    // View page.
    if (path == '/view' || path == '/') {
      request.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      request.response.headers.set(
        'Content-Security-Policy',
        "default-src 'none'; connect-src 'self'; img-src data:; "
            "font-src data:; style-src 'unsafe-inline'; "
            "script-src 'unsafe-inline'",
      );
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final allowControlJs = _state.allowControl ? 'true' : 'false';
      final htmlPage = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Live Presentation</title>
<style>
  body { font-family: system-ui, sans-serif; background: #0f172a; color: white;
         display: flex; justify-content: center; align-items: center;
         min-height: 100vh; margin: 0; padding: 24px; box-sizing: border-box; }
  .card { background: #1e293b; border-radius: 16px; padding: 32px; width: 100%;
          max-width: 900px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
  .slide { transition: opacity 0.25s ease; }
  .controls { margin-top: 16px; display: flex; gap: 12px; justify-content: center; }
  .controls button { background: #3a8fd4; border: 0; color: #fff; border-radius: 8px;
                     padding: 10px 22px; font-size: 16px; cursor: pointer; }
  .counter { position: fixed; top: 12px; right: 12px; background: #1e293b;
             border-radius: 20px; padding: 6px 12px; font-size: 12px; color: #9aa4b2; }
  .notes { margin-top: 12px; background: #24344d; border-radius: 8px; padding: 12px;
           font-size: 13px; color: #cdd6e2; white-space: pre-wrap; }
</style>
</head>
<body>
<div class="counter" id="counter">0 viewers</div>
<div class="card">
  <div class="slide" id="slide">$_currentSlideHtml</div>
  <div class="notes" id="notes" style="display:none"></div>
  <div class="controls" id="controls" style="display:none">
    <button onclick="send('prev')">&#9664; Prev</button>
    <button onclick="send('next')">Next &#9654;</button>
  </div>
</div>
<script>
  const allowControl = $allowControlJs;
  if (allowControl) document.getElementById('controls').style.display = 'flex';
  const es = new EventSource('/events');
  es.onmessage = (e) => {
    try {
       const s = JSON.parse(e.data);
       if (typeof s.slideHtml === 'string') {
         document.getElementById('slide').innerHTML = s.slideHtml;
       }
      if (s.notes) { document.getElementById('notes').style.display = 'block';
                     document.getElementById('notes').textContent = s.notes; }
    } catch (err) {}
  };
  function send(action) { fetch('/control?action=' + action).catch(() => {}); }
</script>
</body>
</html>
''';
      request.response.write(htmlPage);
      await request.response.close();
      return;
    }
    request.response
      ..statusCode = 404
      ..write('not found');
    await request.response.close();
  }

  /// The share-link query token is accepted only as a bootstrap credential
  /// (T08) — never as a standing credential for slide/control traffic.
  bool _queryTokenValid(HttpRequest request) {
    final accessToken = _accessToken;
    return accessToken != null &&
        request.uri.queryParameters['t'] == accessToken;
  }

  /// Session credentials minted after the first page load: the HttpOnly
  /// ghita_broadcast cookie (browsers send it automatically for same-origin
  /// EventSource/fetch) or the X-Ghita-Token header for non-browser clients.
  bool _sessionAuthorized(HttpRequest request) {
    final accessToken = _accessToken;
    if (accessToken == null) return false;
    if (request.headers.value('X-Ghita-Token') == accessToken) return true;
    return request.cookies.any(
      (cookie) =>
          cookie.name == 'ghita_broadcast' && cookie.value == accessToken,
    );
  }

  void _setAccessCookie(HttpResponse response) {
    final accessToken = _accessToken;
    if (accessToken == null) return;
    response.headers.add(
      HttpHeaders.setCookieHeader,
      'ghita_broadcast=$accessToken; HttpOnly; SameSite=Strict; Path=/',
    );
  }
}
