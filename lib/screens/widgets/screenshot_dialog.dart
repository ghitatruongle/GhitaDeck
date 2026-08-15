import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/screenshot_service.dart';

/// Screenshot capture dialog (Track 16, P1): choose full screen / active
/// window / custom region, then capture to PNG bytes. Returns the captured
/// PNG on "insert" — the caller (editor_shell) opens the image editor for
/// cropping before inserting.
class ScreenshotDialog extends StatefulWidget {
  const ScreenshotDialog({super.key});

  @override
  State<ScreenshotDialog> createState() => _ScreenshotDialogState();
}

enum _ScreenshotMode { fullScreen, window, region }

class _ScreenshotDialogState extends State<ScreenshotDialog> {
  _ScreenshotMode _mode = _ScreenshotMode.fullScreen;
  final _regionX = TextEditingController(text: '0');
  final _regionY = TextEditingController(text: '0');
  final _regionW = TextEditingController();
  final _regionH = TextEditingController();
  bool _capturing = false;
  bool _failed = false;
  Uint8List? _preview;

  @override
  void dispose() {
    _regionX.dispose();
    _regionY.dispose();
    _regionW.dispose();
    _regionH.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _failed = false;
      _preview = null;
    });
    Uint8List? result;
    switch (_mode) {
      case _ScreenshotMode.fullScreen:
        result = await ScreenshotService.captureFullScreen();
      case _ScreenshotMode.window:
        result = await ScreenshotService.captureWindow();
      case _ScreenshotMode.region:
        result = await ScreenshotService.captureRegion(
          int.tryParse(_regionX.text) ?? 0,
          int.tryParse(_regionY.text) ?? 0,
          int.tryParse(_regionW.text) ?? 0,
          int.tryParse(_regionH.text) ?? 0,
        );
    }
    if (!mounted) return;
    setState(() {
      _capturing = false;
      if (result == null) {
        _failed = true;
      } else {
        _preview = result;
      }
    });
  }

  void _insert() {
    final preview = _preview;
    if (preview == null) return;
    Navigator.pop(context, preview);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.camera_alt_outlined),
        const SizedBox(width: 10),
        Text(l.screenshot),
      ]),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_ScreenshotMode>(
                segments: [
                  ButtonSegment(
                      value: _ScreenshotMode.fullScreen,
                      label: Text(l.screenshotFullscreen),
                      icon: const Icon(Icons.desktop_windows_outlined)),
                  ButtonSegment(
                      value: _ScreenshotMode.window,
                      label: Text(l.screenshotWindow),
                      icon: const Icon(Icons.window_outlined)),
                  ButtonSegment(
                      value: _ScreenshotMode.region,
                      label: Text(l.screenshotRegion),
                      icon: const Icon(Icons.crop_free)),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              const SizedBox(height: 12),
              if (_mode == _ScreenshotMode.region) ...[
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
                        keyboardType: TextInputType.number,
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
                        keyboardType: TextInputType.number,
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
                        keyboardType: TextInputType.number,
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
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l.screenshotRegionHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              if (_preview != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _preview!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (_failed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l.screenshotFailed,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _capturing ? null : _capture,
                  icon: _capturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(_preview != null
                      ? l.screenshotRecapture
                      : l.screenshotCapture),
                ),
              ),
              if (_preview != null) ...[
                const SizedBox(height: 8),
                Text(l.screenshotCropHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        if (_preview != null)
          FilledButton(
            onPressed: _insert,
            child: Text(l.screenshotUse),
          ),
      ],
    );
  }
}