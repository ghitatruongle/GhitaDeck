/// Video & GIF export from slides (Track 41, FEAT 66/67).
///
/// Pipeline: build a frame schedule (per-slide duration from rehearse
/// timings / narration audio / a default), render frames with
/// [SlideFrameRenderer], then either
///
///  * **GIF** — encoded in pure Dart with the `image` package (256-colour
///    palette, per-slide durations via frame repetition, loop count),
///  * **MP4** — piped to FFmpeg (`image2pipe` PNG frames + narration audio
///    mixed per slide with `adelay`). FFmpeg must be installed; when it is
///    missing the service reports a clear error instead of failing silently.
///
/// Progress/cancel follow the Track 01 contract (monotonic fraction +
/// cooperative [ExportCancelToken]).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'export_primitives.dart';
import 'slide_frame_renderer.dart';

/// Output container for a slide movie.
enum SlideMovieFormat { mp4, gif }

/// One slide in the movie: index + its hold duration.
class SlideShot {
  final int slideIndex;
  final Duration duration;

  const SlideShot({required this.slideIndex, required this.duration});

  Map<String, dynamic> toMap() =>
      {'slideIndex': slideIndex, 'durationMs': duration.inMilliseconds};

  static SlideShot fromMap(Map<String, dynamic> map) => SlideShot(
        slideIndex: (map['slideIndex'] as num?)?.toInt() ?? 0,
        duration: Duration(
            milliseconds: (map['durationMs'] as num?)?.toInt() ?? 3000),
      );
}

class VideoExportOptions {
  const VideoExportOptions({
    this.format = SlideMovieFormat.mp4,
    this.fps = 30,
    this.scale = 2, // 2 → 1080p (2560×1440 @ 16:9); 1 → 720p, 3 → 4K
    this.defaultSlideDuration = const Duration(seconds: 3),
    this.gifLoop = 0, // 0 = infinite
    this.gifFps = 10,
    this.includeNarration = true,
    this.ffmpegPath = 'ffmpeg',
  });

  final SlideMovieFormat format;
  final int fps;
  final int scale;
  final Duration defaultSlideDuration;

  /// GIF only: 0 = loop forever, n = play n times.
  final int gifLoop;
  final int gifFps;

  /// Mix per-slide narration audio into MP4 (from `audioPath`).
  final bool includeNarration;

  /// Executable used for MP4 (path or bare `ffmpeg` on PATH).
  final String ffmpegPath;
}

/// Result of a completed render.
class VideoExportResult {
  final String path;
  final Duration duration;
  final int frameCount;

  const VideoExportResult({
    required this.path,
    required this.duration,
    required this.frameCount,
  });
}

/// Estimated render cost — shown before the run starts (phase 7).
class VideoRenderEstimate {
  final Duration duration;
  final int frameCount;
  final int width;
  final int height;
  final int estimatedSeconds;

  const VideoRenderEstimate({
    required this.duration,
    required this.frameCount,
    required this.width,
    required this.height,
    required this.estimatedSeconds,
  });
}

class VideoExportService {
  VideoExportService._();

  /// Per-slide duration: narration audio duration when present (probed via
  /// the audio file header), else `rehearseMs`, else the default.
  static Duration slideDuration(
    Map<String, dynamic> slide, {
    Duration defaultDuration = const Duration(seconds: 3),
    bool includeNarration = true,
  }) {
    if (includeNarration) {
      final audio = (slide['audioPath'] ?? '').toString();
      if (audio.isNotEmpty) {
        final dur = _probeAudioDuration(audio);
        if (dur != null && dur > Duration.zero) return dur;
      }
    }
    final rehearse = (slide['rehearseMs'] as num?)?.toInt() ?? 0;
    if (rehearse > 0) return Duration(milliseconds: rehearse);
    return defaultDuration;
  }

  /// WAV/MP4 duration probe (pure Dart header parse): WAV fmt chunk or MP4
  /// (m4a) `mvhd`/`stts`-independent estimate via sample count + rate from
  /// the `mdhd` box. Returns null when unreadable — callers fall back.
  static Duration? _probeAudioDuration(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      if (bytes.length < 44) return null;
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        // RIFF/WAV: fmt chunk at 12, data chunk size at 40.
        final sampleRate = data.getUint32(24, Endian.little);
        final byteRate = data.getUint32(28, Endian.little);
        final dataSize = data.getUint32(40, Endian.little);
        if (sampleRate <= 0 || byteRate <= 0) return null;
        final seconds = dataSize / byteRate;
        return Duration(milliseconds: (seconds * 1000).round());
      }
      // MP4: find the `mdhd` box inside moov→trak→mdia (boxes start at
      // offset 0; containers hold nested boxes). Version 0 → 32-bit
      // timescale/duration; version 1 → 64-bit. Offsets are relative to the
      // box start: fullbox (version+flags) at +8; v0 timescale +20 /
      // duration +24; v1 creation +12..+20, timescale +28 / duration +32.
      Duration? probe(int start, int end) {
        var i = start;
        while (i + 8 <= end) {
          final size = data.getUint32(i, Endian.big);
          if (size < 8) break;
          final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
          final boxEnd = i + size;
          if (type == 'mdhd' && boxEnd <= end) {
            final version = bytes[i + 8];
            final tsOff = version == 1 ? 28 : 20;
            final durOff = version == 1 ? 32 : 24;
            if (boxEnd - i < durOff + 8) return null;
            final timescale = data.getUint32(i + tsOff, Endian.big);
            final dur = version == 1
                ? data.getUint64(i + durOff, Endian.big)
                : data.getUint32(i + durOff, Endian.big);
            if (timescale > 0) {
              return Duration(
                  milliseconds: (dur / timescale * 1000).round());
            }
            return null;
          }
          if (boxEnd > end) break;
          if (type == 'moov' || type == 'trak' || type == 'mdia') {
            final r = probe(i + 8, boxEnd);
            if (r != null) return r;
          }
          i = boxEnd;
        }
        return null;
      }

      final r = probe(0, bytes.length);
      if (r != null) return r;
    } catch (_) {}
    return null;
  }

  /// Build the shot list for [slides] (phases 2–3 of the track).
  static List<SlideShot> buildSchedule(
    List<Map<String, dynamic>> slides, {
    VideoExportOptions options = const VideoExportOptions(),
  }) {
    return [
      for (var i = 0; i < slides.length; i++)
        SlideShot(
          slideIndex: i,
          duration: slideDuration(slides[i],
              defaultDuration: options.defaultSlideDuration,
              includeNarration: options.includeNarration),
        ),
    ];
  }

  /// Total duration + frame count of a schedule (for progress and the
  /// pre-run estimate).
  static VideoRenderEstimate estimate(
    List<SlideShot> shots, {
    VideoExportOptions options = const VideoExportOptions(),
  }) {
    var totalMs = 0;
    for (final s in shots) {
      totalMs += s.duration.inMilliseconds;
    }
    final (w, h) = _sizeForScale(options.scale);
    // GIF encodes one frame per shot (per-slide duration baked into the
    // frame delay); MP4 repeats each frame at the FPS rate.
    final frameCount = options.format == SlideMovieFormat.gif
        ? shots.length
        : (totalMs / 1000 * options.fps).ceil();
    // ~40 ms per 1080p frame in pure Dart rendering is a safe guide.
    final estimatedSeconds = (frameCount * 40 / 1000).round();
    return VideoRenderEstimate(
      duration: Duration(milliseconds: totalMs),
      frameCount: frameCount,
      width: w,
      height: h,
      estimatedSeconds: estimatedSeconds,
    );
  }

  static (int, int) _sizeForScale(int scale) {
    final s = scale.clamp(1, 4);
    return (1280 * s, 720 * s);
  }

  /// Check whether [ffmpegPath] resolves (phase 1 survey — used by the UI
  /// to pre-warn before the dialog opens).
  static Future<bool> ffmpegAvailable({String ffmpegPath = 'ffmpeg'}) async {
    try {
      final r = await Process.run(ffmpegPath, ['-version'])
          .timeout(const Duration(seconds: 5));
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Render the whole movie. [onProgress] receives a monotonic 0..1
  /// fraction (per rendered frame).
  static Future<VideoExportResult> exportVideo(
    List<Map<String, dynamic>> slides,
    String outputPath, {
    VideoExportOptions options = const VideoExportOptions(),
    ExportCancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    final shots = buildSchedule(slides, options: options);
    final est = estimate(shots, options: options);
    final (width, height) = (est.width, est.height);

    switch (options.format) {
      case SlideMovieFormat.gif:
        final bytes = await _encodeGif(
          slides,
          shots,
          width: width,
          height: height,
          loop: options.gifLoop,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
        if (bytes == null) throw Exception('GIF encoding failed');
        await File(outputPath).writeAsBytes(bytes, flush: true);
        return VideoExportResult(
            path: outputPath,
            duration: est.duration,
            frameCount: shots.length);
      case SlideMovieFormat.mp4:
        return await _encodeMp4(
          slides,
          shots,
          outputPath,
          width: width,
          height: height,
          options: options,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
    }
  }

  static int _framesForShot(SlideShot shot, int fps) {
    final frames = (shot.duration.inMilliseconds * fps / 1000).ceil();
    return frames.clamp(1, 1 << 20);
  }

  /// GIF: one frame per shot with the shot's hold duration baked into the
  /// frame (the encoder writes per-frame delays in 1/100 s); the 256-colour
  /// palette quantizes across the whole clip.
  static Future<Uint8List?> _encodeGif(
    List<Map<String, dynamic>> slides,
    List<SlideShot> shots, {
    required int width,
    required int height,
    required int loop,
    ExportCancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    final frames = <img.Image>[];
    for (var k = 0; k < shots.length; k++) {
      cancelToken?.throwIfCancelled();
      final shot = shots[k];
      final frame = SlideFrameRenderer.renderSlide(slides[shot.slideIndex],
          width: width, height: height);
      if (frame == null) continue;
      frame.image.frameDuration = shot.duration.inMilliseconds;
      frames.add(frame.image);
      onProgress?.call((k + 1) / shots.length);
    }
    if (frames.isEmpty) return null;
    final animated = img.Image(width: width, height: height, numChannels: 4);
    animated.loopCount = loop;
    animated.frames.addAll(frames);
    return Uint8List.fromList(img.GifEncoder().encode(animated));
  }

  /// MP4: pipe PNG frames + per-slide narration into FFmpeg.
  static Future<VideoExportResult> _encodeMp4(
    List<Map<String, dynamic>> slides,
    List<SlideShot> shots,
    String outputPath, {
    required int width,
    required int height,
    required VideoExportOptions options,
    ExportCancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    final ffmpeg = options.ffmpegPath;
    final narrationInputs = <String>[];
    final audioFilters = <String>[];
    var inputIndex = 0; // 0 = the image2pipe
    var elapsedMs = 0;
    for (var k = 0; k < shots.length; k++) {
      final audio = options.includeNarration
          ? (slides[shots[k].slideIndex]['audioPath'] ?? '').toString()
          : '';
      if (audio.isNotEmpty && File(audio).existsSync()) {
        inputIndex++;
        narrationInputs.addAll(['-i', audio]);
        audioFilters.add(
            '[$inputIndex:a]adelay=$elapsedMs|$elapsedMs[a$k]');
      } else {
        audioFilters.add('anullsrc=channel_layout=stereo:sample_rate=44100,'
            'atrim=0:${shots[k].duration.inMilliseconds / 1000},'
            'asetpts=PTS-STARTPTS[a$k]');
      }
      elapsedMs += shots[k].duration.inMilliseconds;
    }
    final args = <String>[
      '-y',
      '-f', 'image2pipe',
      '-framerate', '${options.fps}',
      '-vcodec', 'png',
      '-i', '-',
      ...narrationInputs,
      '-filter_complex',
      '${audioFilters.join(';')};'
          '${audioFilters.asMap().entries.map((e) => '[a${e.key}]').join('')}'
          'amix=inputs=${audioFilters.length}:normalize=0[aout]',
      '-map', '0:v',
      '-map', '[aout]',
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',
      '-preset', 'veryfast',
      '-c:a', 'aac',
      '-shortest',
      outputPath,
    ];

    final process = await Process.start(ffmpeg, args);
    process.stderr.transform(utf8.decoder).listen((_) {});
    final sink = process.stdin;
    var done = 0;
    final total =
        shots.fold<int>(0, (s, sh) => s + _framesForShot(sh, options.fps));
    try {
      for (var k = 0; k < shots.length; k++) {
        cancelToken?.throwIfCancelled();
        final shot = shots[k];
        final frame = SlideFrameRenderer.renderSlide(slides[shot.slideIndex],
            width: width, height: height);
        if (frame == null) continue;
        final bytes = frame.pngBytes;
        final repeats = _framesForShot(shot, options.fps);
        for (var r = 0; r < repeats; r++) {
          sink.add(bytes);
          done++;
          if (done % options.fps == 0) onProgress?.call(done / total);
        }
      }
    } finally {
      await sink.close();
    }
    final exit = await process.exitCode;
    if (exit != 0) {
      throw Exception('FFmpeg exited with code $exit');
    }
    onProgress?.call(1.0);
    return VideoExportResult(
        path: outputPath,
        duration: Duration(milliseconds: elapsedMs),
        frameCount: done);
  }
}
