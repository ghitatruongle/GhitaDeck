import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import 'video_embed_service.dart';

/// Audio Recording Service — v1.2.0
/// Records per-slide narration, stores as WAV files, provides playback sync.
///
/// Track 13: on Windows the `record` plugin captures WAV natively (the
/// aacLc encoder writes ADTS, not an m4a container) — so recordings are
/// transcoded to compressed m4a with FFmpeg right after stopping when
/// ffmpeg is available (otherwise the WAV is kept and documented as a
/// size/format limit).
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentPath;
  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentPath => _currentPath;
  int get elapsedSeconds => _elapsedSeconds;

  StreamController<int>? _durationStreamController;
  Stream<int>? get durationStream => _durationStreamController?.stream;

  /// The directory holding slide narration files.
  static Future<Directory> narrationDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(dir.path, 'GhitaPPT', 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Start recording audio for a specific slide.
  Future<bool> startRecording({int slideIndex = 0}) async {
    if (_isRecording) return false; // v1.2.0: guard against re-entrant
    // Claim the recording state BEFORE any await so two near-simultaneous
    // calls cannot both pass the guard and tear each other's state down.
    _isRecording = true;
    try {
      // Clean up any leftover stream/timer from previous session
      _durationTimer?.cancel();
      _durationTimer = null;
      await _durationStreamController?.close();
      _durationStreamController = null;

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('Microphone permission denied');
        _isRecording = false;
        return false;
      }

      final audioDir = await narrationDir();
      _currentPath = p.join(audioDir.path, 'slide_${slideIndex}_${DateTime.now().millisecondsSinceEpoch}.wav');
      _elapsedSeconds = 0;

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentPath!,
      );

      // Duration timer
      _durationStreamController = StreamController<int>.broadcast();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _elapsedSeconds++;
        _durationStreamController?.add(_elapsedSeconds);
      });

      debugPrint('AudioRecordingService: Started recording to $_currentPath');
      return true;
    } catch (e) {
      debugPrint('AudioRecordingService Error starting: $e');
      _isRecording = false;
      _isPaused = false;
      return false;
    }
  }

  /// Stop recording and return the file path.
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;
      _isPaused = false;
      _durationTimer?.cancel();
      _durationTimer = null;
      // v1.2.0: close stream controller to prevent leak
      await _durationStreamController?.close();
      _durationStreamController = null;

      debugPrint('AudioRecordingService: Stopped recording at $path');
      // v1.2.0: verify file exists before returning path
      if (path != null) {
        final file = File(path);
        if (await file.exists()) return path;
      }
      return _currentPath; // fallback
    } catch (e) {
      // The recorder threw (mic unplugged, device error) — release the timer
      // and controller here too, otherwise the periodic timer keeps firing
      // forever and the stream controller leaks.
      debugPrint('AudioRecordingService Error stopping: $e');
      _isRecording = false;
      _isPaused = false;
      _durationTimer?.cancel();
      _durationTimer = null;
      await _durationStreamController?.close();
      _durationStreamController = null;
      return null;
    }
  }

  /// Pause recording.
  Future<void> pauseRecording() async {
    try {
      if (_isRecording && !_isPaused) {
        await _recorder.pause();
        _isPaused = true;
        _durationTimer?.cancel();
      }
    } catch (e) {
      debugPrint('AudioRecordingService Error pausing: $e');
    }
  }

  /// Resume recording.
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return; // v1.2.0: guard state
    try {
      await _recorder.resume();
      _isPaused = false;
      // Only create timer if controller is still open
      if (_durationStreamController != null && !_durationStreamController!.isClosed) {
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _elapsedSeconds++;
          _durationStreamController?.add(_elapsedSeconds);
        });
      }
    } catch (e) {
      debugPrint('AudioRecordingService Error resuming: $e');
    }
  }

  // ---- Track 13: compressed m4a + trim (FFmpeg optional) ----------------

  /// Transcode a recorded WAV to a compressed m4a (AAC) next to it, deleting
  /// the WAV on success. Returns the m4a path, or the original [wavPath]
  /// when FFmpeg is unavailable (WAV fallback).
  static Future<String> transcodeToM4a(String wavPath) async {
    if (!await VideoEmbedService.ffmpegAvailable()) return wavPath;
    final m4aPath = wavPath.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '.m4a');
    try {
      final r = await Process.run('ffmpeg', [
        '-y', '-i', wavPath,
        '-c:a', 'aac', '-b:a', '128k',
        m4aPath,
      ]);
      if (r.exitCode == 0 && File(m4aPath).existsSync()) {
        try {
          File(wavPath).deleteSync();
        } catch (_) {}
        return m4aPath;
      }
    } catch (_) {}
    return wavPath;
  }

  /// Cut [srcPath] to the [start, end] window (stream copy first, re-encode
  /// fallback). Returns the trimmed file path, or null on failure.
  static Future<String?> trimAudio(
    String srcPath,
    double start,
    double end,
  ) async {
    if (!await VideoEmbedService.ffmpegAvailable() || end <= start) return null;
    final dir = Directory('${Directory.systemTemp.path}/ghita_atrim_${DateTime.now().millisecondsSinceEpoch}');
    await dir.create(recursive: true);
    final out = p.join(dir.path, 'trim.m4a');
    try {
      var r = await Process.run('ffmpeg', [
        '-y', '-ss', '$start', '-i', srcPath,
        '-t', '${end - start}', '-c', 'copy', out,
      ]);
      if (r.exitCode != 0) {
        r = await Process.run('ffmpeg', [
          '-y', '-ss', '$start', '-i', srcPath,
          '-t', '${end - start}',
          '-c:a', 'aac', '-b:a', '128k', out,
        ]);
      }
      if (r.exitCode != 0 || !File(out).existsSync()) return null;
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Get all audio files for the presentation (wav + m4a).
  Future<List<AudioFileInfo>> listAudioFiles() async {
    try {
      final dir = await narrationDir();
      final files = await dir
          .list()
          .where((f) =>
              f is File &&
              (f.path.endsWith('.wav') || f.path.endsWith('.m4a')))
          .toList();
      final result = <AudioFileInfo>[];
      for (final f in files) {
        try {
          // statSync on a file that was just deleted/being-written throws;
          // skip that entry instead of aborting the whole listing (which
          // previously made the UI show "no recordings").
          final stat = File(f.path).statSync();
          result.add(AudioFileInfo(
            path: f.path,
            fileName: p.basename(f.path),
            sizeBytes: stat.size,
            modified: stat.modified,
          ));
        } catch (_) {
          // file vanished mid-listing — skip
        }
      }
      return result;
    } catch (e) {
      debugPrint('AudioRecordingService Error listing: $e');
      return [];
    }
  }

  /// Delete an audio file.
  Future<bool> deleteAudioFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('AudioRecordingService Error deleting: $e');
    }
    return false;
  }

  /// Clean up resources.
  void dispose() {
    _durationTimer?.cancel();
    _durationStreamController?.close();
    _recorder.dispose();
  }

  /// Format seconds to mm:ss string.
  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class AudioFileInfo {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modified;

  const AudioFileInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modified,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
