import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'screen_recorder_service.dart';

/// Recording mode for a presentation session (Track 39, P2).
enum PresentationRecordMode {
  /// Record slide timings + narration only (no video file).
  timingsNarration,

  /// Record full video of the presentation.
  video,
}

/// Track 39, P4: a finished recording.
class RecordedPresentation {
  final String? videoPath;
  final List<int> slideChangeSeconds;

  const RecordedPresentation({this.videoPath, required this.slideChangeSeconds});
}

/// Presentation recorder (Track 39, FEAT 65).
///
/// Wraps [ScreenRecorderService] for the video path and tracks per-slide
/// timings for the narration path. Exposes REC state + elapsed timer so the
/// Presenter UI can show a badge and a recording timer (P3).
class PresentationRecorderService extends ChangeNotifier {
  final ScreenRecorderService _screenRecorder = ScreenRecorderService();

  bool _recording = false;
  bool _paused = false;
  PresentationRecordMode _mode = PresentationRecordMode.timingsNarration;
  DateTime? _startedAt;
  Timer? _ticker;
  int _elapsedSeconds = 0;

  /// When the current recording started (null when not recording).
  DateTime? get startedAt => _startedAt;
  final List<int> _slideChangeSeconds = [];
  int _currentSlide = 0;
  String? _lastVideoPath;

  // Track 39, P7: limits.
  static const int maxDurationSeconds = 1800; // 30 min
  static const int maxSizeBytes = 1024 * 1024 * 1024; // 1 GB

  bool get recording => _recording;
  bool get paused => _paused;
  PresentationRecordMode get mode => _mode;
  int get elapsedSeconds => _elapsedSeconds;
  String? get lastVideoPath => _lastVideoPath;

  /// Called when recording auto-stops (duration/size limit reached).
  void Function()? onAutoStop;

  Future<bool> start(PresentationRecordMode mode) async {
    if (_recording) return false;
    _mode = mode;
    _recording = true;
    _paused = false;
    _elapsedSeconds = 0;
    _slideChangeSeconds.clear();
    _slideChangeSeconds.add(0);
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      if (_elapsedSeconds >= maxDurationSeconds) {
        stop();
        onAutoStop?.call();
      }
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void enterSlide(int slideIndex) {
    if (!_recording) return;
    if (slideIndex != _currentSlide) {
      _currentSlide = slideIndex;
      _slideChangeSeconds.add(_elapsedSeconds);
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (!_recording || _paused) return;
    _paused = true;
    if (_mode == PresentationRecordMode.video) {
      await _screenRecorder.pause();
    }
    notifyListeners();
  }

  Future<void> resume() async {
    if (!_recording || !_paused) return;
    _paused = false;
    if (_mode == PresentationRecordMode.video) {
      await _screenRecorder.resume();
    }
    notifyListeners();
  }

  /// Stop the recording. In video mode the MP4 is finalised via the screen
  /// recorder; timings-only mode just returns the timing list.
  Future<RecordedPresentation> stop() async {
    if (!_recording) {
      return RecordedPresentation(slideChangeSeconds: List.of(_slideChangeSeconds));
    }
    _recording = false;
    _ticker?.cancel();
    _ticker = null;
    RecordedPresentation result;
    if (_mode == PresentationRecordMode.video) {
      final dir = Directory.systemTemp;
      final path = '${dir.path}/ghita_pres_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final recorded = await _screenRecorder.stop(path);
      _lastVideoPath = recorded?.path ?? (File(path).existsSync() ? path : null);
      result = RecordedPresentation(
        videoPath: _lastVideoPath,
        slideChangeSeconds: List.of(_slideChangeSeconds),
      );
    } else {
      result = RecordedPresentation(slideChangeSeconds: List.of(_slideChangeSeconds));
    }
    notifyListeners();
    return result;
  }

  Future<void> cancel() async {
    _recording = false;
    _ticker?.cancel();
    _ticker = null;
    await _screenRecorder.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
