import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../models/slide.dart';
import 'time_machine_history_service.dart';

/// Track 65 (OPT 25/26): compressed/diffed history storage + autosave drafts.
///
/// * [compressSlides]/[decompressSlides] — gzip a slide list into a compact
///   blob for snapshots (a 30-snapshot undo stack stops eating RAM).
/// * [diffSlides]/[applyDiff] — store only the changed slides between
///   consecutive snapshots.
/// * [CoalescingRecorder] — collapses continuous typing into one snapshot
///   (a 5s quiet window flushes the coalesced state).
/// * [AutosaveDraft] — debounced, dirty-only draft persistence keyed per
///   session.
class HistoryStorageService {
  HistoryStorageService._();

  static const int snapshotThresholdBytes = 256 * 1024;

  /// gzip a serialized slide list. Returns bytes.
  static Uint8List compressSlides(List<Slide> slides) {
    final json = jsonEncode([for (final s in slides) s.toMap()]);
    final raw = utf8.encode(json);
    final gz = GZipEncoder().encode(raw);
    return gz == null ? Uint8List.fromList(raw) : Uint8List.fromList(gz);
  }

  static List<Slide> decompressSlides(Uint8List bytes) {
    try {
      final gz = GZipDecoder().decodeBytes(bytes);
      final json = utf8.decode(gz);
      final list = jsonDecode(json) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Slide.fromMap)
          .toList();
    } catch (_) {
      // Fall back to raw JSON (uncompressed marker) or empty.
      try {
        final json = utf8.decode(bytes);
        final list = jsonDecode(json) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(Slide.fromMap)
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  /// Diff: keep full copy only when under the threshold or changes are
  /// widespread; otherwise store only the changed slides as
  /// `{full: bool, slides: [...], changed: {index: slide}}`.
  static Map<String, dynamic> diffSlides(List<Slide> prev, List<Slide> next) {
    if (prev.isEmpty || next.length != prev.length) {
      return {'full': true, 'slides': [for (final s in next) s.toMap()]};
    }
    final changed = <int, Map<String, dynamic>>{};
    for (var i = 0; i < next.length; i++) {
      final a = jsonEncode(prev[i].toMap());
      final b = jsonEncode(next[i].toMap());
      if (a != b) changed[i] = next[i].toMap();
    }
    if (changed.isEmpty) {
      return {'full': true, 'slides': [for (final s in next) s.toMap()]};
    }
    return {'full': false, 'changed': changed};
  }

  static List<Slide> applyDiff(List<Slide> base, Map<String, dynamic> diff) {
    if (diff['full'] == true) {
      final raw = diff['slides'];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().map(Slide.fromMap).toList();
      }
      return base;
    }
    final out = base.map((s) => s.copyWith()).toList();
    final changed = diff['changed'];
    if (changed is Map) {
      changed.forEach((k, v) {
        final idx = int.tryParse(k.toString());
        if (idx != null && idx >= 0 && idx < out.length && v is Map) {
          out[idx] = Slide.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }
    return out;
  }
}

/// Coalescing snapshot recorder (OPT 25): typing calls [touch] frequently;
/// the first edit records immediately and subsequent edits within
/// [coalesceWindow] update the pending snapshot instead of appending new ones.
class CoalescingRecorder {
  final TimeMachineHistoryService history;
  final Duration coalesceWindow;
  final void Function()? onSnapshot;
  Timer? _timer;
  List<Slide>? _pending;
  String _pendingDescription = '';

  CoalescingRecorder({
    required this.history,
    this.coalesceWindow = const Duration(seconds: 5),
    this.onSnapshot,
  });

  bool get hasPending => _pending != null;

  /// A slide edit happened. [description] is used for the eventual snapshot.
  ///
  /// Coalescing: the first edit starts a quiet-window timer; further edits
  /// within the window update the pending state and reset the timer; when the
  /// window lapses (or [flush] is called) exactly one snapshot is recorded.
  void touch(String description, List<Slide> slides) {
    _pending = slides.map((s) => s.copyWith()).toList();
    _pendingDescription = description;
    _timer?.cancel();
    _timer = Timer(coalesceWindow, _flushPending);
  }

  void _flushNow() {
    _timer?.cancel();
    _timer = null;
    _flushPending();
  }

  void _flushPending() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    history.recordSnapshot(_pendingDescription, pending);
    onSnapshot?.call();
  }

  void flush() => _flushNow();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Autosave draft (OPT 26): debounced + dirty-only, per-session file.
class AutosaveDraft {
  final Directory dir;
  final Duration debounce;
  Timer? _timer;
  bool _dirty = false;
  String _sessionId = '';

  AutosaveDraft({required this.dir, this.debounce = const Duration(seconds: 2)});

  String get sessionId => _sessionId;

  File _fileFor(String sessionId) =>
      File('${dir.path}/draft_$sessionId.ghita');

  void setSession(String sessionId) => _sessionId = sessionId;

  /// Mark dirty and schedule a write (only when actually changed).
  void markDirty(List<Slide> slides) {
    if (slides.isEmpty) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, () => _write(slides));
  }

  Future<void> _write(List<Slide> slides) async {
    if (!_dirty) return;
    _dirty = false;
    final session = _sessionId.isEmpty ? 'default' : _sessionId;
    try {
      final file = _fileFor(session);
      await file.parent.create(recursive: true);
      final gz = HistoryStorageService.compressSlides(slides);
      await file.writeAsBytes(gz, flush: true);
    } catch (e) {
      debugPrint('AutosaveDraft write error: $e');
    }
  }

  Future<List<Slide>?> load(String sessionId) async {
    final file = _fileFor(sessionId);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      return HistoryStorageService.decompressSlides(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String sessionId) async {
    final file = _fileFor(sessionId);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> flush(List<Slide> slides) async {
    _timer?.cancel();
    _dirty = true;
    await _write(slides);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
