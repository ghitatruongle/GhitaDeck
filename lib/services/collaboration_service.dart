import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../providers/presentation_state.dart';

/// Authenticated local-network collaboration with revisioned snapshot sync.
///
/// Transport is deliberately HTTP polling rather than pretending to provide a
/// WebSocket channel. Every protected request uses a high-entropy session or
/// collaborator token, request bodies are bounded, and stale writes are
/// rejected with the authoritative snapshot.
class CollaborationService {
  static const int maxPayloadBytes = 2 * 1024 * 1024;
  /// Maximum concurrent collaborators before the oldest is evicted. Without
  /// this, repeated /join calls grow memory and mint tokens without bound.
  static const int defaultMaxCollaborators = 20;
  static const int defaultMaxSlides = 200;
  static const int maxTitleLength = 500;
  static const int maxHtmlLength = 250000;
  static const int maxNotesLength = 50000;
  static const Duration requestTimeout = Duration(seconds: 5);
  static const Duration defaultPollInterval = Duration(milliseconds: 900);
  /// After a local edit the next poll fires almost immediately so priority
  /// events (content edits) propagate in well under a second.
  static const Duration fastPollInterval = Duration(milliseconds: 250);
  /// Poll failures back off 1s → 2s → 4s → 8s and then stay at 8s.
  static const Duration reconnectMaxBackoff = Duration(seconds: 8);
  static const int maxSyncLogEntries = 200;

  bool _disposed = false;
  HttpServer? _server;
  String? _localIp;
  int _port = 8080;
  CollaborationMode _mode = CollaborationMode.idle;
  final List<CollaboratorInfo> _collaborators = [];
  final Map<String, CollaboratorInfo> _accessTokens = {};
  /// View-only access token (separate from edit tokens — T49).
  String? _viewToken;
  final Map<String, CollaboratorInfo> _viewTokens = {};
  /// Guards against overlapping polls: the adaptive timer must not fire
  /// while a slow poll is still in flight.
  bool _polling = false;
  final StreamController<CollaborationEvent> _eventController =
      StreamController<CollaborationEvent>.broadcast();
  final Random _secureRandom = Random.secure();

  // ---- T46: tunable session config (host). --------------------------------
  int _maxCollaborators = defaultMaxCollaborators;
  int _maxSlides = defaultMaxSlides;
  final Duration _pollInterval = defaultPollInterval;
  /// When true the host refuses new joins (session is committed).
  bool _sessionLocked = false;

  // ---- T47: per-slide merge, presence, locks, history. --------------------
  /// Slide index → revision when that slide was last written.
  final Map<int, int> _slideRevisions = {};
  /// Slide index → {name, color, at} of the last writer (conflict UI).
  final Map<int, Map<String, dynamic>> _lastWriters = {};
  /// Collaborator id → {name, color, slideIndex, x, y, lastSeen}.
  final Map<String, Map<String, dynamic>> _presence = {};
  /// Slide index → collaborator id holding a soft lock.
  final Map<int, String> _locks = {};
  /// Append-only "who changed what when" log (cap [_maxSyncLogEntries]).
  final List<Map<String, dynamic>> _syncLog = [];

  String? _sessionToken;
  String? _clientAccessToken;
  String? _remoteHost;
  int? _remotePort;
  CollaborationRole _role = CollaborationRole.editor;
  int _revision = 0;
  /// Client-side mirror of the server per-slide revisions.
  final Map<int, int> _clientSlideRevisions = {};

  CollaborationRole get role => _role;
  bool get isViewer => _role == CollaborationRole.viewer;
  bool get isEditor => _role != CollaborationRole.viewer;
  String? get clientAccessToken => _clientAccessToken;
  List<Map<String, dynamic>> _slides = [];
  String _slidesFingerprint = '[]';
  PresentationState? _presentation;
  List<Map<String, dynamic>> Function()? _documentReader;
  FutureOr<void> Function(List<Map<String, dynamic>> slides)? _documentWriter;
  bool _applyingRemoteSnapshot = false;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  int _pollFailures = 0;
  Timer? _pushDebounce;
  DateTime? _lastCursorSent;

  int get maxCollaborators => _maxCollaborators;
  int get maxSlides => _maxSlides;
  Duration get pollInterval => _pollInterval;
  bool get sessionLocked => _sessionLocked;
  List<Map<String, dynamic>> get syncLog => List.unmodifiable(_syncLog);
  List<Map<String, dynamic>> get presence =>
      List.unmodifiable(_presence.values);
  Map<int, Map<String, dynamic>> get lastWriters =>
      Map.unmodifiable(_lastWriters);

  bool get isHosting => _mode == CollaborationMode.host;
  bool get isJoined => _mode == CollaborationMode.client;
  bool get isActive => _mode != CollaborationMode.idle;
  CollaborationMode get mode => _mode;
  String? get localIp => _localIp;
  int get port => _port;
  int get revision => _revision;
  List<CollaboratorInfo> get collaborators =>
      List.unmodifiable(_collaborators);
  Stream<CollaborationEvent> get eventStream => _eventController.stream;

  /// Connects collaboration to the real presentation model. Rebinding is safe
  /// and is used by ProxyProvider when the app provider tree rebuilds.
  void bindPresentation(PresentationState presentation) {
    if (identical(_presentation, presentation)) return;
    _presentation?.removeListener(_onLocalPresentationChanged);
    _presentation = presentation;
    _documentReader = () => presentation.slides
        .map((slide) => Map<String, dynamic>.from(slide.toMap()))
        .toList(growable: false);
    _documentWriter = (slides) => presentation.replaceSlidesFromCollaboration(
          slides.map(Slide.fromMap).toList(growable: false),
        );
    presentation.addListener(_onLocalPresentationChanged);
    _captureLocalSlides(incrementRevision: false);
  }

  /// Testable/adaptable document binding for non-Flutter collaboration clients.
  void bindDocument({
    required List<Map<String, dynamic>> Function() readSlides,
    required FutureOr<void> Function(List<Map<String, dynamic>> slides)
        applySlides,
  }) {
    _presentation?.removeListener(_onLocalPresentationChanged);
    _presentation = null;
    _documentReader = readSlides;
    _documentWriter = applySlides;
    _captureLocalSlides(incrementRevision: false);
  }

  /// Signals a local mutation when [bindDocument] is used instead of a
  /// [PresentationState] listener.
  void notifyDocumentChanged() => _onLocalPresentationChanged();

  Future<String?> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      _localIp = await info.getWifiIP();
      if (_localIp != null && _localIp!.isNotEmpty) return _localIp;
    } catch (e) {
      debugPrint('CollaborationService: WiFi IP lookup failed: $e');
    }
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            _localIp = address.address;
            return _localIp;
          }
        }
      }
    } catch (e) {
      debugPrint('CollaborationService: interface lookup failed: $e');
    }
    _localIp = '127.0.0.1';
    return _localIp;
  }

  /// Starts a protected host. Port zero is supported for deterministic tests.
  /// [viewToken] (optional) is a short token that grants read-only joins.
  Future<bool> startHosting({int port = 8080, String? viewToken}) async {
    if (_disposed || isActive || port < 0 || port > 65535) return false;
    try {
      _port = port;
      _localIp = await getLocalIpAddress();
      _sessionToken = _newToken(32);
      _viewToken = (viewToken != null && viewToken.isNotEmpty)
          ? viewToken
          : _newToken(8);
      _revision = 1;
      _captureLocalSlides(incrementRevision: false);

      final router = Router()
        ..get('/health', _handleHealth)
        ..post('/join', _handleJoin)
        ..get('/slides', _handleSlides)
        ..post('/sync', _handleSync)
        ..post('/presence', _handlePresence)
        ..get('/presence', _handlePresenceList)
        ..post('/lock', _handleLock)
        ..get('/history', _handleHistory)
        ..post('/kick', _handleKick)
        ..post('/session-lock', _handleSessionLock);

      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addMiddleware(_securityHeadersMiddleware())
          .addMiddleware(_gzipMiddleware())
          .addHandler(router.call);

      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
        shared: false,
      );
      _port = _server!.port;
      _mode = CollaborationMode.host;
      _emit(CollaborationEventType.sessionStarted, {
        'host': _localIp,
        'port': _port,
      });
      debugPrint('CollaborationService: protected host started on port $_port');
      return true;
    } catch (e) {
      debugPrint('CollaborationService: host start failed: $e');
      await stop();
      return false;
    }
  }

  /// View-only join URL (shares the same host/session but a short token that
  /// yields a read-only collaborator).
  String? getShareViewUrl() {
    if (!isHosting || _localIp == null || _viewToken == null) return null;
    return Uri(
      scheme: 'http',
      host: _localIp,
      port: _port,
      queryParameters: {'token': _viewToken},
    ).toString();
  }

  /// Tunable session config (OPT 36): bounds are clamped sanely.
  void updateSessionConfig({int? maxCollaborators, int? maxSlides}) {
    _maxCollaborators =
        (maxCollaborators ?? _maxCollaborators).clamp(1, 100);
    _maxSlides = (maxSlides ?? _maxSlides).clamp(1, 1000);
  }

  /// Host locks/unlocks the session: new joins are refused while locked.
  void setSessionLocked(bool locked) => _sessionLocked = locked;

  /// Host removes a collaborator (their token stops authorizing).
  Future<bool> kickCollaborator(String collaboratorId) async {
    if (!isHosting || collaboratorId.isEmpty) return false;
    final client = HttpClient()..connectionTimeout = requestTimeout;
    client.autoUncompress = false;
    try {
      final request = await client
          .post('127.0.0.1', _port, '/kick')
          .timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set('x-ghita-session-token', _sessionToken ?? '');
      request.write(jsonEncode({'collaboratorId': collaboratorId}));
      final response = await request.close().timeout(requestTimeout);
      final data = await _decodeResponseObject(response);
      return response.statusCode == 200 && data['success'] == true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    return _jsonResponse(200, {
      'status': 'ok',
      'app': 'GhitaPPT',
      'version': '2.0.0',
      'protocol': 2,
    });
  }

  Future<shelf.Response> _handleJoin(shelf.Request request) async {
    final headerToken = request.headers['x-ghita-session-token'] ?? '';
    final isViewJoin = _constantTimeEquals(headerToken, _viewToken ?? '');
    final isEditJoin = _constantTimeEquals(headerToken, _sessionToken ?? '');
    if (!isViewJoin && !isEditJoin) {
      return _errorResponse(401, 'invalid_session_token');
    }
    if (_sessionLocked && isEditJoin) {
      return _errorResponse(403, 'session_locked');
    }

    try {
      final body = await _readJsonObject(request);
      final name = (body['name'] ?? '').toString().trim();
      final color = (body['color'] ?? '#FF9800').toString();
      if (name.isEmpty || name.length > 64) {
        return _errorResponse(422, 'invalid_collaborator_name');
      }
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
        return _errorResponse(422, 'invalid_collaborator_color');
      }

      final collaborator = CollaboratorInfo(
        id: _newToken(12),
        name: name,
        color: color,
        joinedAt: DateTime.now(),
        role: isViewJoin ? CollaborationRole.viewer : CollaborationRole.editor,
      );
      final accessToken = _newToken(32);
      // Cap the collaborator list — without this, repeated /join calls grow
      // memory without bound and mint tokens that are never revoked.
      if (_collaborators.length >= _maxCollaborators) {
        final evicted = _collaborators.removeAt(0);
        _accessTokens.removeWhere((_, c) => c.id == evicted.id);
        _viewTokens.removeWhere((_, c) => c.id == evicted.id);
      }
      _collaborators.add(collaborator);
      _accessTokens[accessToken] = collaborator;
      if (isViewJoin) _viewTokens[accessToken] = collaborator;
      _emit(CollaborationEventType.userJoined, collaborator);

      return _jsonResponse(200, {
        'success': true,
        'sessionId': 'ghita_${_sessionToken!.substring(0, 12)}',
        'accessToken': accessToken,
        'revision': _revision,
        'slides': _slides,
        'role': collaborator.role.name,
        'slideRevisions': _slideRevisionsStringKeys(),
      });
    } on CollaborationPayloadException catch (e) {
      return _errorResponse(e.statusCode, e.code);
    } catch (_) {
      return _errorResponse(400, 'invalid_json');
    }
  }

  Future<shelf.Response> _handleSlides(shelf.Request request) async {
    if (!_isAuthorizedCollaborator(request)) {
      return _errorResponse(401, 'unauthorized');
    }
    // Delta poll: a client sends ?since=N and receives only the slides whose
    // per-slide revision is newer than N (the first poll after join uses the
    // full snapshot from /join, so `since` is normally set).
    final since = int.tryParse(request.url.queryParameters['since'] ?? '') ?? 0;
    final delta = <Map<String, dynamic>>[];
    for (final entry in _slideRevisions.entries) {
      if (entry.value > since && entry.key < _slides.length) {
        delta.add({'index': entry.key, 'slide': _slides[entry.key]});
      }
    }
    // Read-only: do NOT mutate server state (revision/slides) on a GET.
    // Previously this incremented _revision, racing with in-flight syncs and
    // forcing spurious 409s.
    return _jsonResponse(200, {
      'revision': _revision,
      'slides': _slides,
      'delta': delta,
      'slideRevisions': _slideRevisionsStringKeys(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<shelf.Response> _handleSync(shelf.Request request) async {
    final collab = _authorizedCollaborator(request);
    if (collab == null) return _errorResponse(401, 'unauthorized');
    if (collab.role == CollaborationRole.viewer) {
      return _errorResponse(403, 'read_only');
    }
    try {
      final body = await _readJsonObject(request);
      final baseRevision = body['baseRevision'];
      if (baseRevision is! int) {
        return _errorResponse(422, 'invalid_base_revision');
      }
      _captureLocalSlides(incrementRevision: false);

      // Delta sync: the client sends {index, slide} pairs for the slides it
      // changed. Slides not in the delta keep the server revision. This is
      // what lets two editors work on different slides without conflicts.
      final delta = body['delta'];
      final incomingSlides = <Map<String, dynamic>>[];
      final changedIndexes = <int>[];
      if (delta is List) {
        if (delta.length > _maxSlides) {
          return _errorResponse(422, 'invalid_slide_list');
        }
        final candidate = List<Map<String, dynamic>>.from(_slides);
        final conflicts = <Map<String, dynamic>>[];
        for (final item in delta) {
          if (item is! Map || item['index'] is! int || item['slide'] is! Map) {
            return _errorResponse(422, 'invalid_delta');
          }
          final index = item['index'] as int;
          if (index < 0 || index >= _maxSlides) {
            return _errorResponse(422, 'invalid_delta');
          }
          final slide = _validatedSlide(item['slide']);
          // Per-slide revision check: only slides changed by someone else
          // since this client's base revision conflict.
          final slideRev = _slideRevisions[index] ?? 1;
          if (slideRev > baseRevision) {
            conflicts.add({
              'index': index,
              ..._lastWriters[index] ?? {'name': '?', 'at': null},
            });
            continue;
          }
          // Soft lock: refuse to overwrite a slide another editor holds.
          final lockOwnerId = _locks[index];
          if (lockOwnerId != null && lockOwnerId != collab.id) {
            final owner = _collaborators
                .where((c) => c.id == lockOwnerId)
                .firstOrNull;
            return _jsonResponse(409, {
              'error': 'slide_locked',
              'index': index,
              'owner': owner?.name ?? 'another user',
              'revision': _revision,
              'slides': _slides,
            });
          }
          while (candidate.length <= index) {
            candidate.add(_emptySlide(candidate.length + 1));
          }
          candidate[index] = slide;
          changedIndexes.add(index);
        }
        if (conflicts.isNotEmpty) {
          return _jsonResponse(409, {
            'error': 'revision_conflict',
            'revision': _revision,
            'slides': _slides,
            'conflicts': conflicts,
          });
        }
        incomingSlides.addAll(candidate);
      } else {
        // Legacy full-snapshot sync (regression path kept for older clients).
        final full = _validatedSlides(body['slides']);
        if (baseRevision != _revision) {
          return _jsonResponse(409, {
            'error': 'revision_conflict',
            'revision': _revision,
            'slides': _slides,
          });
        }
        for (var i = 0; i < full.length; i++) {
          changedIndexes.add(i);
        }
        incomingSlides.addAll(full);
      }

      // Apply BEFORE committing the new revision, so an apply failure keeps
      // server state consistent (previously _revision was bumped even when
      // the document write threw, desyncing clients).
      await _applyRemoteSlides(incomingSlides);
      _revision++;
      _slides = incomingSlides;
      _slidesFingerprint = jsonEncode(_slides);
      final now = DateTime.now().toUtc().toIso8601String();
      for (final index in changedIndexes) {
        _slideRevisions[index] = _revision;
        _lastWriters[index] = {
          'name': collab.name,
          'color': collab.color,
          'at': now,
        };
        _syncLog.add({
          'at': now,
          'name': collab.name,
          'color': collab.color,
          'slideIndex': index,
          'revision': _revision,
        });
      }
      if (_syncLog.length > maxSyncLogEntries) {
        _syncLog.removeRange(0, _syncLog.length - maxSyncLogEntries);
      }
      _emit(CollaborationEventType.slideUpdated, {
        'revision': _revision,
        'slideCount': incomingSlides.length,
        'changed': changedIndexes,
        'name': collab.name,
      });
      return _jsonResponse(200, {
        'success': true,
        'revision': _revision,
        'changed': changedIndexes,
      });
    } on CollaborationPayloadException catch (e) {
      return _errorResponse(e.statusCode, e.code);
    } catch (_) {
      return _errorResponse(400, 'invalid_json');
    }
  }

  // ---- T47: presence, locks, history, moderation -------------------------

  Future<shelf.Response> _handlePresence(shelf.Request request) async {
    final collab = _authorizedCollaborator(request);
    if (collab == null) return _errorResponse(401, 'unauthorized');
    try {
      final body = await _readJsonObject(request);
      final entry = _presence.putIfAbsent(collab.id, () => {
            'name': collab.name,
            'color': collab.color,
            'slideIndex': 0,
            'x': null,
            'y': null,
            'lastSeen': DateTime.now().toUtc().toIso8601String(),
          });
      final slideIndex = body['slideIndex'];
      if (slideIndex is int && slideIndex >= 0) {
        entry['slideIndex'] = slideIndex;
      }
      final x = body['x'];
      final y = body['y'];
      if (x is num && y is num) {
        entry['x'] = x.toDouble();
        entry['y'] = y.toDouble();
      }
      entry['lastSeen'] = DateTime.now().toUtc().toIso8601String();
      return _jsonResponse(200, {'success': true});
    } catch (_) {
      return _errorResponse(400, 'invalid_json');
    }
  }

  Future<shelf.Response> _handlePresenceList(shelf.Request request) async {
    if (!_isAuthorizedCollaborator(request)) {
      return _errorResponse(401, 'unauthorized');
    }
    return _jsonResponse(200, {
      'presence': _presence.values.toList(),
      'collaborators':
          _collaborators.map((c) => c.toMap()).toList(growable: false),
    });
  }

  /// Soft lock: a collaborator can acquire/release a per-slide edit lock.
  Future<shelf.Response> _handleLock(shelf.Request request) async {
    final collab = _authorizedCollaborator(request);
    if (collab == null) return _errorResponse(401, 'unauthorized');
    if (collab.role == CollaborationRole.viewer) {
      return _errorResponse(403, 'read_only');
    }
    try {
      final body = await _readJsonObject(request);
      final index = body['slideIndex'];
      final acquire = body['acquire'] == true;
      if (index is! int || index < 0) {
        return _errorResponse(422, 'invalid_slide_index');
      }
      if (acquire) {
        final holder = _locks[index];
        if (holder != null && holder != collab.id) {
          final owner =
              _collaborators.where((c) => c.id == holder).firstOrNull;
          return _jsonResponse(409, {
            'error': 'slide_locked',
            'owner': owner?.name ?? 'another user',
          });
        }
        _locks[index] = collab.id;
      } else {
        if (_locks[index] == collab.id) _locks.remove(index);
      }
      return _jsonResponse(200, {
        'success': true,
        'locked': _locks.containsKey(index),
      });
    } catch (_) {
      return _errorResponse(400, 'invalid_json');
    }
  }

  Future<shelf.Response> _handleHistory(shelf.Request request) async {
    if (!_isAuthorizedCollaborator(request)) {
      return _errorResponse(401, 'unauthorized');
    }
    return _jsonResponse(200, {'history': _syncLog});
  }

  /// Host-only: remove a collaborator from the session.
  Future<shelf.Response> _handleKick(shelf.Request request) async {
    if (!_constantTimeEquals(
      request.headers['x-ghita-session-token'] ?? '',
      _sessionToken ?? '',
    )) {
      return _errorResponse(401, 'invalid_session_token');
    }
    try {
      final body = await _readJsonObject(request);
      final targetId = (body['collaboratorId'] ?? '').toString();
      final target = _collaborators.where((c) => c.id == targetId).firstOrNull;
      if (target == null) return _errorResponse(404, 'collaborator_not_found');
      _collaborators.remove(target);
      _accessTokens.removeWhere((_, c) => c.id == targetId);
      _viewTokens.removeWhere((_, c) => c.id == targetId);
      _presence.remove(targetId);
      _locks.removeWhere((_, holder) => holder == targetId);
      _emit(CollaborationEventType.userLeft, target);
      return _jsonResponse(200, {'success': true});
    } catch (_) {
      return _errorResponse(400, 'invalid_json');
    }
  }

  /// Host-only: lock/unlock the session (new joins refused).
  Future<shelf.Response> _handleSessionLock(shelf.Request request) async {
    if (!_constantTimeEquals(
      request.headers['x-ghita-session-token'] ?? '',
      _sessionToken ?? '',
    )) {
      return _errorResponse(401, 'invalid_session_token');
    }
    try {
      final body = await _readJsonObject(request);
      _sessionLocked = body['locked'] == true;
      return _jsonResponse(200, {'locked': _sessionLocked});
    } catch (_) {
      return _errorResponse(400, 'invalid_json');
    }
  }

  /// JSON-safe view of the per-slide revisions (JSON object keys must be
  /// strings; clients read them back as ints in [_handleJoin]/poll merge).
  Map<String, int> _slideRevisionsStringKeys() => {
        for (final entry in _slideRevisions.entries)
          '${entry.key}': entry.value,
      };

  Map<String, dynamic> _emptySlide(int index) => {
        'title': 'Slide $index',
        'htmlContent': '<h1>Slide $index</h1>',
        'notes': '',
      };

  /// Joins a host, authenticates, applies the initial snapshot, and starts
  /// revision polling. The session token comes from the host's share URL.
  Future<bool> joinSession({
    required String hostIp,
    required int port,
    required String sessionToken,
    String name = 'User',
  }) async {
    if (_disposed || isActive) return false;
    final normalizedHost = _normalizeHost(hostIp);
    if (normalizedHost == null || port < 1 || port > 65535) return false;
    // Edit tokens are 32+ chars; the short view token (≥8) is allowed so
    // view-only links can join (T49).
    if (sessionToken.length < 8 ||
        name.trim().isEmpty ||
        name.length > 64) {
      return false;
    }

    final client = HttpClient()..connectionTimeout = requestTimeout;
    client.autoUncompress = false;
    try {
      final request = await client
          .post(normalizedHost, port, '/join')
          .timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set('x-ghita-session-token', sessionToken);
      request.write(jsonEncode({
        'name': name.trim(),
        'color': _randomColor(),
      }));
      final response = await request.close().timeout(requestTimeout);
      final data = await _decodeResponseObject(response);
      if (response.statusCode != 200) return false;

      final accessToken = data['accessToken'];
      final serverRevision = data['revision'];
      if (accessToken is! String ||
          accessToken.length < 32 ||
          serverRevision is! int) {
        return false;
      }
      final initialSlides = _validatedSlides(data['slides']);
      _remoteHost = normalizedHost;
      _remotePort = port;
      _sessionToken = sessionToken;
      _clientAccessToken = accessToken;
      _role = data['role'] == 'viewer'
          ? CollaborationRole.viewer
          : CollaborationRole.editor;
      _revision = serverRevision;
      _slides = initialSlides;
      _slidesFingerprint = jsonEncode(initialSlides);
      // Per-slide revisions from the server (all at the joined revision).
      _clientSlideRevisions.clear();
      final serverSlideRevisions = data['slideRevisions'];
      if (serverSlideRevisions is Map) {
        for (final entry in serverSlideRevisions.entries) {
          final index = int.tryParse('${entry.key}');
          if (index != null && entry.value is int) {
            _clientSlideRevisions[index] = entry.value as int;
          }
        }
      }
      _mode = CollaborationMode.client;
      await _applyRemoteSlides(initialSlides);
      _schedulePoll(fastPollInterval);
      _emit(CollaborationEventType.sessionJoined, {
        'host': normalizedHost,
        'port': port,
        'revision': _revision,
        'role': _role.name,
      });
      return true;
    } catch (e) {
      debugPrint('CollaborationService: join failed: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _pollHost() async {
    if (!isJoined || _disposed || _polling) return;
    _polling = true; // Guard: skip if a prior poll is still in flight.
    try {
      // Delta poll: only ask for slides newer than our revision.
      final response = await _authorizedRequest(
        'GET',
        '/slides?since=$_revision',
      );
      if (response == null) {
        _handlePollFailure();
        return;
      }
      final data = await _decodeResponseObject(response);
      if (response.statusCode == 401) {
        _emit(CollaborationEventType.authenticationFailed, null);
        return;
      }
      if (response.statusCode != 200 || data['revision'] is! int) return;
      final serverRevision = data['revision'] as int;
      if (serverRevision <= _revision) return;
      _onReconnected();
      final serverSlides = _validatedSlides(data['slides']);
      // Merge only the delta (per-slide revisions) into our copy — an edit
      // on a different slide by another editor is applied without clobbering
      // our local unsent changes on other slides.
      final delta = data['delta'];
      if (delta is List && delta.isNotEmpty) {
        final merged = List<Map<String, dynamic>>.from(_slides);
        for (final item in delta) {
          if (item is Map &&
              item['index'] is int &&
              item['slide'] is Map) {
            final index = item['index'] as int;
            final slide = _validatedSlide(item['slide']);
            while (merged.length <= index) {
              merged.add(_emptySlide(merged.length + 1));
            }
            merged[index] = slide;
          }
        }
        _slides = merged;
        _slidesFingerprint = jsonEncode(merged);
        await _applyRemoteSlides(merged);
      } else {
        _slides = serverSlides;
        _slidesFingerprint = jsonEncode(serverSlides);
        await _applyRemoteSlides(serverSlides);
      }
      final slideRevisions = data['slideRevisions'];
      if (slideRevisions is Map) {
        for (final entry in slideRevisions.entries) {
          final index = int.tryParse('${entry.key}');
          if (index != null && entry.value is int) {
            _clientSlideRevisions[index] = entry.value as int;
          }
        }
      }
      _revision = serverRevision;
      _emit(CollaborationEventType.slideUpdated, {
        'revision': _revision,
        'slideCount': _slides.length,
      });
    } catch (e) {
      debugPrint('CollaborationService: poll response rejected: $e');
      _handlePollFailure();
    } finally {
      _polling = false;
    }
  }

  /// OPT 35 — auto re-connect with exponential backoff (1→2→4→8s). The
  /// poll timer is rescheduled with the growing delay; on recovery the
  /// revision delta is resumed naturally by the next poll.
  void _handlePollFailure() {
    if (!isJoined || _disposed) return;
    _pollFailures++;
    // 1s → 2s → 4s → 8s (capped). Shift is clamped so it never overflows.
    final shift = (_pollFailures - 1).clamp(0, 3);
    final delay = Duration(seconds: 1 << shift);
    _emit(CollaborationEventType.connectionLost, {
      'attempt': _pollFailures,
      'backoffMs': delay.inMilliseconds,
    });
    _schedulePoll(delay);
  }

  void _onReconnected() {
    if (_pollFailures > 0) {
      _pollFailures = 0;
      _emit(CollaborationEventType.reconnected, null);
    }
    _schedulePoll(_pollInterval);
  }

  /// Adaptive polling: fast interval right after an edit, slow heartbeat
  /// otherwise. A single-shot timer avoids overlapping in-flight polls.
  void _schedulePoll(Duration delay) {
    if (!isJoined || _disposed) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(delay, () => unawaited(_pollHost()));
  }

  void _onLocalPresentationChanged() {
    if (_disposed || _applyingRemoteSnapshot || !isActive) return;
    if (isHosting) {
      _captureLocalSlides(incrementRevision: true);
      return;
    }

    _pushDebounce?.cancel();
    _pushDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_pushCurrentSlides()),
    );
  }

  Future<void> _pushCurrentSlides() async {
    if (!isJoined || _disposed) return;
    // Viewers are not blocked client-side: the push goes out and the server
    // rejects it (403 read_only), so the UI can show a clear "view mode"
    // notice instead of silently swallowing the edit.
    final current = _presentationSlides();
    final fingerprint = jsonEncode(current);
    if (fingerprint == _slidesFingerprint) return;

    // Delta sync: compute the changed slide indexes vs our last-known server
    // snapshot and send only those. Unchanged slides keep server revisions.
    final delta = <Map<String, dynamic>>[];
    final length = current.length > _slides.length
        ? current.length
        : _slides.length;
    for (var i = 0; i < length; i++) {
      final before = i < _slides.length ? _slides[i] : null;
      final after = i < current.length ? current[i] : null;
      if (jsonEncode(before) == jsonEncode(after)) continue;
      if (after == null) continue;
      delta.add({'index': i, 'slide': after});
    }
    if (delta.isEmpty) {
      _slides = current;
      _slidesFingerprint = fingerprint;
      return;
    }
    try {
      final response = await _authorizedRequest(
        'POST',
        '/sync',
        body: {
          'baseRevision': _revision,
          'delta': delta,
        },
      );
      if (response == null) return;
      final data = await _decodeResponseObject(response);
      if (response.statusCode == 200 && data['revision'] is int) {
        _revision = data['revision'] as int;
        // Keep our authoritative mirror in sync with what we sent.
        final merged = List<Map<String, dynamic>>.from(_slides);
        for (final item in delta) {
          final index = item['index'] as int;
          while (merged.length <= index) {
            merged.add(_emptySlide(merged.length + 1));
          }
          merged[index] = item['slide'] as Map<String, dynamic>;
        }
        _slides = merged;
        _slidesFingerprint = fingerprint;
        _schedulePoll(fastPollInterval);
        return;
      }
      if (response.statusCode == 409 && data['revision'] is int) {
        final authoritative = _validatedSlides(data['slides']);
        _revision = data['revision'] as int;
        _slides = authoritative;
        _slidesFingerprint = jsonEncode(authoritative);
        await _applyRemoteSlides(authoritative);
        _emit(CollaborationEventType.syncConflict, {
          'revision': _revision,
          'conflicts': data['conflicts'],
          'lockedIndex': data['index'],
          'lockOwner': data['owner'],
          'error': data['error'],
        });
      } else if (response.statusCode == 401) {
        _emit(CollaborationEventType.authenticationFailed, null);
      } else if (response.statusCode == 403) {
        _emit(CollaborationEventType.readOnlyRejected, null);
      }
    } catch (e) {
      debugPrint('CollaborationService: sync failed: $e');
    }
  }

  Future<HttpClientResponse?> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final host = _remoteHost;
    final port = _remotePort;
    final token = _clientAccessToken;
    if (host == null || port == null || token == null) return null;
    final client = HttpClient()..connectionTimeout = requestTimeout;
    // Disable dart:io's transparent decompression: we advertise gzip and
    // decode ourselves, otherwise the body arrives already decompressed but
    // still carries Content-Encoding: gzip and we'd decode it twice.
    client.autoUncompress = false;
    try {
      final request = await client.open(method, host, port, path).timeout(
            requestTimeout,
          );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(requestTimeout);
      // The response owns the socket until consumed by the caller. Closing the
      // client without force allows that response stream to finish normally.
      client.close();
      return response;
    } catch (_) {
      client.close(force: true);
      return null;
    }
  }

  // ---- T47 client API -----------------------------------------------------

  /// Publish the current cursor position (throttled to ~10/s client-side).
  Future<void> sendCursor({int? slideIndex, double? x, double? y}) async {
    if (!isJoined || _disposed) return;
    final now = DateTime.now();
    if (_lastCursorSent != null &&
        now.difference(_lastCursorSent!) < const Duration(milliseconds: 100)) {
      return;
    }
    _lastCursorSent = now;
    await _authorizedRequest('POST', '/presence', body: {
      if (slideIndex != null) 'slideIndex': slideIndex,
      if (x != null && y != null) 'x': x,
      if (y != null) 'y': y,
    });
  }

  /// Soft-lock a slide for editing. Returns true when acquired.
  Future<bool> acquireSlideLock(int slideIndex) async {
    if (!isJoined || _disposed) return false;
    final response = await _authorizedRequest(
      'POST',
      '/lock',
      body: {'slideIndex': slideIndex, 'acquire': true},
    );
    if (response == null) return false;
    final data = await _decodeResponseObject(response);
    return response.statusCode == 200 && data['locked'] == true;
  }

  /// Release a soft lock held by this collaborator.
  Future<void> releaseSlideLock(int slideIndex) async {
    if (!isJoined || _disposed) return;
    await _authorizedRequest(
      'POST',
      '/lock',
      body: {'slideIndex': slideIndex, 'acquire': false},
    );
  }

  /// Fetch the sync history (who changed what, when).
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    if (!isJoined) return const [];
    final response = await _authorizedRequest('GET', '/history');
    if (response == null) return const [];
    final data = await _decodeResponseObject(response);
    final history = data['history'];
    if (history is! List) return const [];
    return history.cast<Map<String, dynamic>>();
  }

  /// Fetch live presence (cursors + collaborator list).
  Future<Map<String, dynamic>> fetchPresence() async {
    if (!isJoined) return const {};
    final response = await _authorizedRequest('GET', '/presence');
    if (response == null) return const {};
    final data = await _decodeResponseObject(response);
    return data;
  }

  Future<void> leaveSession() async {
    if (!isJoined) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _remoteHost = null;
    _remotePort = null;
    _clientAccessToken = null;
    _sessionToken = null;
    _mode = CollaborationMode.idle;
    _role = CollaborationRole.editor;
    _pollFailures = 0;
    _emit(CollaborationEventType.sessionStopped, null);
  }

  Future<void> stopHosting() async {
    if (!isHosting && _server == null) return;
    await _server?.close(force: true);
    _server = null;
    _collaborators.clear();
    _accessTokens.clear();
    _sessionToken = null;
    _mode = CollaborationMode.idle;
    _emit(CollaborationEventType.sessionStopped, null);
  }

  Future<void> stop() async {
    if (isHosting || _server != null) {
      await stopHosting();
    } else {
      await leaveSession();
    }
  }

  String? getShareUrl() {
    if (!isHosting || _localIp == null || _sessionToken == null) return null;
    return Uri(
      scheme: 'http',
      host: _localIp,
      port: _port,
      queryParameters: {'token': _sessionToken},
    ).toString();
  }

  String? get sessionTokenForDisplay => isHosting ? _sessionToken : null;

  void _captureLocalSlides({required bool incrementRevision}) {
    final current = _presentationSlides();
    final fingerprint = jsonEncode(current);
    if (fingerprint == _slidesFingerprint) return;
    // Compute the changed indexes so the host records per-slide revisions
    // (the same bookkeeping a client delta push performs).
    final length = current.length > _slides.length
        ? current.length
        : _slides.length;
    final changed = <int>[];
    for (var i = 0; i < length; i++) {
      final before = i < _slides.length ? _slides[i] : null;
      final after = i < current.length ? current[i] : null;
      if (jsonEncode(before) == jsonEncode(after)) continue;
      changed.add(i);
    }
    if (incrementRevision && isHosting && changed.isNotEmpty) _revision++;
    _slides = current;
    _slidesFingerprint = fingerprint;
    if (isHosting && changed.isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final index in changed) {
        _slideRevisions[index] = _revision;
        _lastWriters[index] = {'name': 'Host', 'color': '#1565C0', 'at': now};
        _syncLog.add({
          'at': now,
          'name': 'Host',
          'color': '#1565C0',
          'slideIndex': index,
          'revision': _revision,
        });
      }
      if (_syncLog.length > maxSyncLogEntries) {
        _syncLog.removeRange(0, _syncLog.length - maxSyncLogEntries);
      }
    }
  }

  List<Map<String, dynamic>> _presentationSlides() {
    final reader = _documentReader;
    if (reader == null) return List<Map<String, dynamic>>.from(_slides);
    return reader()
        .map((slide) => Map<String, dynamic>.from(slide))
        .toList(growable: false);
  }

  Future<void> _applyRemoteSlides(List<Map<String, dynamic>> rawSlides) async {
    final writer = _documentWriter;
    if (writer == null) return;
    _applyingRemoteSnapshot = true;
    try {
      await Future.sync(() => writer(rawSlides));
    } finally {
      _applyingRemoteSnapshot = false;
    }
  }

  List<Map<String, dynamic>> _validatedSlides(dynamic value) {
    if (value is! List || value.length > _maxSlides) {
      throw const CollaborationPayloadException(422, 'invalid_slide_list');
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      result.add(_validatedSlide(item));
    }
    return result;
  }

  Map<String, dynamic> _validatedSlide(dynamic item) {
    if (item is! Map) {
      throw const CollaborationPayloadException(422, 'invalid_slide');
    }
    final slide = Map<String, dynamic>.from(item);
    final title = slide['title'];
    final html = slide['htmlContent'];
    final notes = slide['notes'];
    if (title is! String ||
        html is! String ||
        title.length > maxTitleLength ||
        html.length > maxHtmlLength ||
        (notes != null &&
            (notes is! String || notes.length > maxNotesLength))) {
      throw const CollaborationPayloadException(422, 'invalid_slide');
    }
    // Parsing catches malformed optional fields while preserving the exact
    // map representation used by the presentation model.
    Slide.fromMap(slide);
    return slide;
  }

  Future<Map<String, dynamic>> _readJsonObject(shelf.Request request) async {
    final declaredLength = int.tryParse(
      request.headers[HttpHeaders.contentLengthHeader] ?? '',
    );
    if (declaredLength != null && declaredLength > maxPayloadBytes) {
      throw const CollaborationPayloadException(413, 'payload_too_large');
    }
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxPayloadBytes) {
        throw const CollaborationPayloadException(413, 'payload_too_large');
      }
    }
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map) {
      throw const CollaborationPayloadException(400, 'invalid_json_object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _decodeResponseObject(
    HttpClientResponse response,
  ) async {
    final bytes = <int>[];
    // Apply a read deadline per chunk: a slow-drip host must never stall the
    // poll/push/join forever. Only connect/headers had a timeout before.
    await for (final chunk in response.timeout(requestTimeout)) {
      bytes.addAll(chunk);
      if (bytes.length > maxPayloadBytes) {
        throw const CollaborationPayloadException(413, 'response_too_large');
      }
    }
    // Decompress gzip responses (we always advertise Accept-Encoding: gzip).
    final raw = response.headers.value(HttpHeaders.contentEncodingHeader);
    final payload = raw != null && raw.toLowerCase().contains('gzip')
        ? gzip.decode(bytes)
        : bytes;
    final decoded = jsonDecode(utf8.decode(payload, allowMalformed: false));
    if (decoded is! Map) {
      throw const CollaborationPayloadException(400, 'invalid_response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  bool _isAuthorizedCollaborator(shelf.Request request) {
    return _authorizedCollaborator(request) != null;
  }

  CollaboratorInfo? _authorizedCollaborator(shelf.Request request) {
    final authorization = request.headers[HttpHeaders.authorizationHeader];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return null;
    }
    final candidate = authorization.substring(7);
    for (final entry in _accessTokens.entries) {
      if (_constantTimeEquals(candidate, entry.key)) return entry.value;
    }
    for (final entry in _viewTokens.entries) {
      if (_constantTimeEquals(candidate, entry.key)) return entry.value;
    }
    return null;
  }

  String? _normalizeHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 255) return null;
    if (Uri.tryParse('http://$trimmed')?.host case final String host
        when host.isNotEmpty) {
      return host;
    }
    return null;
  }

  shelf.Middleware _securityHeadersMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        if (request.method == 'OPTIONS') {
          return _errorResponse(405, 'cors_not_supported');
        }
        final response = await innerHandler(request);
        return response.change(headers: const {
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
          'Referrer-Policy': 'no-referrer',
        });
      };
    };
  }

  /// OPT — gzip-compress JSON bodies when the client accepts it. A 2 MB
  /// snapshot typically shrinks to ~300 KB, which is what keeps LAN sync
  /// snappy on 2.4 GHz Wi-Fi without dropping the hard payload cap.
  shelf.Middleware _gzipMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final accepts = (request.headers['accept-encoding'] ?? '').toLowerCase();
        final response = await innerHandler(request);
        if (!accepts.contains('gzip')) return response;
        final bytes = await response.read().fold<List<int>>(
            <int>[], (acc, chunk) => acc..addAll(chunk));
        if (bytes.isEmpty) return response;
        final compressed = gzip.encode(bytes);
        // `change` keeps the original Content-Length (that of the plain JSON
        // body) — the compressed body has a different size, so the header must
        // be replaced or clients will truncate the stream.
        return response.change(
          body: compressed,
          headers: {
            'Content-Encoding': 'gzip',
            'Vary': 'Accept-Encoding',
            'Content-Length': '${compressed.length}',
          },
        );
      };
    };
  }

  shelf.Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return shelf.Response(
      statusCode,
      body: jsonEncode(body),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    );
  }

  shelf.Response _errorResponse(int statusCode, String code) {
    return _jsonResponse(statusCode, {'error': code});
  }

  String _newToken(int byteLength) {
    final bytes = List<int>.generate(
      byteLength,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _randomColor() {
    final value = _secureRandom.nextInt(0x1000000);
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  bool _constantTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    var difference = leftBytes.length ^ rightBytes.length;
    final length = max(leftBytes.length, rightBytes.length);
    for (var index = 0; index < length; index++) {
      final leftByte = index < leftBytes.length ? leftBytes[index] : 0;
      final rightByte = index < rightBytes.length ? rightBytes[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  void _emit(CollaborationEventType type, dynamic data) {
    if (!_disposed && !_eventController.isClosed) {
      _eventController.add(CollaborationEvent(type: type, data: data));
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _presentation?.removeListener(_onLocalPresentationChanged);
    _presentation = null;
    _documentReader = null;
    _documentWriter = null;
    _pollTimer?.cancel();
    _pushDebounce?.cancel();
    unawaited(_server?.close(force: true));
    _server = null;
    unawaited(_eventController.close());
  }
}

enum CollaborationMode { idle, host, client }

/// Role of a collaborator inside a session (T49). Hosts are created by
/// [CollaborationService.startHosting]; editors and viewers join via token.
enum CollaborationRole { host, editor, viewer }

class CollaboratorInfo {
  final String id;
  final String name;
  final String color;
  final DateTime joinedAt;
  final CollaborationRole role;

  const CollaboratorInfo({
    required this.id,
    required this.name,
    required this.color,
    required this.joinedAt,
    this.role = CollaborationRole.editor,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'joinedAt': joinedAt.toUtc().toIso8601String(),
        'role': role.name,
      };
}

enum CollaborationEventType {
  sessionStarted,
  sessionJoined,
  sessionStopped,
  userJoined,
  userLeft,
  slideUpdated,
  syncConflict,
  authenticationFailed,
  connectionLost,
  reconnected,
  readOnlyRejected,
}

class CollaborationEvent {
  final CollaborationEventType type;
  final dynamic data;

  const CollaborationEvent({required this.type, this.data});
}

class CollaborationPayloadException implements Exception {
  final int statusCode;
  final String code;

  const CollaborationPayloadException(this.statusCode, this.code);

  @override
  String toString() => 'CollaborationPayloadException($statusCode, $code)';
}
