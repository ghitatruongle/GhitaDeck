import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/media_item.dart';
import '../../services/screen_recorder_service.dart';
import '../../services/video_embed_service.dart';

/// "Quay màn hình" dialog (Track 12, P2–P7): pick a capture target (full
/// screen / window / region), record with a 3s countdown + live timer +
/// pause/resume, preview the result (poster + duration + size) and insert it
/// into the current slide as a Track 11 `<video>` block.
///
/// The dialog pops a [VideoData] on "insert", or null when dismissed —
/// the caller (editor_shell) inserts it via `presentationState.upsertVideo`.
class ScreenCaptureDialog extends StatefulWidget {
  const ScreenCaptureDialog({super.key});

  @override
  State<ScreenCaptureDialog> createState() => _ScreenCaptureDialogState();
}

enum _Stage { checking, ready, noFfmpeg, countdown, recording, result }

class _ScreenCaptureDialogState extends State<ScreenCaptureDialog> {
  final _service = ScreenRecorderService();
  StreamSubscription<RecorderStatus>? _statusSub;
  Timer? _countdownTimer;

  _Stage _stage = _Stage.checking;
  CaptureMode _mode = CaptureMode.fullScreen;
  List<String> _windowTitles = const [];
  String? _selectedWindow;
  final _regionX = TextEditingController(text: '0');
  final _regionY = TextEditingController(text: '0');
  final _regionW = TextEditingController();
  final _regionH = TextEditingController();
  int _countdown = 3;
  int _elapsedSeconds = 0;
  int _sizeBytes = 0;
  bool _paused = false;

  RecordedVideo? _recorded;
  Uint8List? _posterBytes;
  String? _finalPath;
  bool _inserted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await ScreenRecorderService.ffmpegAvailable();
    if (!mounted) return;
    setState(() => _stage = ok ? _Stage.ready : _Stage.noFfmpeg);
    if (ok) {
      final titles = await ScreenRecorderService.listWindowTitles();
      if (mounted) {
        setState(() {
          _windowTitles = titles;
          if (titles.isNotEmpty) _selectedWindow = titles.first;
        });
      }
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _countdownTimer?.cancel();
    _service.dispose();
    if (!_inserted && _finalPath != null) {
      try {
        File(_finalPath!).deleteSync();
      } catch (_) {}
    }
    _regionX.dispose();
    _regionY.dispose();
    _regionW.dispose();
    _regionH.dispose();
    super.dispose();
  }

  CaptureTarget? _buildTarget() {
    switch (_mode) {
      case CaptureMode.fullScreen:
        return const CaptureTarget.fullScreen();
      case CaptureMode.window:
        return CaptureTarget.window(_selectedWindow ?? '');
      case CaptureMode.region:
        return CaptureTarget.region(
          int.tryParse(_regionX.text) ?? 0,
          int.tryParse(_regionY.text) ?? 0,
          int.tryParse(_regionW.text) ?? 0,
          int.tryParse(_regionH.text) ?? 0,
        );
    }
  }

  Future<void> _startPressed() async {
    final target = _buildTarget();
    if (target == null) return;
    if (target.mode == CaptureMode.window &&
        (target.windowTitle == null || target.windowTitle!.isEmpty)) {
      _toast(context.l10n.recordWindowRequired);
      return;
    }
    if (target.mode == CaptureMode.region &&
        ((target.regionW ?? 0) <= 0 || (target.regionH ?? 0) <= 0)) {
      _toast(context.l10n.recordRegionRequired);
      return;
    }
    final freeMb = await ScreenRecorderService.checkDiskFreeMb();
    if (!mounted) return;
    if (freeMb != null && freeMb < ScreenRecorderService.diskLowWarningMb) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.l10n.recordDiskLowTitle),
          content: Text(context.l10n.recordDiskLowBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.recordContinue),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.countdown;
      _countdown = 3;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        if (!mounted) return;
        final error = await _service.start(
          target: target,
          outputPath: '${Directory.systemTemp.path}/ghita_rec_final_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        if (!mounted) return;
        if (error != null) {
          setState(() => _stage = _Stage.ready);
          _toast(error);
          return;
        }
        setState(() {
          _stage = _Stage.recording;
          _elapsedSeconds = 0;
          _sizeBytes = 0;
          _paused = false;
        });
        _statusSub?.cancel();
        _statusSub = _service.statusStream.listen(_onStatus);
      }
    });
  }

  void _onStatus(RecorderStatus status) {
    if (!mounted) return;
    setState(() {
      _elapsedSeconds = status.elapsedSeconds;
      _sizeBytes = status.sizeBytes;
      _paused = status.paused;
    });
    if (status.autoStopped) {
      _toast(status.reason == RecorderStopReason.maxDuration
          ? context.l10n.recordMaxDurationReached
          : context.l10n.recordMaxSizeReached);
      _finish();
    }
  }

  Future<void> _pausePressed() async {
    await _service.pause();
    if (mounted) setState(() => _paused = true);
  }

  Future<void> _resumePressed() async {
    await _service.resume();
    if (mounted) setState(() => _paused = false);
  }

  Future<void> _stopPressed() async {
    _statusSub?.cancel();
    await _finish();
  }

  Future<void> _finish() async {
    final path = '${Directory.systemTemp.path}/ghita_rec_final_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final recorded = await _service.stop(path);
    if (!mounted) return;
    if (recorded == null) {
      setState(() => _stage = _Stage.ready);
      _toast(context.l10n.recordFailed);
      return;
    }
    final poster =
        await VideoEmbedService.extractFrameJpeg(recorded.path, at: 0.1);
    if (!mounted) return;
    setState(() {
      _stage = _Stage.result;
      _recorded = recorded;
      _posterBytes = poster;
      _finalPath = recorded.path;
      _elapsedSeconds = recorded.durationMs ~/ 1000;
      _sizeBytes = recorded.sizeBytes;
    });
  }

  void _insert() {
    final recorded = _recorded;
    if (recorded == null) return;
    _inserted = true;
    final video = VideoData(
      src: 'data:video/mp4;base64,${base64Encode(File(recorded.path).readAsBytesSync())}',
      poster: _posterBytes != null
          ? VideoEmbedService.thumbnailDataUri(_posterBytes!)
          : '',
      durationMs: recorded.durationMs,
    );
    try {
      File(recorded.path).deleteSync();
    } catch (_) {}
    Navigator.pop(context, video);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
    ));
  }

  static String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.videocam_outlined),
          const SizedBox(width: 10),
          Text(l.recordScreen),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: _buildContent(l),
      ),
      actions: _stage == _Stage.result
          ? [
              TextButton(
                onPressed: () {
                  if (_finalPath != null) {
                    try {
                      File(_finalPath!).deleteSync();
                    } catch (_) {}
                  }
                  Navigator.pop(context);
                },
                child: Text(l.recordDiscard),
              ),
              FilledButton.icon(
                onPressed: _insert,
                icon: const Icon(Icons.add_to_queue_outlined),
                label: Text(l.recordInsert),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
            ],
    );
  }

  Widget _buildContent(AppLocalizations l) {
    switch (_stage) {
      case _Stage.checking:
        return const Center(child: CircularProgressIndicator());
      case _Stage.noFfmpeg:
        return Text(l.recordNoFfmpeg);
      case _Stage.countdown:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_countdown',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(l.recordCountdown),
            ],
          ),
        );
      case _Stage.recording:
        return _buildRecording(l);
      case _Stage.result:
        return _buildResult(l);
      case _Stage.ready:
        return _buildConfig(l);
    }
  }

  Widget _buildConfig(AppLocalizations l) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<CaptureMode>(
            segments: [
              ButtonSegment(
                  value: CaptureMode.fullScreen,
                  label: Text(l.recordModeFullscreen),
                  icon: const Icon(Icons.desktop_windows_outlined)),
              ButtonSegment(
                  value: CaptureMode.window,
                  label: Text(l.recordModeWindow),
                  icon: const Icon(Icons.window_outlined)),
              ButtonSegment(
                  value: CaptureMode.region,
                  label: Text(l.recordModeRegion),
                  icon: const Icon(Icons.crop_free)),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 12),
          if (_mode == CaptureMode.window) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedWindow,
              decoration: InputDecoration(
                labelText: l.recordWindowSelect,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final t in _windowTitles)
                  DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _selectedWindow = v),
            ),
            if (_windowTitles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.recordWindowEmpty,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
          if (_mode == CaptureMode.region) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _regionX,
                    decoration: InputDecoration(
                      labelText: l.recordRegionX,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _regionY,
                    decoration: InputDecoration(
                      labelText: l.recordRegionY,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _regionW,
                    decoration: InputDecoration(
                      labelText: l.recordRegionW,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _regionH,
                    decoration: InputDecoration(
                      labelText: l.recordRegionH,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.recordRegionHint,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          Text(
            '${l.recordLimit}: ${_service.maxDurationSeconds ~/ 60} ${l.recordMinutes} / ${_fmtSize(_service.maxFileSizeBytes)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startPressed,
              icon: const Icon(Icons.fiber_manual_record, color: Colors.redAccent),
              label: Text(l.recordStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecording(AppLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _fmtDuration(_elapsedSeconds),
              style: const TextStyle(fontSize: 28, fontFamily: 'Consolas'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${_fmtSize(_sizeBytes)} · '
            '${_paused ? l.recordPaused : l.recordRecording}'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: _paused ? _resumePressed : _pausePressed,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              tooltip: _paused ? l.recordResume : l.recordPause,
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _stopPressed,
              icon: const Icon(Icons.stop),
              tooltip: l.recordStop,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult(AppLocalizations l) {
    final recorded = _recorded;
    if (recorded == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _posterBytes != null
              ? Image.memory(
                  _posterBytes!,
                  width: 480,
                  height: 270,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 480,
                  height: 270,
                  color: Colors.black,
                  child: const Icon(Icons.videocam, color: Colors.white54, size: 48),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          '${l.recordDuration}: ${_fmtDuration(recorded.durationMs ~/ 1000)} · '
          '${l.recordSize}: ${_fmtSize(recorded.sizeBytes)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(l.recordPreviewHint,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
