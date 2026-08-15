import 'dart:convert';

/// Per-slide rehearsal timing (Track 38, FEAT 54).
class RehearseTiming {
  final int slideIndex;
  final int durationMs;

  const RehearseTiming({required this.slideIndex, required this.durationMs});

  Map<String, dynamic> toMap() => {'slideIndex': slideIndex, 'durationMs': durationMs};

  static RehearseTiming fromMap(Map<String, dynamic> map) => RehearseTiming(
        slideIndex: (map['slideIndex'] as num?)?.toInt() ?? 0,
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      );
}

/// One rehearsal run (Track 38, P2/P3/P7).
class RehearseSession {
  final String id;
  final DateTime startedAt;
  final List<RehearseTiming> timings;

  const RehearseSession({
    required this.id,
    required this.startedAt,
    required this.timings,
  });

  int get totalMs =>
      timings.fold(0, (sum, t) => sum + t.durationMs);

  Map<String, dynamic> toMap() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'timings': timings.map((t) => t.toMap()).toList(),
      };

  static RehearseSession fromMap(Map<String, dynamic> map) => RehearseSession(
        id: (map['id'] ?? '').toString(),
        startedAt:
            DateTime.tryParse((map['startedAt'] ?? '').toString()) ?? DateTime.now(),
        timings: (map['timings'] as List? ?? const [])
            .map((e) => RehearseTiming.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// In-memory rehearsal engine (Track 38). Records per-slide timings while the
/// presenter rehearses and produces a text report.
class RehearseService {
  final Map<int, DateTime> _slideStartedAt = {};
  final List<RehearseTiming> _timings = [];
  bool _running = false;
  DateTime? _sessionStart;
  String _sessionId = '';

  bool get running => _running;
  List<RehearseTiming> get timings => List.unmodifiable(_timings);

  void start() {
    _timings.clear();
    _slideStartedAt.clear();
    _running = true;
    _sessionStart = DateTime.now();
    _sessionId = 'r_${_sessionStart!.millisecondsSinceEpoch}';
  }

  /// Call when a slide becomes active. Ends the previous slide's timing and
  /// starts a new one.
  void enterSlide(int slideIndex) {
    final now = DateTime.now();
    final previous = _slideStartedAt.keys.toList();
    if (previous.isNotEmpty) {
      final prev = previous.last;
      _timings.add(RehearseTiming(
        slideIndex: prev,
        durationMs: now.difference(_slideStartedAt[prev]!).inMilliseconds,
      ));
    }
    _slideStartedAt.clear();
    _slideStartedAt[slideIndex] = now;
  }

  void stop() {
    if (!_running) return;
    final now = DateTime.now();
    if (_slideStartedAt.isNotEmpty) {
      final prev = _slideStartedAt.keys.last;
      _timings.add(RehearseTiming(
        slideIndex: prev,
        durationMs: now.difference(_slideStartedAt[prev]!).inMilliseconds,
      ));
    }
    _slideStartedAt.clear();
    _running = false;
  }

  RehearseSession finish() {
    stop();
    return RehearseSession(
      id: _sessionId,
      startedAt: _sessionStart ?? DateTime.now(),
      timings: List.of(_timings),
    );
  }

  /// Human-readable report (Track 38, P3).
  String buildReport(RehearseSession session) {
    final b = StringBuffer();
    final totalSec = (session.totalMs / 1000).round();
    b.writeln('Rehearsal report (${session.id})');
    b.writeln('Total time: ${_fmt(totalSec)}');
    if (session.timings.isEmpty) {
      b.writeln('No slide timings recorded.');
      return b.toString();
    }
    RehearseTiming? longest;
    for (final t in session.timings) {
      if (longest == null || t.durationMs > longest.durationMs) longest = t;
    }
    b.writeln(
        'Longest slide: #${longest!.slideIndex + 1} (${_fmt((longest.durationMs / 1000).round())})');
    // Slides over 2 minutes get a "trim" recommendation.
    final slow = session.timings
        .where((t) => t.durationMs > 120000)
        .map((t) => '#${t.slideIndex + 1}')
        .toList();
    if (slow.isNotEmpty) {
      b.writeln('Consider trimming: ${slow.join(', ')}');
    }
    for (final t in session.timings) {
      b.writeln(
          'Slide ${t.slideIndex + 1}: ${_fmt((t.durationMs / 1000).round())}');
    }
    return b.toString();
  }

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String sessionsToJson(List<RehearseSession> sessions) =>
      jsonEncode(sessions.map((s) => s.toMap()).toList());

  static List<RehearseSession> sessionsFromJson(String json) {
    try {
      final list = jsonDecode(json);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(RehearseSession.fromMap)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
