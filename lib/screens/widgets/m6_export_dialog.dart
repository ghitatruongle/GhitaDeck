import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart' as printing;

import '../../l10n/l10n.dart';
import '../../services/doc_security_service.dart';
import '../../services/odp_export_service.dart';
import '../../services/outline_export_service.dart';
import '../../services/package_format_service.dart';
import '../../services/package_service.dart';
import '../../services/ppt_generator.dart';
import '../../services/print_service.dart';
import '../../services/slide_image_export_service.dart';
import '../../services/video_export_service.dart';

/// Milestone 6 tools (T41–T45): video/GIF export, batch slide images,
/// print & handouts & outline RTF, extended save formats (.potx/.ppsx/
/// .odp/.ppt) and package + document protection.
class M6ExportDialog extends StatefulWidget {
  const M6ExportDialog({super.key, required this.slides});

  final List<Map<String, dynamic>> slides;

  @override
  State<M6ExportDialog> createState() => _M6ExportDialogState();
}

class _M6ExportDialogState extends State<M6ExportDialog> {
  int _tab = 0;
  bool _busy = false;
  double _progress = 0;

  // T41 video.
  SlideMovieFormat _movieFormat = SlideMovieFormat.mp4;
  int _fps = 30;
  int _movieScale = 2;
  bool _includeNarration = true;
  bool _ffmpegOk = true;

  // T42 images.
  SlideImageFormat _imgFormat = SlideImageFormat.png;
  int _imgScale = 2;
  bool _transparent = false;
  bool _contactSheet = false;
  final String _prefix = 'slide';

  // T43 print.
  HandoutPerPage _perPage = HandoutPerPage.six;
  bool _includeNotes = true;
  bool _grayscale = false;

  // T45 security.
  final List<InspectorFinding> _findings = [];
  String _password = '';
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    VideoExportService.ffmpegAvailable().then((ok) {
      if (mounted) setState(() => _ffmpegOk = ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.m6Title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l.m6Video)),
                  ButtonSegment(value: 1, label: Text(l.m6Images)),
                  ButtonSegment(value: 2, label: Text(l.m6Print)),
                  ButtonSegment(value: 3, label: Text(l.m6Formats)),
                  ButtonSegment(value: 4, label: Text(l.m6Protect)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: 12),
              if (_busy) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(l.exportingInProgress),
                const SizedBox(height: 12),
              ],
              switch (_tab) {
                0 => _buildVideoTab(l),
                1 => _buildImagesTab(l),
                2 => _buildPrintTab(l),
                3 => _buildFormatsTab(l),
                _ => _buildProtectTab(l),
              },
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }

  // ---- T41: video & GIF --------------------------------------------------

  Widget _buildVideoTab(dynamic l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<SlideMovieFormat>(
          initialValue: _movieFormat,
          decoration: InputDecoration(labelText: l.m6MovieFormat),
          items: SlideMovieFormat.values
              .map((f) => DropdownMenuItem(
                  value: f, child: Text(f.name.toUpperCase())))
              .toList(),
          onChanged: (v) => setState(() => _movieFormat = v ?? _movieFormat),
        ),
        DropdownButtonFormField<int>(
          initialValue: _fps,
          decoration: const InputDecoration(labelText: 'FPS'),
          items: [24, 30, 60]
              .map((f) => DropdownMenuItem(value: f, child: Text('$f')))
              .toList(),
          onChanged: (v) => setState(() => _fps = v ?? _fps),
        ),
        DropdownButtonFormField<int>(
          initialValue: _movieScale,
          decoration: const InputDecoration(labelText: '720p / 1080p / 4K'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('720p')),
            DropdownMenuItem(value: 2, child: Text('1080p')),
            DropdownMenuItem(value: 3, child: Text('4K (2160p)')),
          ],
          onChanged: (v) => setState(() => _movieScale = v ?? _movieScale),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.m6IncludeNarration),
          value: _includeNarration,
          onChanged: (v) => setState(() => _includeNarration = v),
        ),
        if (_movieFormat == SlideMovieFormat.mp4 && !_ffmpegOk)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.m6FfmpegMissing,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : () => _exportMovie(l),
          icon: const Icon(Icons.movie),
          label: Text(l.m6ExportMovie),
        ),
      ],
    );
  }

  Future<void> _exportMovie(dynamic l) async {
    final path = await _pickSavePath(_movieFormat == SlideMovieFormat.gif
        ? 'presentation.gif'
        : 'presentation.mp4');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await VideoExportService.exportVideo(
        widget.slides,
        path,
        options: VideoExportOptions(
          format: _movieFormat,
          fps: _fps,
          scale: _movieScale,
          includeNarration: _includeNarration,
        ),
        onProgress: (f) {
          if (mounted) setState(() => _progress = f);
        },
      );
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- T42: slide images -------------------------------------------------

  Widget _buildImagesTab(dynamic l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<SlideImageFormat>(
          initialValue: _imgFormat,
          decoration: InputDecoration(labelText: l.m6ImageFormat),
          items: SlideImageFormat.values
              .map((f) => DropdownMenuItem(
                  value: f,
                  child: Text(f == SlideImageFormat.png ? 'PNG' : 'JPEG')))
              .toList(),
          onChanged: (v) => setState(() => _imgFormat = v ?? _imgFormat),
        ),
        DropdownButtonFormField<int>(
          initialValue: _imgScale,
          decoration: const InputDecoration(labelText: '1× / 2× / 3×'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('1× (1280×720)')),
            DropdownMenuItem(value: 2, child: Text('2× (2560×1440)')),
            DropdownMenuItem(value: 3, child: Text('3× (3840×2160)')),
          ],
          onChanged: (v) => setState(() => _imgScale = v ?? _imgScale),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.m6TransparentPng),
          value: _transparent,
          onChanged: (v) => setState(() => _transparent = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.m6ContactSheet),
          value: _contactSheet,
          onChanged: (v) => setState(() => _contactSheet = v),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _exportImages(l),
          icon: const Icon(Icons.image_outlined),
          label: Text(l.m6ExportImages),
        ),
      ],
    );
  }

  Future<void> _exportImages(dynamic l) async {
    final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l.m6ChooseFolder);
    if (dir == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final result = await SlideImageExportService.exportSlides(
        widget.slides,
        dir,
        options: SlideImageExportOptions(
          format: _imgFormat,
          scale: _imgScale,
          transparentBackground: _transparent,
          contactSheet: _contactSheet,
          prefix: _prefix,
        ),
        onProgress: (f, i) {
          if (mounted) setState(() => _progress = f);
        },
      );
      if (mounted) _done(l, l.exportSuccessful('${result.count} PNG/JPEG'));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- T43: print & outline ----------------------------------------------

  Widget _buildPrintTab(dynamic l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<HandoutPerPage>(
          initialValue: _perPage,
          decoration: InputDecoration(labelText: l.m6HandoutsPerPage),
          items: HandoutPerPage.values
              .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                      '${switch (p) { HandoutPerPage.two => 2, HandoutPerPage.three => 3, HandoutPerPage.four => 4, HandoutPerPage.six => 6, HandoutPerPage.nine => 9 }} / page')))
              .toList(),
          onChanged: (v) => setState(() => _perPage = v ?? _perPage),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.m6PrintNotes),
          value: _includeNotes,
          onChanged: (v) => setState(() => _includeNotes = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.m6Grayscale),
          value: _grayscale,
          onChanged: (v) => setState(() => _grayscale = v),
        ),
        Row(children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _print(l),
            icon: const Icon(Icons.print),
            label: Text(l.m6Print),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _exportOutline(l),
            icon: const Icon(Icons.notes),
            label: Text(l.m6OutlineRtf),
          ),
        ]),
      ],
    );
  }

  Future<void> _print(dynamic l) async {
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final bytes = await PrintService.buildHandoutPdf(
        widget.slides,
        options: PrintJobOptions(
          perPage: _perPage,
          includeNotes: _includeNotes,
          grayscale: _grayscale,
        ),
      );
      await printing.Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'handouts',
      );
      if (mounted) _done(l, l.m6PrintDone);
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportOutline(dynamic l) async {
    final path = await _pickSavePath('outline.rtf');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await OutlineExportService.writeRtf(widget.slides, path);
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- T44: save formats -------------------------------------------------

  Widget _buildFormatsTab(dynamic l) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _formatButton(l, '.potx', Icons.design_services, () => _saveAs(l, OoxmlDeckKind.template)),
        _formatButton(l, '.ppsx', Icons.slideshow, () => _saveAs(l, OoxmlDeckKind.slideshow)),
        _formatButton(l, '.odp', Icons.description_outlined, () => _saveOdp(l)),
        _formatButton(l, '.ppt', Icons.history_edu, () => _savePpt(l)),
      ],
    );
  }

  Widget _formatButton(dynamic l, String label, IconData icon, VoidCallback onTap) =>
      FilledButton.tonalIcon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon),
        label: Text(label),
      );

  Future<void> _saveAs(dynamic l, OoxmlDeckKind kind) async {
    final ext = PackageFormatService.extensionFor(kind);
    final path = await _pickSavePath('presentation.$ext');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final tmp = '${Directory.systemTemp.path}/ghita_${DateTime.now().millisecondsSinceEpoch}.pptx';
      await PPTGenerator.generatePPT(widget.slides, tmp);
      final bytes = await File(tmp).readAsBytes();
      final rewritten =
          PackageFormatService.rewritePackageType(Uint8List.fromList(bytes), kind);
      if (rewritten == null) throw StateError('Package rewrite failed');
      await File(path).writeAsBytes(rewritten, flush: true);
      try {
        File(tmp).deleteSync();
      } catch (_) {}
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveOdp(dynamic l) async {
    final path = await _pickSavePath('presentation.odp');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await OdpExportService.writeOdp(widget.slides, path);
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePpt(dynamic l) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final tmp = '${Directory.systemTemp.path}/ghita_${DateTime.now().millisecondsSinceEpoch}.pptx';
      await PPTGenerator.generatePPT(widget.slides, tmp);
      final out = await PackageFormatService.convertToPpt(tmp, dir);
      if (mounted) _done(l, l.exportSuccessful(out));
    } catch (e) {
      if (mounted) _fail(l, l.m6PptFallback);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- T45: package & protection ------------------------------------------

  Widget _buildProtectTab(dynamic l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          FilledButton.tonalIcon(
            onPressed: () => _scan(l),
            icon: const Icon(Icons.search),
            label: Text(l.m6Inspect),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _package(l),
            icon: const Icon(Icons.folder_zip),
            label: Text(l.m6Package),
          ),
        ]),
        if (_scanned)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _findings.isEmpty
                  ? l.m6InspectorClean
                  : l.m6InspectorFound(_findings.length),
            ),
          ),
        if (_findings.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _exportCleaned(l),
            icon: const Icon(Icons.cleaning_services),
            label: Text(l.m6CleanExport),
          ),
        const Divider(height: 24),
        TextField(
          decoration: InputDecoration(
              labelText: l.m6ModifyPassword, border: const OutlineInputBorder()),
          obscureText: true,
          onChanged: (v) => _password = v,
        ),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _markFinal(l),
            icon: const Icon(Icons.verified_outlined),
            label: Text(l.m6MarkFinal),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: (_busy || _password.isEmpty) ? null : () => _passwordProtect(l),
            icon: const Icon(Icons.lock_outline),
            label: Text(l.m6ApplyPassword),
          ),
        ]),
      ],
    );
  }

  void _scan(dynamic l) {
    setState(() {
      _findings
        ..clear()
        ..addAll(DocSecurityService.inspect(widget.slides, authorName: 'Ghita'));
      _scanned = true;
    });
  }

  Future<void> _package(dynamic l) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final result = await PackageService.packageDeck(
          widget.slides, '$dir${Platform.pathSeparator}ghita_package',
          createZip: true);
      if (mounted) _done(l, l.exportSuccessful(result.outputDir));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCleaned(dynamic l) async {
    final path = await _pickSavePath('cleaned.pptx');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final cleaned = DocSecurityService.clean(
        widget.slides,
        removeAuthor: true,
        removeEmails: true,
        removePhones: true,
        authorName: 'Ghita',
      );
      await PPTGenerator.generatePPT(cleaned, path);
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markFinal(dynamic l) async {
    final path = await _pickSavePath('final.pptx');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final tmp = '${Directory.systemTemp.path}/ghita_${DateTime.now().millisecondsSinceEpoch}.pptx';
      await PPTGenerator.generatePPT(widget.slides, tmp);
      final out = DocSecurityService.markAsFinal(
          Uint8List.fromList(await File(tmp).readAsBytes()));
      if (out == null) throw StateError('markAsFinal failed');
      await File(path).writeAsBytes(out, flush: true);
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passwordProtect(dynamic l) async {
    final path = await _pickSavePath('protected.pptx');
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final tmp = '${Directory.systemTemp.path}/ghita_${DateTime.now().millisecondsSinceEpoch}.pptx';
      await PPTGenerator.generatePPT(widget.slides, tmp);
      final out = DocSecurityService.applyModifyPassword(
          Uint8List.fromList(await File(tmp).readAsBytes()), _password);
      if (out == null) throw StateError('password protect failed');
      await File(path).writeAsBytes(out, flush: true);
      if (mounted) _done(l, l.exportSuccessful(path));
    } catch (e) {
      if (mounted) _fail(l, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- helpers -------------------------------------------------------------

  Future<String?> _pickSavePath(String defaultName) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save',
      fileName: defaultName,
    );
    return result;
  }

  void _done(dynamic l, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  void _fail(dynamic l, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }
}
