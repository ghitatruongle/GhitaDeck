import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// A control message from a remote client (phone) or the app (Track 37, P1/P2).
class RemoteCommand {
  final String action; // next | prev | jump | setSlide | ping
  final int? slide;
  final String? token;

  const RemoteCommand({required this.action, this.slide, this.token});

  Map<String, dynamic> toMap() => {
        'action': action,
        if (slide != null) 'slide': slide,
        if (token != null) 'token': token,
      };

  static RemoteCommand fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is Map<String, dynamic>) {
        return RemoteCommand(
          action: (map['action'] ?? '').toString(),
          slide: (map['slide'] as num?)?.toInt(),
          token: map['token']?.toString(),
        );
      }
    } catch (_) {}
    return const RemoteCommand(action: '');
  }
}

/// State snapshot pushed to remote clients (Track 37, P3).
class RemoteState {
  final int currentSlide;
  final int totalSlides;
  final String notes;
  final int elapsedSeconds;

  const RemoteState({
    required this.currentSlide,
    required this.totalSlides,
    required this.notes,
    required this.elapsedSeconds,
  });

  Map<String, dynamic> toMap() => {
        'currentSlide': currentSlide,
        'totalSlides': totalSlides,
        'notes': notes,
        'elapsedSeconds': elapsedSeconds,
      };

  String toJson() => jsonEncode(toMap());
}

/// WebSocket remote-control server (Track 37).
///
/// Replaces polling with a WebSocket channel: the presenter app pushes
/// [RemoteState] snapshots and remote clients send [RemoteCommand]s
/// (next/prev/jump). Access is gated by a 32-byte session token generated at
/// start; clients must echo the token in their first message.
class RemoteControlService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final List<WebSocket> _viewers = [];
  final _random = Random.secure();
  bool _enabled = false;
  int _port = 8091;

  /// Latest presenter state (set by the presenter UI each second).
  RemoteState _state = const RemoteState(
      currentSlide: 0, totalSlides: 0, notes: '', elapsedSeconds: 0);

  /// Callback fired when a remote client issues a command.
  void Function(RemoteCommand command)? onCommand;

  /// Callback fired when a new viewer connects / disconnects (P4: count chip).
  void Function(int count)? onViewerCountChanged;

  bool get isRunning => _server != null;
  bool get enabled => _enabled;
  int get port => _port;
  int get viewerCount => _viewers.length;
  String? _token;
  String? get token => _token;

  /// Generate a 32-byte (64 hex chars) session token.
  String generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Start the WS server. [requireToken] gates control commands with the
  /// session token (viewers that only watch still need it to connect).
  Future<String?> start({
    int port = 8091,
    int maxPort = 8099,
    bool requireToken = true,
  }) async {
    _requireToken = requireToken;
    _token = generateToken();
    _enabled = true;
    for (int tryPort = port; tryPort <= maxPort; tryPort++) {
      try {
        await stop();
        _port = tryPort;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _server!.listen(_handleRequest, onError: (e) {
          debugPrint('RemoteControlService: server error: $e');
        });
        return 'ws://${await _localIp()}:$_port?token=$_token';
      } catch (e) {
        debugPrint('RemoteControlService: port $tryPort busy, trying next');
        _server = null;
        if (tryPort == maxPort) return null;
      }
    }
    return null;
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return 'localhost';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/ws') {
      final socket = await WebSocketTransformer.upgrade(request);
      final token = request.uri.queryParameters['token'] ?? '';
      final authorized = !_requireToken || token == _token;
      if (!authorized) {
        socket.add(jsonEncode({'type': 'error', 'message': 'bad_token'}));
        await socket.close();
        return;
      }
      _clients.add(socket);
      _viewers.add(socket);
      socket.add(jsonEncode({'type': 'state', 'state': _state.toMap()}));
      socket.listen(
        (data) => _onMessage(socket, data),
        onDone: () => _removeClient(socket),
        onError: (_) => _removeClient(socket),
      );
      onViewerCountChanged?.call(_viewers.length);
    } else {
      request.response
        ..statusCode = 404
        ..write('not found');
      await request.response.close();
    }
  }

  bool _requireToken = true;

  void _onMessage(WebSocket socket, dynamic data) {
    final cmd = RemoteCommand.fromJson(data.toString());
    if (cmd.action == 'ping') {
      socket.add(jsonEncode({'type': 'pong'}));
      return;
    }
    if (cmd.action == 'next' || cmd.action == 'prev' || cmd.action == 'jump') {
      onCommand?.call(cmd);
    }
  }

  void _removeClient(WebSocket socket) {
    _clients.remove(socket);
    _viewers.remove(socket);
    onViewerCountChanged?.call(_viewers.length);
  }

  /// Push the latest state to every connected remote.
  void pushState(RemoteState state) {
    _state = state;
    final payload = jsonEncode({'type': 'state', 'state': state.toMap()});
    for (final client in List.of(_clients)) {
      try {
        client.add(payload);
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    _enabled = false;
    for (final c in List.of(_clients)) {
      try {
        await c.close();
      } catch (_) {}
    }
    _clients.clear();
    _viewers.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void dispose() {
    unawaited(stop());
  }
}
