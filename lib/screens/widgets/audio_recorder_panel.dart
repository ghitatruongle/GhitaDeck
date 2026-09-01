import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/presentation_state.dart';
import '../../services/audio_recording_service.dart';
import '../../services/video_embed_service.dart';
import '../../utils/snackbar_helper.dart';

/// Per-slide narration recorder (Track 13, P1/P3/P6/P7): record mic audio
/// (WAV → FFmpeg-transcoded m4a), then edit the attached narration — trim
/// window, autoplay/loop/play-across-slides/hide-icon options, or remove.
///
/// Every change is applied immediately to the current slide by the panel
/// itself via `PresentationState.updateSlide`.
class AudioRecorderPanel extends StatefulWidget {
  const AudioRecorderPanel({super.key, required this.slideIndex});

  final int slideIndex;

  @override
  State<AudioRecorderPanel> createState() => _AudioRecorderPanelState();
}

class _AudioRecorderPanelState extends State<AudioRecorderPanel> {
  final AudioRecordingService _recorder = AudioRecordingService();
  StreamSubscription<int>? _durationSub;
  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  bool _busy = false;

  final _trimStart = TextEditingController();
  final _trimEnd = TextEditingController();

  @override
  void dispose() {
    _durationSub?.cancel();
    _recorder.dispose();
    _trimStart.dispose();
    _trimEnd.dispose();
    super.dispose();
  }

  Slide? get _slide {
    final state = context.read<PresentationState>();
    final index = state.currentSlideIndex;
    if (index < 0 || index >= state.slides.length) return null;
    return state.slides[index];
  }

  void _applyAudio(Slide Function(Slide) transform) {
    final state = context.read<PresentationState>();
    final index = state.currentSlideIndex;
    final slide = _slide;
    if (index < 0 || slide == null) return;
    state.updateSlide(index, transform(slide));
  }

  Map<String, dynamic> _optionsOf(Slide slide) =>
      Map<String, dynamic>.from(slide.audioOptions);

  Future<void> _startRecording() async {
    final ok =
        await _recorder.startRecording(slideIndex: widget.slideIndex);
    if (!ok || !mounted) return;
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _elapsedSeconds = 0;
    });
    _durationSub?.cancel();
    _durationSub = _recorder.durationStream?.listen((seconds) {
      if (mounted) setState(() => _elapsedSeconds = seconds);
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stopRecording();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    // Track 13, P2: compress WAV → m4a with FFmpeg when available.
    final finalPath = await AudioRecordingService.transcodeToM4a(path);
    final durationMs =
        await VideoEmbedService.probeDurationMs(finalPath) ?? 0;
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _busy = false;
    });
    _applyAudio((slide) => slide.copyWith(
          audioPath: finalPath,
          audioEmbedded: true,
          audioOptions: {
            ..._optionsOf(slide),
            'durationMs': durationMs,
          },
        ));
  }

  Future<void> _pauseRecording() async {
    await _recorder.pauseRecording();
    if (mounted) setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _recorder.resumeRecording();
    if (mounted) setState(() => _isPaused = false);
  }

  Future<void> _applyTrim() async {
    final slide = _slide;
    if (slide == null || slide.audioPath.isEmpty) return;
    final start = _parseSeconds(_trimStart.text);
    final end = _parseSeconds(_trimEnd.text);
    if (end <= start) return;
    setState(() => _busy = true);
    final trimmed =
        await AudioRecordingService.trimAudio(slide.audioPath, start, end);
    if (!mounted) return;
    setState(() => _busy = false);
    if (trimmed != null) {
      // Real cut: the file itself is trimmed, timestamps reset.
      final durationMs =
          await VideoEmbedService.probeDurationMs(trimmed) ?? 0;
      _applyAudio((s) => s.copyWith(
            audioPath: trimmed,
            audioOptions: {
              ..._optionsOf(s),
              'durationMs': durationMs,
              'trimStart': 0,
              'trimEnd': 0,
            },
          ));
      _trimStart.clear();
      _trimEnd.clear();
    } else {
      // No FFmpeg: keep timestamps — the HTML player honours them.
      _applyAudio((s) => s.copyWith(audioOptions: {
            ..._optionsOf(s),
            'trimStart': start,
            'trimEnd': end,
          }));
      if (mounted) {
        showAppSnackBar(
  context,
  context.l10n.audioTrimNoFfmpeg,
  duration: const Duration(seconds: 2)
);
      }
    }
  }

  static double _parseSeconds(String text) {
    final parts = text.trim().split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (double.tryParse(parts[1]) ?? 0);
    }
    return double.tryParse(text.trim()) ?? 0;
  }

  void _setOption(String key, bool value) {
    _applyAudio((s) => s.copyWith(audioOptions: {
          ..._optionsOf(s),
          key: value,
        }));
  }

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final slide = _slide;
    final hasAudio = slide != null && slide.audioPath.isNotEmpty;
    final durationMs =
        (slide?.audioOptions['durationMs'] as num?)?.toInt() ?? 0;
    final opts =
        slide == null ? const <String, dynamic>{} : slide.audioOptions;

    if (_isRecording) {
      return Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AudioRecordingService.formatDuration(_elapsedSeconds),
            style: const TextStyle(
                fontSize: 13, fontFamily: 'Consolas', color: Colors.redAccent),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
            tooltip: _isPaused ? l.recordResume : l.recordPause,
          ),
          IconButton(
            icon: const Icon(Icons.stop, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : _stopRecording,
            tooltip: l.recordStop,
          ),
        ],
      );
    }

    if (!hasAudio) {
      return Row(
        children: [
          IconButton(
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mic, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : _startRecording,
            tooltip: l.audioRecordNarration,
          ),
          const SizedBox(width: 6),
          Text(l.audioNoNarration,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mic, size: 16),
          visualDensity: VisualDensity.compact,
          onPressed: _busy ? null : _startRecording,
          tooltip: l.audioRecordNarration,
        ),
        Icon(Icons.volume_up,
            size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 2),
        Text(
          '${l.audioDuration}: ${_fmt((durationMs / 1000).round())}',
          style: const TextStyle(fontSize: 11),
        ),
        // Trim window
        SizedBox(
          width: 52,
          child: TextField(
            controller: _trimStart,
            decoration: const InputDecoration(
              hintText: '0:05',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const Text('–', style: TextStyle(fontSize: 11)),
        SizedBox(
          width: 52,
          child: TextField(
            controller: _trimEnd,
            decoration: const InputDecoration(
              hintText: '0:30',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _applyTrim,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 28),
          ),
          child: Text(l.audioTrimApply, style: const TextStyle(fontSize: 11)),
        ),
        // Options
        FilterChip(
          label: Text(l.audioAutoplay, style: const TextStyle(fontSize: 10)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selected: opts['autoplay'] == true,
          onSelected: (v) => _setOption('autoplay', v),
        ),
        FilterChip(
          label: Text(l.audioLoop, style: const TextStyle(fontSize: 10)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selected: opts['loop'] == true,
          onSelected: (v) => _setOption('loop', v),
        ),
        FilterChip(
          label:
              Text(l.audioAcrossSlides, style: const TextStyle(fontSize: 10)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selected: opts['acrossSlides'] == true,
          onSelected: (v) => _setOption('acrossSlides', v),
        ),
        FilterChip(
          label: Text(l.audioHideIcon, style: const TextStyle(fontSize: 10)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selected: opts['hideIcon'] == true,
          onSelected: (v) => _setOption('hideIcon', v),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 16),
          visualDensity: VisualDensity.compact,
          onPressed: () => _applyAudio((s) => s.copyWith(clearAudio: true)),
          tooltip: l.audioRemove,
        ),
      ],
    );
  }
}