import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/export_options.dart';
import '../../models/ppt_theme_setting.dart';
import '../../providers/presentation_state.dart';
import '../../providers/theme_provider.dart';
import '../../l10n/l10n.dart';
import 'm6_export_dialog.dart';

/// Advanced export dialog with options for selected slides, aspect ratio, quality
class AdvancedExportDialog extends StatefulWidget {
  const AdvancedExportDialog({super.key});

  @override
  State<AdvancedExportDialog> createState() => _AdvancedExportDialogState();
}

class _AdvancedExportDialogState extends State<AdvancedExportDialog> {
  PresentationExportFormat _format = PresentationExportFormat.pptx;
  ExportAspectRatio _aspectRatio = ExportAspectRatio.widescreen16x9;
  ExportQuality _quality = ExportQuality.medium;
  bool _includeNotes = true;
  bool _includeBackgrounds = true;
  bool _fitContent = true;
  PdfPaperSize _pdfPaperSize = PdfPaperSize.matchSlide;
  PdfMarginPreset _pdfMarginPreset = PdfMarginPreset.standard;
  bool _pdfScaleToFit = true;
  bool _includeHiddenSlides = false;
  bool _allSlides = true;
  final Set<int> _selectedSlideIndices = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedSlideIndices.clear();
  }

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);
    final slides = presentationState.slides;
    final theme = Theme.of(context);

    return Semantics(
      namesRoute: true,
      label: context.l10n.advancedExport,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(context.l10n.advancedExport),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Format selection
                _buildSectionTitle(context, context.l10n.exportFormat),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PresentationExportFormat.values.map((format) {
                    return ChoiceChip(
                      label: Text(format.label),
                      selected: _format == format,
                      onSelected: (_) => setState(() => _format = format),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Aspect ratio
                _buildSectionTitle(context, context.l10n.aspectRatio),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ExportAspectRatio.values.map((ratio) {
                    return ChoiceChip(
                      label: Text(ratio.label),
                      selected: _aspectRatio == ratio,
                      onSelected: (_) => setState(() => _aspectRatio = ratio),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Quality
                _buildSectionTitle(context, context.l10n.quality),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ExportQuality.values.map((q) {
                    return ChoiceChip(
                      label: Text(q.label),
                      selected: _quality == q,
                      onSelected: (_) => setState(() => _quality = q),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Options
                _buildSectionTitle(context, context.l10n.exportOptions),
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  title: Text(context.l10n.includeSpeakerNotes),
                  value: _includeNotes,
                  onChanged: (v) => setState(() => _includeNotes = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  dense: true,
                  title: Text(context.l10n.includeBackgrounds),
                  value: _includeBackgrounds,
                  onChanged: (v) =>
                      setState(() => _includeBackgrounds = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  dense: true,
                  title: Text(context.l10n.fitContent),
                  subtitle: Text(context.l10n.fitContentDescription),
                  value: _fitContent,
                  onChanged: (v) => setState(() => _fitContent = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_format == PresentationExportFormat.pdf) ...[
                  const SizedBox(height: 12),
                  _buildSectionTitle(context, context.l10n.pdfPaperSize),
                  const SizedBox(height: 8),
                  _buildPdfOptions(context),
                ],
                const SizedBox(height: 8),

                // Slide selection
                _buildSectionTitle(context, context.l10n.slidesToExport),
                const SizedBox(height: 8),
                RadioGroup<bool>(
                  groupValue: _allSlides,
                  onChanged: (v) => setState(() {
                    if (v == null) return;
                    _allSlides = v;
                    if (v) _selectedSlideIndices.clear();
                  }),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          dense: true,
                          title: Text(context.l10n.allSlides),
                          value: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          dense: true,
                          title: Text(context.l10n
                              .selectedSlides(_selectedSlideIndices.length)),
                          value: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_allSlides)
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(slides.length, (index) {
                          final selected =
                              _selectedSlideIndices.contains(index);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(
                              '${index + 1}. ${slides[index].title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v ?? false) {
                                  _selectedSlideIndices.add(index);
                                } else {
                                  _selectedSlideIndices.remove(index);
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isExporting ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          // Milestone 6 tools (T41–T45): video/GIF, slide images, print,
          // extended formats (.potx/.ppsx/.odp/.ppt) and package/security.
          OutlinedButton.icon(
            icon: const Icon(Icons.apps, size: 18),
            label: Text(context.l10n.m6Title),
            onPressed: _isExporting
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (_) => M6ExportDialog(
                        slides: presentationState.slides
                            .map((s) => s.toMap())
                            .toList(),
                      ),
                    ),
          ),
          FilledButton.icon(
            icon: _isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.file_download, size: 18),
            label: Text(
                _isExporting ? context.l10n.exporting : context.l10n.export),
            onPressed: _isExporting
                ? null
                : () => _performExport(context, presentationState),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  /// PDF-only options (Track 06): paper size, margins, scale-to-fit and
  /// hidden-slide inclusion.
  Widget _buildPdfOptions(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PdfPaperSize.values.map((size) {
            return ChoiceChip(
              label: Text(switch (size) {
                PdfPaperSize.matchSlide => l.pdfPaperMatchSlide,
                PdfPaperSize.a4 => l.pdfPaperA4,
                PdfPaperSize.letter => l.pdfPaperLetter,
              }),
              selected: _pdfPaperSize == size,
              onSelected: (_) => setState(() => _pdfPaperSize = size),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PdfMarginPreset>(
          initialValue: _pdfMarginPreset,
          decoration: InputDecoration(
            labelText: l.pdfMargins,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: PdfMarginPreset.values.map((preset) {
            return DropdownMenuItem(
              value: preset,
              child: Text(switch (preset) {
                PdfMarginPreset.compact => l.pdfMarginCompact,
                PdfMarginPreset.standard => l.pdfMarginStandard,
                PdfMarginPreset.wide => l.pdfMarginWide,
              }),
            );
          }).toList(),
          onChanged: (v) => setState(() => _pdfMarginPreset = v ?? _pdfMarginPreset),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          dense: true,
          title: Text(l.pdfScaleToFit),
          value: _pdfScaleToFit,
          onChanged: (v) => setState(() => _pdfScaleToFit = v ?? true),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          dense: true,
          title: Text(l.includeHiddenSlides),
          value: _includeHiddenSlides,
          onChanged: (v) =>
              setState(() => _includeHiddenSlides = v ?? false),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// Build the PPTX theme from the user's theme settings — only when they
  /// actually customized the theme (the untouched Office Blue preset exports
  /// exactly like v1.6.3).
  static PptThemeSetting? _userPptTheme(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.presetTheme == PresetTheme.officeBlue) return null;
    String hex(Color color) => color.toARGB32().toRadixString(16).padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return PptThemeSetting(
      accent1: hex(themeProvider.primaryColor),
      accent2: hex(themeProvider.accentColor),
      fontMinor: themeProvider.fontFamily,
    );
  }

  Future<void> _performExport(
      BuildContext context, PresentationState presentationState) async {
    if (!_allSlides && _selectedSlideIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chooseAtLeastOneSlide)),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final indices = _allSlides
          ? List.generate(presentationState.slides.length, (i) => i)
          : _selectedSlideIndices.toList()
        ..sort();

      final options = ExportOptions(
        format: _format,
        aspectRatio: _aspectRatio,
        quality: _quality,
        includeNotes: _includeNotes,
        includeBackgrounds: _includeBackgrounds,
        fitContent: _fitContent,
        // Track 02/04: the user's customized theme (colors + font) lands in
        // the PPTX theme part. The untouched Office Blue preset keeps the
        // v1.6.3 defaults byte-for-byte (no theme attached).
        theme: _userPptTheme(context),
        pdfPaperSize: _pdfPaperSize,
        pdfMarginPreset: _pdfMarginPreset,
        pdfScaleToFit: _pdfScaleToFit,
        includeHiddenSlides: _includeHiddenSlides,
        // Track 07, P9: deck player strings follow the app locale.
        htmlPlayerLocale:
            Localizations.localeOf(context).languageCode == 'vi' ? 'vi' : 'en',
        allSlides: _allSlides,
        selectedSlideIndices: indices,
      );
      final summary =
          '${_format.label} | ${_aspectRatio.label} | ${_quality.label} | ${indices.length} slides';
      final fileName = 'presentation_${DateTime.now().millisecondsSinceEpoch}';
      await presentationState.exportWithOptions(fileName, options);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.exportSuccessful(summary)),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.exportFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
