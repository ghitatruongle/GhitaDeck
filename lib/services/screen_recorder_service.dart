/// Screen recording service (Track 12, FEAT 7): captures the Windows
/// desktop through FFmpeg's `gdigrab` backend (no plugin, no admin rights —
/// requires ffmpeg/ffprobe on PATH, the same optional dependency Track 11
/// uses). Full screen / window / custom region, pause via segment split +
/// lossless concat, duration/size caps and a disk-free warning.
library;

import 'dart:async';
import 'dart:io';

import 'video_embed_service.dart';

/// Capture target mode.
enum CaptureMode { fullScreen, window, region }

/// Why the session ended (Stop pressed, or a cap reached).
enum RecorderStopReason { manual, maxDuration, maxSize }

/// Live status emitted every second while recording.
class RecorderStatus {
  const RecorderStatus({
    required this.elapsedSeconds,
    required this.sizeBytes,
    required this.paused,
    this.autoStopped = false,
    this.reason = RecorderStopReason.manual,
  });

  final int elapsedSeconds;
  final int sizeBytes;
  final bool paused;
  final bool autoStopped;
  final RecorderStopReason reason;
}

/// One finished recording: the final mp4 path plus probed metadata.
class RecordedVideo {
  const RecordedVideo({
    required this.path,
    required this.durationMs,
    required this.sizeBytes,
  });

  final String path;
  final int durationMs;
  final int sizeBytes;
}

/// Capture geometry for one session.
class CaptureTarget {
  const CaptureTarget.fullScreen() : mode = CaptureMode.fullScreen, windowTitle = null, regionX = null, regionY = null, regionW = null, regionH = null;
  const CaptureTarget.window(String this.windowTitle)
      : mode = CaptureMode.window, regionX = null, regionY = null, regionW = null, regionH = null;
  const CaptureTarget.region(int this.regionX, int this.regionY, int this.regionW, int this.regionH)
      : mode = CaptureMode.region, windowTitle = null;

  final CaptureMode mode;
  final String? windowTitle;
  final int? regionX;
  final int? regionY;
  final int? regionW;
  final int? regionH;
}

class ScreenRecorderService {
  ScreenRecorderService({
    this.maxDurationSeconds = defaultMaxDurationSeconds,
    this.maxFileSizeBytes = defaultMaxFileSizeBytes,
  });

  static const int defaultMaxDurationSeconds = 300;
  static const int defaultMaxFileSizeBytes = 100 * 1024 * 1024;
  static const int diskLowWarningMb = 500;

  final int maxDurationSeconds;
  final int maxFileSizeBytes;

  Process? _process;
  String? _sessionDir;
  final List<String> _segments = [];
  Timer? _ticker;
  final StreamController<RecorderStatus> _status =
      StreamController<RecorderStatus>.broadcast();
  int _elapsedSeconds = 0;
  bool _paused = false;
  bool _capHit = false;
  CaptureTarget? _target;

  Stream<RecorderStatus> get statusStream => _status.stream;
  bool get isRecording => _process != null;
  bool get isPaused => _paused;

  // ---- Capability probes ------------------------------------------------

  /// Whether ffmpeg is on PATH (reuses the Track 11 probe).
  static Future<bool> ffmpegAvailable() => VideoEmbedService.ffmpegAvailable();

  /// Visible window titles (windows with a non-empty MainWindowTitle).
  static Future<List<String>> listWindowTitles() async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        // Raw strings: PowerShell's $_ must not be Dart-interpolated.
        r'Get-Process | Where-Object { $_.MainWindowTitle } | '
            r'ForEach-Object { $_.MainWindowTitle }',
      ]);
      if (r.exitCode != 0) return const [];
      return (r.stdout as String)
          .split('\r\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Free space on [drive] in MB, or null when unavailable.
  static Future<int?> checkDiskFreeMb([String drive = 'C']) async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "(Get-PSDrive '$drive').Free / 1MB",
      ]);
      final value = double.tryParse((r.stdout as String).trim());
      return value?.round();
    } catch (_) {
      return null;
    }
  }

  // ---- Pure command/plan builders (unit-tested) -------------------------

  /// FFmpeg arguments for one gdigrab segment of [target].
  static List<String> buildCaptureCommand({
    required CaptureTarget target,
    required String outputPath,
    int framerate = 15,
  }) {
    final args = <String>[
      '-y',
      '-f', 'gdigrab',
      '-framerate', '$framerate',
    ];
    switch (target.mode) {
      case CaptureMode.fullScreen:
        args.addAll(['-i', 'desktop']);
      case CaptureMode.window:
        args.addAll(['-i', 'title=${target.windowTitle}']);
      case CaptureMode.region:
        args.addAll([
          '-offset_x', '${target.regionX}',
          '-offset_y', '${target.regionY}',
          '-video_size', '${target.regionW}x${target.regionH}',
          '-i', 'desktop',
        ]);
    }
    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-pix_fmt', 'yuv420p',
      outputPath,
    ]);
    return args;
  }

  /// Content of the concat list file (`file '…'` per segment).
  static String buildConcatList(List<String> segments) => segments
      .map((s) => "file '${s.replaceAll("'", "'\\''")}'")
      .join('\n');

  // ---- Lifecycle --------------------------------------------------------

  /// Begin a new recording of [target]. Returns null on success, or an
  /// error message (missing ffmpeg, bad target, already recording).
  Future<String?> start({
    required CaptureTarget target,
    required String outputPath,
  }) async {
    if (_process != null) return 'already recording';
    if (target.mode == CaptureMode.window &&
        (target.windowTitle == null || target.windowTitle!.isEmpty)) {
      return 'window title required';
    }
    if (target.mode == CaptureMode.region &&
        (target.regionW == null ||
            target.regionW! <= 0 ||
            target.regionH == null ||
            target.regionH! <= 0)) {
      return 'region size required';
    }
    if (!await ffmpegAvailable()) {
      return 'ffmpeg not found';
    }
    _target = target;
    _capHit = false;
    final dir = Directory(
        '${Directory.systemTemp.path}/ghita_rec_${DateTime.now().millisecondsSinceEpoch}');
    await dir.create(recursive: true);
    _sessionDir = dir.path;
    _segments.clear();
    _elapsedSeconds = 0;
    _paused = false;
    final error = await _startSegment();
    if (error != null) {
      _cleanupSession();
      return error;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return null;
  }

  Future<String?> _startSegment() async {
    final target = _target;
    if (target == null) return 'no target';
    final segment = '$_sessionDir/seg${_segments.length + 1}.mp4';
    try {
      _process = await Process.start(
        'ffmpeg',
        buildCaptureCommand(target: target, outputPath: segment),
        mode: ProcessStartMode.normal,
      );
      // Drain stdout/stderr completely: ffmpeg writes progress lines
      // continuously, and a full pipe blocks it — which would stall the
      // 'q' stdin shutdown and leave the segment unfinished.
      _process!.stderr.drain<void>().ignore();
      _process!.stdout.drain<void>().ignore();
    } catch (e) {
      return 'ffmpeg failed to start: $e';
    }
    _segments.add(segment);
    return null;
  }

  Future<void> _tick() async {
    if (_paused || _process == null || _capHit) return;
    _elapsedSeconds++;
    final size = await _sessionSize();
    final reason = _elapsedSeconds >= maxDurationSeconds
        ? RecorderStopReason.maxDuration
        : (size >= maxFileSizeBytes ? RecorderStopReason.maxSize : null);
    if (reason != null) {
      // Signal the listener; the dialog owns the stop() call so the final
      // file lands where it expects.
      _capHit = true;
      _status.add(RecorderStatus(
        elapsedSeconds: _elapsedSeconds,
        sizeBytes: size,
        paused: false,
        autoStopped: true,
        reason: reason,
      ));
      return;
    }
    _status.add(RecorderStatus(
      elapsedSeconds: _elapsedSeconds,
      sizeBytes: size,
      paused: false,
    ));
  }

  Future<int> _sessionSize() async {
    var total = 0;
    for (final seg in _segments) {
      try {
        total += File(seg).lengthSync();
      } catch (_) {}
    }
    return total;
  }

  /// Pause: gracefully stop the current segment (a new one starts on resume).
  Future<void> pause() async {
    if (_process == null || _paused) return;
    _paused = true;
    await _stopProcess();
    _status.add(RecorderStatus(
      elapsedSeconds: _elapsedSeconds,
      sizeBytes: await _sessionSize(),
      paused: true,
    ));
  }

  /// Resume: start a new segment with identical parameters.
  Future<String?> resume() async {
    if (_process != null || !_paused) return 'not paused';
    final error = await _startSegment();
    if (error != null) return error;
    _paused = false;
    _status.add(RecorderStatus(
      elapsedSeconds: _elapsedSeconds,
      sizeBytes: await _sessionSize(),
      paused: false,
    ));
    return null;
  }

  /// Stop and finalize: concat all segments into [outputPath] (stream copy —
  /// segments share identical codec parameters), probe and return metadata.
  /// Without [outputPath] the result is written to a default temp location
  /// (used by the automatic cap stop).
  Future<RecordedVideo?> stop([String? outputPath]) async {
    if (_process == null) return null;
    _paused = false;
    await _stopProcess();
    _ticker?.cancel();
    _ticker = null;
    if (_segments.isEmpty) return null;
    final finalPath = outputPath ??
        '${Directory.systemTemp.path}/ghita_rec_auto_${DateTime.now().millisecondsSinceEpoch}.mp4';
    try {
      if (_segments.length == 1) {
        await File(_segments.first).copy(finalPath);
      } else {
        final listFile = File('$_sessionDir/concat.txt');
        await listFile.writeAsString(buildConcatList(_segments));
        final r = await Process.run('ffmpeg', [
          '-y', '-f', 'concat', '-safe', '0',
          '-i', listFile.path,
          '-c', 'copy',
          finalPath,
        ]);
        if (r.exitCode != 0) return null;
      }
      final durationMs = await VideoEmbedService.probeDurationMs(finalPath);
      final size = File(finalPath).lengthSync();
      return RecordedVideo(
        path: finalPath,
        durationMs: durationMs ?? 0,
        sizeBytes: size,
      );
    } catch (_) {
      return null;
    } finally {
      _cleanupSession();
      _segments.clear();
      _target = null;
    }
  }

  Future<void> _stopProcess() async {
    final p = _process;
    _process = null;
    if (p == null) return;
    try {
      p.stdin.write('q');
      await p.stdin.flush();
      await p.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      p.kill();
    }
  }

  void _cleanupSession() {
    try {
      final dir = _sessionDir;
      _sessionDir = null;
      if (dir != null) {
        Directory(dir).deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  /// Abort without producing a result (deletes temp segments).
  Future<void> cancel() async {
    await _stopProcess();
    _ticker?.cancel();
    _ticker = null;
    _cleanupSession();
    _segments.clear();
    _target = null;
  }

  void dispose() {
    _ticker?.cancel();
    _status.close();
  }
}
