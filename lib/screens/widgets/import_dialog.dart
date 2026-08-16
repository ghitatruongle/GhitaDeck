import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/advanced_import_service.dart';
import '../../models/slide.dart';
import '../../utils/error_mapper.dart';
import '../../l10n/l10n.dart';

/// Import Dialog — v1.2.0 + Track 66 (M10)
/// Import slides from advanced Markdown (tables/lists/code/images), web URL,
/// or files (.docx / .pptx / .pdf) with a live preview before applying.
class ImportDialog extends StatefulWidget {
  final void Function(List<Slide> slides)? onImportSlides;

  const ImportDialog({super.key, this.onImportSlides});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _markdownController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  List<Slide>? _previewSlides;
  String _importMode = 'markdown';
  String? _fileName;

  @override
  void dispose() {
    _markdownController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _importFromMarkdown() async {
    final text = _markdownController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Track 66: advanced markdown — tables, nested lists, code, images, `---`.
      final slides = AdvancedImportService.parseMarkdown(text);
      setState(() {
        _previewSlides = slides;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorMapper.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Track 66: rich web import — title + H1–H3 + paragraphs + lists + images.
      final slides = await AdvancedImportService.importWebRich(url);
      if (!mounted) return; // dialog may have been closed mid-fetch
      setState(() {
        _previewSlides = slides;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorMapper.showErrorSnackBar(context, e);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx', 'pptx', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ErrorMapper.showErrorSnackBar(
            context, StateError('Không đọc được nội dung file'));
      }
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    setState(() {
      _isLoading = true;
      _fileName = file.name;
    });
    try {
      final slides = switch (ext) {
        'docx' => AdvancedImportService.importDocx(bytes),
        'pptx' => AdvancedImportService.importPptx(bytes),
        'pdf' => AdvancedImportService.importPdf(bytes),
        _ => throw StateError('Định dạng không hỗ trợ: .$ext'),
      };
      if (!mounted) return;
      setState(() {
        _previewSlides = slides;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorMapper.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.file_upload),
                  const SizedBox(width: 12),
                  Text(context.l10n.importSlides, style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'markdown', label: Text('Markdown'), icon: Icon(Icons.article)),
                  ButtonSegment(value: 'file', label: Text('File'), icon: Icon(Icons.insert_drive_file)),
                  ButtonSegment(value: 'url', label: Text('Web URL'), icon: Icon(Icons.link)),
                ],
                selected: {_importMode},
                onSelectionChanged: (v) => setState(() => _importMode = v.first),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _importMode == 'markdown'
                    ? Column(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _markdownController,
                              maxLines: null,
                              expands: true,
                              decoration: const InputDecoration(
                                labelText: 'Markdown Content',
                                hintText:
                                    '# Slide 1\n- Point A\n- Point B\n\n| Cột 1 | Cột 2 |\n| --- | --- |\n| A | B |\n\n---\n\n# Slide 2\nParagraph, code block, image…',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.article),
                              label: const Text('Parse Markdown'),
                              onPressed: _isLoading ? null : _importFromMarkdown,
                            ),
                          ),
                        ],
                      )
                    : _importMode == 'file'
                        ? Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.upload_file, size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      _fileName ?? 'Chọn file .docx / .pptx / .pdf',
                                      style: theme.textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.folder_open),
                                      label: const Text('Chọn File'),
                                      onPressed: _isLoading ? null : _pickFile,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              TextField(
                                controller: _urlController,
                                decoration: const InputDecoration(
                                  labelText: 'Web URL',
                                  hintText: 'https://example.com/article',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.download),
                                  label: const Text('Fetch & Convert'),
                                  onPressed: _isLoading ? null : _importFromUrl,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            // Preview
            if (_previewSlides != null) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preview: ${_previewSlides!.length} slides', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _previewSlides!.length,
                        itemBuilder: (ctx, i) {
                          final slide = _previewSlides![i];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}. ${slide.title}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    slide.htmlContent.replaceAll(RegExp(r'<[^>]+>'), ''),
                                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isLoading) ...[
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                  ],
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _previewSlides == null || _previewSlides!.isEmpty
                        ? null
                        : () {
                            widget.onImportSlides?.call(_previewSlides!);
                            Navigator.pop(context);
                          },
                    child: Text('Thêm ${_previewSlides?.length ?? 0} Slides'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
