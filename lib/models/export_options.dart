import 'ppt_theme_setting.dart';

/// Output format for a presentation export.
enum PresentationExportFormat {
  pptx('PowerPoint (.pptx)', 'pptx'),
  html('HTML presentation (.html)', 'html'),
  pdf('PDF document (.pdf)', 'pdf'),
  docx('Word report (.docx)', 'docx');

  final String label;
  final String extension;

  const PresentationExportFormat(this.label, this.extension);
}

/// Supported canvas dimensions. Values use English Metric Units (EMUs), the
/// native coordinate system for PresentationML. They are also the single
/// source of truth for the PDF and HTML renderers.
enum ExportAspectRatio {
  widescreen16x9(
    '16:9 (Widescreen)',
    12192000,
    6858000,
    '16 / 9',
    'screen16x9',
  ),
  standard4x3(
    '4:3 (Standard)',
    9144000,
    6858000,
    '4 / 3',
    'screen4x3',
  ),
  square1x1(
    '1:1 (Square)',
    6858000,
    6858000,
    '1 / 1',
    null,
  ),
  portrait9x16(
    '9:16 (Portrait/Mobile)',
    5143500,
    9144000,
    '9 / 16',
    null,
  );

  final String label;
  final int widthEmu;
  final int heightEmu;
  final String cssAspectRatio;

  /// The Office preset used for standard sizes. Custom dimensions intentionally
  /// omit it so PowerPoint respects their exact EMU values.
  final String? pptxPreset;

  const ExportAspectRatio(
    this.label,
    this.widthEmu,
    this.heightEmu,
    this.cssAspectRatio,
    this.pptxPreset,
  );

  double get ratio => widthEmu / heightEmu;
  double get widthInches => widthEmu / 914400;
  double get heightInches => heightEmu / 914400;
}

/// Image-rasterization ceiling for an export. Text and vectors remain sharp;
/// this setting only changes embedded bitmap resolution and file size.
enum ExportQuality {
  low('Low (150 px images)', 150),
  medium('Medium (300 px images)', 300),
  high('High (600 px images)', 600);

  final String label;
  final int imageMaxWidth;

  const ExportQuality(this.label, this.imageMaxWidth);
}

/// PDF page size (Track 06, P2). [matchSlide] keeps the v1.6.3 behavior: one
/// page exactly the size of the slide.
enum PdfPaperSize {
  matchSlide('Match slide'),
  a4('A4'),
  letter('Letter');

  final String label;

  const PdfPaperSize(this.label);
}

/// PDF page-margin presets in points (Track 06, P3).
enum PdfMarginPreset {
  compact('Compact', 24),
  standard('Standard', 48),
  wide('Wide', 72);

  final String label;
  final double points;

  const PdfMarginPreset(this.label, this.points);
}

/// A complete, format-independent export request.
///
/// The caller may select all slides or an explicit set of zero-based indices.
/// Invalid selections fail early instead of silently exporting a different
/// deck than the user asked for.
class ExportOptions {
  const ExportOptions({
    required this.format,
    this.aspectRatio = ExportAspectRatio.widescreen16x9,
    this.quality = ExportQuality.medium,
    this.includeNotes = true,
    this.includeBackgrounds = true,
    this.fitContent = true,
    this.theme,
    this.pdfPaperSize = PdfPaperSize.matchSlide,
    this.pdfMarginPreset = PdfMarginPreset.standard,
    this.pdfScaleToFit = true,
    this.pdfNotesPages = false,
    this.pdfBookmarks = false,
    this.docxIncludeSlideList = true,
    this.includeHiddenSlides = false,
    this.htmlPlayerLocale = 'en',
    this.allSlides = true,
    this.selectedSlideIndices = const [],
  });

  final PresentationExportFormat format;
  final ExportAspectRatio aspectRatio;
  final ExportQuality quality;
  final bool includeNotes;
  final bool includeBackgrounds;

  /// PPTX only: shrink overflowing text so the whole deck fits its slides.
  final bool fitContent;

  /// PPTX only: user theme (colors + fonts) written into the theme part;
  /// null keeps the v1.6.3 Office defaults.
  final PptThemeSetting? theme;

  /// PDF only: page size (default = match slide, the v1.6.3 behavior).
  final PdfPaperSize pdfPaperSize;

  /// PDF only: page margins in points (default Standard = the legacy inset).
  final PdfMarginPreset pdfMarginPreset;

  /// PDF only: scale the slide to fit page size minus margins.
  final bool pdfScaleToFit;

  /// T06: dedicated speaker-notes pages in the PDF (one per slide with notes).
  final bool pdfNotesPages;

  /// T06: PDF outline entries (bookmarks panel), one per slide.
  final bool pdfBookmarks;

  /// DOCX only: append the numbered slide index at the end of the report.
  final bool docxIncludeSlideList;

  /// PDF only: keep slides marked hidden in the exported document.
  final bool includeHiddenSlides;

  /// HTML only: player control strings locale ('en' | 'vi', Track 07, P9).
  final String htmlPlayerLocale;
  final bool allSlides;
  final List<int> selectedSlideIndices;

  List<T> selectSlides<T>(List<T> source) {
    if (source.isEmpty) {
      throw ArgumentError.value(
          source, 'source', 'There are no slides to export');
    }
    if (allSlides) return List<T>.from(source);

    final indices = selectedSlideIndices.toSet().toList()..sort();
    if (indices.isEmpty) {
      throw ArgumentError.value(
        selectedSlideIndices,
        'selectedSlideIndices',
        'Select at least one slide or export all slides',
      );
    }
    if (indices.any((index) => index < 0 || index >= source.length)) {
      throw RangeError.range(
        indices.firstWhere((index) => index < 0 || index >= source.length),
        0,
        source.length - 1,
        'selectedSlideIndices',
      );
    }
    return indices.map((index) => source[index]).toList();
  }
}
