import 'dart:io';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/chart_data.dart';
import '../models/export_options.dart';
import '../models/free_shape.dart';
import '../models/icon_item.dart';
import '../models/media_item.dart';
import '../models/smartart.dart';
import '../models/drawn_shape.dart';
import 'action_button_service.dart';
import 'equation_service.dart';
import 'header_footer_service.dart';
import 'ole_service.dart';
import 'zoom_feature_service.dart';
import 'cameo_service.dart';
import 'export_primitives.dart';
import 'ppt_generator.dart';
import 'html_image_loader.dart';
import 'icon_library_service.dart';

/// Renders slides to a PDF document (Track 06).
///
/// Reuses [PPTGenerator.parseHtmlContentFull] so PPTX and PDF exports share
/// the exact same HTML interpretation.
///
/// Defaults reproduce the v1.6.3 output: one page per slide at the slide's
/// exact size. New options: A4/Letter pages with margins and scale-to-fit,
/// per-quality image compression, hidden-slide filtering and document
/// metadata. The system fonts are embedded per document as glyph subsets,
/// so Vietnamese renders identically on machines without those fonts.
class PdfExportService {
  /// Compiled once — path parsing runs per shape per slide per export.
  static final RegExp _cmdRe = RegExp(r'[MmLlHhVvCcSsQqTtZz]');
  static final RegExp _numRe =
      RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');

  /// Cached Unicode theme built from Windows system fonts.
  static pw.ThemeData? _cachedTheme;
  static bool _themeLoaded = false;

  /// Map an image-max-width ceiling (ExportQuality 150/300/600 px) to the
  /// JPEG quality used for PDF-embedded images (Track 06, P5).
  static int _jpegQualityFor(int? imageMaxWidth) {
    switch (imageMaxWidth) {
      case 150:
        return 60;
      case 600:
        return 85;
      default:
        return 75;
    }
  }

  /// Font family candidates with full Vietnamese/Unicode coverage, in
  /// preference order: [regular, bold, italic, boldItalic].
  static const List<List<String>> _fontCandidates = [
    ['segoeui.ttf', 'segoeuib.ttf', 'segoeuii.ttf', 'segoeuiz.ttf'],
    ['arial.ttf', 'arialbd.ttf', 'ariali.ttf', 'arialbi.ttf'],
    ['tahoma.ttf', 'tahomabd.ttf', 'tahoma.ttf', 'tahomabd.ttf'],
  ];

  /// Load a Unicode font theme from Windows system fonts so Vietnamese and
  /// other non-Latin-1 text renders correctly (the pdf package's built-in
  /// Helvetica has no Unicode support). Returns null when unavailable
  /// (non-Windows or fonts missing) — callers fall back to the default theme.
  static Future<pw.ThemeData?> loadSystemTheme() async {
    if (_themeLoaded) return _cachedTheme;
    _themeLoaded = true;

    final fontsDir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    for (final family in _fontCandidates) {
      try {
        final files =
            family.map((name) => File('$fontsDir\\Fonts\\$name')).toList();
        if (!files[0].existsSync()) continue;

        Future<pw.Font> loadFont(File f, File fallback) async {
          final source = f.existsSync() ? f : fallback;
          final bytes = await source.readAsBytes();
          return pw.Font.ttf(bytes.buffer.asByteData());
        }

        final base = await loadFont(files[0], files[0]);
        final bold = await loadFont(files[1], files[0]);
        final italic = await loadFont(files[2], files[0]);
        final boldItalic = await loadFont(files[3], files[1]);
        _cachedTheme = pw.ThemeData.withFont(
          base: base,
          bold: bold,
          italic: italic,
          boldItalic: boldItalic,
        );
        return _cachedTheme;
      } catch (_) {
        // Try the next family.
      }
    }
    return null;
  }

  Future<String> exportToPdf(
    List<Map<String, dynamic>> slides,
    String outputPath, {
    bool widescreen = true,
    ExportAspectRatio? aspectRatio,
    bool includeNotes = false,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    HtmlParseCache? parseCache,
    ExportCancelToken? cancelToken,
    ExportProgressCallback? onProgress,
    PdfPaperSize paperSize = PdfPaperSize.matchSlide,
    PdfMarginPreset marginPreset = PdfMarginPreset.standard,
    bool scaleToFit = true,
    bool includeHiddenSlides = false,
    DeckMeta? deckMeta,
  }) async {
    // Track 06, P6: hidden slides stay out unless explicitly requested.
    final visible = includeHiddenSlides
        ? slides
        : slides.where((slide) => slide['hidden'] != true).toList();
    if (visible.isEmpty) {
      throw Exception('No slides to export.');
    }

    final theme = await loadSystemTheme();
    // Track 06, P7: document metadata (title from the first slide).
    final firstTitle = (visible.first['title'] ?? 'Presentation').toString();
    final doc = pw.Document(
      theme: theme,
      title: firstTitle,
      author: 'Ghita PPT Converter',
      creator: 'Ghita PPT Converter',
      subject: 'Exported from GhitaPPT',
    );
    final selectedRatio = aspectRatio ??
        (widescreen
            ? ExportAspectRatio.widescreen16x9
            : ExportAspectRatio.standard4x3);
    final slideWidth = selectedRatio.widthInches * PdfPageFormat.inch;
    final slideHeight = selectedRatio.heightInches * PdfPageFormat.inch;
    final marginPt = marginPreset.points;

    // Page geometry: matchSlide keeps the v1.6.3 exact-slide pages; A4/Letter
    // are landscape pages whose margins come from the preset.
    final PdfPageFormat pageFormat;
    switch (paperSize) {
      case PdfPaperSize.a4:
        pageFormat = PdfPageFormat(842, 595, marginAll: marginPt);
      case PdfPaperSize.letter:
        pageFormat = PdfPageFormat(792, 612, marginAll: marginPt);
      case PdfPaperSize.matchSlide:
        pageFormat = PdfPageFormat(slideWidth, slideHeight);
    }
    // Track 06, P3: scale the slide canvas to fit page size minus margins
    // (never upscale — that would blur text).
    final double scale;
    if (paperSize == PdfPaperSize.matchSlide) {
      scale = 1.0;
    } else if (!scaleToFit) {
      scale = 1.0;
    } else {
      final fit = ((pageFormat.width - 2 * marginPt) / slideWidth)
          .clamp(0.05, 1.0);
      final fitHeight = ((pageFormat.height - 2 * marginPt) / slideHeight)
          .clamp(0.05, 1.0);
      scale = fit < fitHeight ? fit : fitHeight;
    }

    for (int i = 0; i < visible.length; i++) {
      // Cooperative cancellation + per-slide progress (Track 01).
      cancelToken?.throwIfCancelled();
      onProgress?.call(ExportProgressBudget.forSlide(i, visible.length));
      final slide = visible[i];
      final title = (slide['title'] ?? 'Slide ${i + 1}').toString();
      final rawHtml = (slide['htmlContent'] ?? '').toString();
      final blocks = PPTGenerator.parseHtmlContentFull(rawHtml,
          parseCache: parseCache);
      final bgColor = includeBackgrounds ? _extractBgColor(slide) : null;
      final notes = includeNotes
          ? _extractNotes(slide, rawHtml, parseCache: parseCache)
          : '';

      // The slide canvas (identical rendering to v1.6.3, whatever the page
      // size — on A4/Letter the whole canvas is scaled down to fit).
      final slideCanvas = pw.Container(
        color: bgColor,
        width: double.infinity,
        height: double.infinity,
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                color: bgColor != null ? _contrastColor(bgColor) : null,
              ),
            ),
            pw.SizedBox(height: 14),
            // Reserve the notes area before laying out the visible slide
            // body.  A bounded, clipped body is preferable to a PDF page
            // whose title/notes are pushed outside its bounds.
            pw.Expanded(
              child: pw.ClipRect(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: _buildBlocks(
                    blocks,
                    bgColor,
                    imageMaxWidth: imageMaxWidth,
                    maxImageHeight: notes.isNotEmpty ? 150.0 : 260.0,
                  ),
                ),
              ),
            ),
            // Track 17, P6: free-form text elements from visualElements.
            if (slide['visualElements'] is Map &&
                (slide['visualElements'] as Map)['freeTexts'] is List) ...[
              for (final raw in ((slide['visualElements'] as Map)['freeTexts'] as List))
                _buildFreeTextPdf(raw),
            ],
            // Track 21: drawn shapes from visualElements.
            if (slide['visualElements'] is Map &&
                (slide['visualElements'] as Map)['shapes'] is List) ...[
              for (final raw in ((slide['visualElements'] as Map)['shapes'] as List))
                _buildShapePdf(raw),
            ],
            if (notes.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Speaker notes',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(notes, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

      // Track 19, P5: header/footer bars drawn on each PDF page.
      // P7: when excludeFirst is on, the title slide (i == 0) gets no bars.
      final hfHeader = (deckMeta?.excludeFirst ?? false) && i == 0 ? '' : (deckMeta?.header ?? '');
      final hfFooter = (deckMeta?.excludeFirst ?? false) && i == 0 ? '' : (deckMeta?.footer ?? '');
      final showNum = (deckMeta?.excludeFirst ?? false) && i == 0 ? false : (deckMeta?.slideNumber ?? false);
      final showDate = (deckMeta?.excludeFirst ?? false) && i == 0 ? false : (deckMeta?.dateTime ?? false);
      final dateFormat = deckMeta?.dateTimeFormat ?? 'yyyy-MM-dd';
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: paperSize == PdfPaperSize.matchSlide
              ? pw.EdgeInsets.zero
              : pw.EdgeInsets.all(marginPt),
          build: (context) {
            if (paperSize == PdfPaperSize.matchSlide) return _wrapWithHF(slideCanvas, hfHeader, hfFooter, showNum, showDate, dateFormat, i + 1);
            return pw.Center(
              child: pw.Transform.scale(
                scale: scale,
                child: pw.SizedBox(
                  width: slideWidth,
                  height: slideHeight,
                  child: _wrapWithHF(slideCanvas, hfHeader, hfFooter, showNum, showDate, dateFormat, i + 1),
                ),
              ),
            );
          },
        ),
      );
    }

    final outputFile = File(outputPath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsBytes(await doc.save());
    return outputFile.path;
  }

  List<pw.Widget> _buildBlocks(
    List<Map<String, dynamic>> blocks,
    PdfColor? bgColor, {
    int? imageMaxWidth,
    double maxImageHeight = 260,
  }) {
    final widgets = <pw.Widget>[];
    final defaultColor = bgColor != null ? _contrastColor(bgColor) : null;

    for (final block in blocks) {
      final type = block['type'] as String;
      switch (type) {
        case 'smartart':
          // Track 10, P4: paint the diagram with the same colours as the
          // SVG/PPTX renderers (title rendered as a widget above).
          final graph = SmartArtGraph.fromJson(
              (block['data-smartart'] ?? '').toString());
          if (graph != null) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (graph.title.isNotEmpty)
                    pw.Text(
                      graph.title,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.CustomPaint(
                    size: const PdfPoint(470, 200),
                    painter: (canvas, size) =>
                        _paintSmartArt(canvas, size, graph),
                  ),
                ],
              ),
            ));
          }
          break;
        case 'chart':
          // Track 08, P5: paint the chart with the same colours as the
          // PPTX/HTML renderers (title + legend rendered as widgets; the
          // canvas carries the geometry).
          final chart =
              ChartData.fromJson((block['data-chart'] ?? '').toString());
          if (chart != null) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (chart.title.isNotEmpty)
                    pw.Text(
                      chart.title,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.CustomPaint(
                    size: const PdfPoint(470, 200),
                    painter: (canvas, size) =>
                        _paintChart(canvas, size, chart),
                  ),
                  if (chart.style.showLegend && chart.series.length > 1)
                    pw.Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (var s = 0; s < chart.series.length; s++)
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Container(
                                width: 8,
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color:
                                      PdfColor.fromHex(chart.style.colorAt(s)),
                                ),
                              ),
                              pw.SizedBox(width: 4),
                              pw.Text(
                                chart.series[s].name,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ));
          }
          break;
        case 'text':
          final paragraphs =
              (block['paragraphs'] as List).cast<Map<String, String>>();
          for (final runs in _groupRuns(paragraphs, 'paragraphStart')) {
            if (runs.every((run) =>
                (run['text'] ?? '').isEmpty && run['isBreak'] != 'true')) {
              continue;
            }
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: _richText(runs, 16, defaultColor),
            ));
          }
          break;
        case 'list':
          final ordered = block['ordered'] == true;
          final items = (block['items'] as List).cast<Map<String, String>>();
          final itemGroups = _groupRuns(items, 'itemStart');
          for (int i = 0; i < itemGroups.length; i++) {
            final itemRuns = itemGroups[i];
            if (itemRuns.every((run) => (run['text'] ?? '').isEmpty)) {
              continue;
            }
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(ordered ? '${i + 1}. ' : '\u2022 ',
                      style: _runStyle(itemRuns.first, 15, defaultColor)),
                  pw.Expanded(
                    child: _richText(itemRuns, 15, defaultColor),
                  ),
                ],
              ),
            ));
          }
          break;
        case 'table':
          final rowsDynamic = block['rows'] as List? ?? [];
          if (rowsDynamic.isEmpty) break;
          final rows = rowsDynamic
              .map((r) => (r as List)
                  .map((c) => Map<String, String>.from(c as Map))
                  .toList())
              .toList();
          final headerRow = block['headerRow'] == true;
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.TableHelper.fromTextArray(
              headers: headerRow && rows.isNotEmpty
                  ? rows.first.map((c) => c['text'] ?? '').toList()
                  : null,
              data: (headerRow && rows.isNotEmpty ? rows.skip(1) : rows)
                  .map((r) => r.map((c) => c['text'] ?? '').toList())
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 12, color: defaultColor),
              headerStyle: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: defaultColor),
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            ),
          ));
          break;
        case 'image':
          final src = (block['src'] ?? '').toString();
          // Track 06, P5: large opaque PNGs embed as JPEG at a quality tied
          // to ExportQuality so low-quality exports produce smaller PDFs.
          final loaded = HtmlImageLoader.load(
            src,
            maxWidth: imageMaxWidth,
            allowJpeg: true,
            jpegQuality: _jpegQualityFor(imageMaxWidth),
          );
          if (loaded != null) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(loaded.bytes),
                  height: maxImageHeight,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ));
          }
          break;
        case 'video':
          // Track 11, P4: print output draws the poster frame (video cannot
          // play on paper); without a poster, a labelled placeholder box.
          final data = VideoData.fromJson(
              (block['data-video'] ?? '').toString());
          final posterSrc = data.poster.isNotEmpty
              ? data.poster
              : (block['poster'] ?? '').toString();
          final loadedVideo = posterSrc.isNotEmpty
              ? HtmlImageLoader.load(posterSrc, maxWidth: imageMaxWidth)
              : null;
          if (loadedVideo != null) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(loadedVideo.bytes),
                  height: maxImageHeight,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ));
          } else {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Container(
                height: maxImageHeight,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey800,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Video',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ));
          }
          break;
        case 'model3d':
          // Track 14: print output shows a labelled placeholder — the GLB is
          // never embedded in PDFs and the SVG poster is not rasterizable
          // here (honest limit; PowerPoint carries the real model).
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Container(
              height: maxImageHeight,
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey800,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              alignment: pw.Alignment.center,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    '3D Model',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.Text(
                    'Xem trong PowerPoint',
                    style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
                  ),
                ],
              ),
            ),
          ));
          break;
        case 'icon':
          // Track 15, P4: render the icon as a centred PNG raster.
          final icon = IconItem.fromJson(
              (block['data-icon'] ?? '').toString());
          if (icon.svgPath.isNotEmpty) {
            final bytes = IconLibraryService.renderPng(icon, size: 48);
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  height: 36,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ));
          }
          break;
        case 'action':
          // Track 18, P1–P2: render a labelled action button.
          final button = ActionButton.fromJson(
              (block['data-action'] ?? '').toString());
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                button.label.isEmpty ? button.defaultLabel : button.label,
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
            ),
          ));
          break;
        case 'equation':
          // Track 18, P3–P4: render the equation as a styled PDF widget
          // using the same layout engine as the SVG renderer — draws
          // fractions, radicals, superscripts, and subscripts with PDF
          // primitives.
          final eq = EquationData.fromJson(
              (block['data-equation'] ?? '').toString());
          final pdfWidget = _buildEquationPdf(eq.mathml);
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pdfWidget,
          ));
          break;
        case 'ole':
          // Track 18, P6: render the OLE object as a styled document icon.
          final ole = OleData.fromJson(
              (block['data-ole'] ?? '').toString());
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('📄', style: const pw.TextStyle(fontSize: 24)),
                  pw.SizedBox(height: 4),
                  pw.Text(ole.iconLabel,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      )),
                  pw.Text(ole.fileName,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ),
          ));
          break;
        case 'zoom':
          // Track 20, P5: render the slide zoom as a blue labelled box.
          final zoom = ZoomItem.fromJson(
              (block['data-zoom'] ?? '').toString());
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                zoom.thumbnailLabel.isEmpty
                    ? 'Slide ${zoom.targetSlide + 1}'
                    : zoom.thumbnailLabel,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ));
          break;
        case 'sectionzoom':
          // Track 20, P6: render the Section/Summary Zoom as a labelled
          // tile grid (one box per entry).
          final sz = SectionZoomData.fromJson(
              (block['data-sectionzoom'] ?? '').toString());
          final cols = sz.columns.clamp(1, 4);
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in sz.entries)
                  pw.Container(
                    width:
                        (sz.w <= 0 ? 80 : sz.w) / cols,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      e.label.isEmpty ? 'Slide ${e.slide + 1}' : e.label,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ));
          break;
        case 'cameo':
          // Track 20, P8: render the cameo as a dark camera placeholder box.
          final cameo = CameoData.fromJson(
              (block['data-cameo'] ?? '').toString());
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey900,
                border: pw.Border.all(color: PdfColors.blue400, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(cameo.label,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      )),
                  pw.Text('Live camera',
                      style: const pw.TextStyle(
                        color: PdfColors.grey500,
                        fontSize: 9,
                      )),
                ],
              ),
            ),
          ));
          break;
      }
    }
    return widgets;
  }

  /// Render one free-form text element (Track 17, P6) as an absolutely
  /// positioned PDF widget — the slide canvas is ~7.5in wide, so % maps to
  /// points (1% = 0.75pt at 75pt/in width).
  pw.Widget _buildFreeTextPdf(dynamic raw) {
    final ft = raw is Map<String, dynamic>
        ? FreeTextShape.fromMap(raw)
        : (raw is Map
            ? FreeTextShape.fromMap(Map<String, dynamic>.from(raw))
            : const FreeTextShape());
    final color = _parseHex(ft.color);
    final bg = ft.backgroundColor == 'transparent'
        ? null
        : _parseHex(ft.backgroundColor);
    return pw.Positioned(
      left: ft.x * 0.75,
      top: ft.y * 0.75,
      child: pw.Container(
        width: ft.w * 0.75,
        height: ft.h * 0.75,
        color: bg,
        alignment: pw.Alignment.center,
        child: pw.Text(
          ft.text,
          style: pw.TextStyle(
            fontSize: ft.fontSize,
            color: color,
            fontWeight: ft.fontWeight == 'bold'
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            fontStyle: ft.fontStyle == 'italic'
                ? pw.FontStyle.italic
                : pw.FontStyle.normal,
          ),
        ),
      ),
    );
  }

  /// Render one drawn shape element (Track 21, P6) as an absolutely
  /// positioned PDF widget — the slide canvas is ~7.5in wide, so % maps to
  /// points (1% = 0.75pt at 75pt/in width). Each shape type is drawn with
  /// its real geometry: rect/oval/line/arrow primitives and freeform/
  /// merged SVG paths (M/L/H/V/C/S/Q/T) via a path painter.
  pw.Widget _buildShapePdf(dynamic raw) {
    final shape = raw is Map<String, dynamic>
        ? DrawnShape.fromMap(raw)
        : (raw is Map
            ? DrawnShape.fromMap(Map<String, dynamic>.from(raw))
            : const DrawnShape());
    return pw.Positioned(
      left: shape.x * 0.75,
      top: shape.y * 0.75,
      child: pw.CustomPaint(
        size: PdfPoint(shape.w * 0.75, shape.h * 0.75),
        painter: (canvas, size) =>
            _paintDrawnShape(canvas, size, shape),
      ),
    );
  }

  /// Paint a [DrawnShape] onto a PDF canvas with its real geometry.
  void _paintDrawnShape(PdfGraphics canvas, PdfPoint size, DrawnShape shape) {
    final fill = _parseHex(shape.fillColor);
    final stroke = _parseHex(shape.strokeColor);
    final w = size.x;
    final h = size.y;
    final fillOpacity = 1.0 - shape.fillTransparency;
    final sw = shape.strokeWidth;
    final hasFill = fill != null && fillOpacity > 0;
    final hasStroke = stroke != null && sw > 0;

    PdfColor fillWith(double opacity) => fillOpacity >= 1
        ? fill!
        : PdfColor.fromHex(_withAlpha(shape.fillColor, (opacity * 255).round()));
    final strokeColor = stroke ?? PdfColors.black;

    void strokePath() {
      if (hasStroke) {
        canvas.setColor(strokeColor);
        canvas.setLineWidth(sw);
        canvas.strokePath(close: true);
      }
    }

    void fillPath() {
      if (hasFill) {
        canvas.setFillColor(fillWith(fillOpacity));
        canvas.fillPath();
      }
      strokePath();
    }

    // Track 25, P5: flattened shadow (kept minimal to avoid bloating the
    // PDF). Drawn as an offset, semi-transparent copy of the geometry.
    if (shape.effect.shadow) {
      _paintFlattenedShadow(canvas, w, h, shape);
    }

    final hasGrad =
        shape.gradientStart.isNotEmpty && shape.gradientEnd.isNotEmpty;
    if (hasGrad && hasFill) {
      // Linear gradient approximated with interpolated colour bands.
      _paintGradientFill(canvas, 0, 0, w, h, shape);
    }

    switch (shape.type) {
      case ShapeType.rect:
        if (hasFill && !hasGrad) {
          canvas.setFillColor(fillWith(fillOpacity));
          canvas.drawRect(0, 0, w, h);
          canvas.fillPath();
        }
        if (hasStroke) {
          canvas.setColor(strokeColor);
          canvas.setLineWidth(sw);
          canvas.drawRect(0, 0, w, h);
          canvas.strokePath(close: true);
        }
        break;
      case ShapeType.oval:
        if (hasFill && !hasGrad) {
          canvas.setFillColor(fillWith(fillOpacity));
          canvas.drawEllipse(w / 2, h / 2, w / 2, h / 2);
          canvas.fillPath();
        }
        if (hasStroke) {
          canvas.setColor(strokeColor);
          canvas.setLineWidth(sw);
          canvas.drawEllipse(w / 2, h / 2, w / 2, h / 2);
          canvas.strokePath(close: true);
        }
        break;
      case ShapeType.line:
        if (hasStroke) {
          canvas.setColor(strokeColor);
          canvas.setLineWidth(sw);
          canvas.drawLine(0, h, w, 0);
        }
        break;
      case ShapeType.arrow:
        // Right-pointing arrow triangle.
        canvas
          ..moveTo(0, 0)
          ..lineTo(w, h / 2)
          ..lineTo(0, h)
          ..closePath();
        if (hasGrad) {
          canvas.saveContext();
          canvas.clipPath();
          _paintGradientFill(canvas, 0, 0, w, h, shape);
          canvas.restoreContext();
          canvas
            ..moveTo(0, 0)
            ..lineTo(w, h / 2)
            ..lineTo(0, h)
            ..closePath();
        }
        fillPath();
        break;
      case ShapeType.freeform:
      case ShapeType.merged:
        if (shape.freeformPath.isNotEmpty) {
          if (hasGrad && hasFill) {
            // Clip to the path, then paint the gradient across the box.
            canvas.saveContext();
            _paintSvgPath(canvas, shape.freeformPath, w, h,
                fill: null, stroke: null, strokeWidth: 0);
            canvas.clipPath();
            _paintGradientFill(canvas, 0, 0, w, h, shape);
            canvas.restoreContext();
            if (hasStroke) {
              _paintSvgPath(canvas, shape.freeformPath, w, h,
                  fill: null, stroke: stroke, strokeWidth: sw);
            }
          } else {
            _paintSvgPath(canvas, shape.freeformPath, w, h,
                fill: hasFill ? shape.fillColor : null,
                fillOpacity: fillOpacity,
                stroke: hasStroke ? stroke : null,
                strokeWidth: sw);
          }
        } else {
          if (hasFill) {
            canvas.setFillColor(fillWith(fillOpacity));
            canvas.drawRect(0, 0, w, h);
            canvas.fillPath();
          }
          if (hasStroke) {
            canvas.setColor(strokeColor);
            canvas.setLineWidth(sw);
            canvas.drawRect(0, 0, w, h);
            canvas.strokePath(close: true);
          }
        }
        break;
    }
  }

  /// Paint an SVG path `d` (local box units 0..w / 0..h) onto the canvas,
  /// supporting M/L/H/V and bézier C/S/Q/T commands (absolute + relative).
  void _paintSvgPath(
    PdfGraphics canvas,
    String pathD,
    double boxW,
    double boxH, {
    String? fill,
    double fillOpacity = 1,
    PdfColor? stroke,
    double strokeWidth = 1,
    double offsetX = 0,
    double offsetY = 0,
  }) {
    final matches = _cmdRe.allMatches(pathD).toList();
    double cx = 0, cy = 0;
    double? lastCx, lastCy;
    var started = false;

    void moveTo(double x, double y) {
      cx = x;
      cy = y;
      if (!started) {
        canvas.moveTo(x + offsetX, y + offsetY);
        started = true;
      }
    }

    for (var k = 0; k < matches.length; k++) {
      final cmd = matches[k].group(0)!;
      final startIdx = matches[k].end;
      final endIdx =
          k + 1 < matches.length ? matches[k + 1].start : pathD.length;
      final nums = _numRe
          .allMatches(pathD.substring(startIdx, endIdx))
          .map((m) => double.parse(m.group(0)!))
          .toList();
      final rel = cmd == cmd.toLowerCase();
      switch (cmd.toUpperCase()) {
        case 'M':
          if (nums.length >= 2) {
            final nx = rel ? cx + nums[0] : nums[0];
            final ny = rel ? cy + nums[1] : nums[1];
            moveTo(nx, ny);
          }
          break;
        case 'L':
          for (var n = 0; n + 1 < nums.length; n += 2) {
            final nx = rel ? cx + nums[n] : nums[n];
            final ny = rel ? cy + nums[n + 1] : nums[n + 1];
            canvas.lineTo(nx + offsetX, ny + offsetY);
            cx = nx;
            cy = ny;
          }
          break;
        case 'H':
          for (final v in nums) {
            final nx = rel ? cx + v : v;
            canvas.lineTo(nx + offsetX, cy + offsetY);
            cx = nx;
          }
          break;
        case 'V':
          for (final v in nums) {
            final ny = rel ? cy + v : v;
            canvas.lineTo(cx + offsetX, ny + offsetY);
            cy = ny;
          }
          break;
        case 'C':
          for (var n = 0; n + 5 < nums.length; n += 6) {
            final x1 = rel ? cx + nums[n] : nums[n];
            final y1 = rel ? cy + nums[n + 1] : nums[n + 1];
            final x2 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y2 = rel ? cy + nums[n + 3] : nums[n + 3];
            final x3 = rel ? cx + nums[n + 4] : nums[n + 4];
            final y3 = rel ? cy + nums[n + 5] : nums[n + 5];
            canvas.curveTo(x1 + offsetX, y1 + offsetY, x2 + offsetX,
                y2 + offsetY, x3 + offsetX, y3 + offsetY);
            cx = x3;
            cy = y3;
            lastCx = x2;
            lastCy = y2;
          }
          break;
        case 'S':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x1 = lastCx != null ? cx + (cx - lastCx) : cx;
            final y1 = lastCy != null ? cy + (cy - lastCy) : cy;
            final x2 = rel ? cx + nums[n] : nums[n];
            final y2 = rel ? cy + nums[n + 1] : nums[n + 1];
            final x3 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y3 = rel ? cy + nums[n + 3] : nums[n + 3];
            canvas.curveTo(x1 + offsetX, y1 + offsetY, x2 + offsetX,
                y2 + offsetY, x3 + offsetX, y3 + offsetY);
            cx = x3;
            cy = y3;
            lastCx = x2;
            lastCy = y2;
          }
          break;
        case 'Q':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x1 = rel ? cx + nums[n] : nums[n];
            final y1 = rel ? cy + nums[n + 1] : nums[n + 1];
            final x2 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y2 = rel ? cy + nums[n + 3] : nums[n + 3];
            final c1x = cx + 2 / 3 * (x1 - cx);
            final c1y = cy + 2 / 3 * (y1 - cy);
            final c2x = x2 + 2 / 3 * (x1 - x2);
            final c2y = y2 + 2 / 3 * (y1 - y2);
            canvas.curveTo(c1x + offsetX, c1y + offsetY, c2x + offsetX,
                c2y + offsetY, x2 + offsetX, y2 + offsetY);
            cx = x2;
            cy = y2;
            lastCx = x1;
            lastCy = y1;
          }
          break;
        case 'T':
          for (var n = 0; n + 1 < nums.length; n += 2) {
            final x1 = lastCx != null ? cx + (cx - lastCx) : cx;
            final y1 = lastCy != null ? cy + (cy - lastCy) : cy;
            final x2 = rel ? cx + nums[n] : nums[n];
            final y2 = rel ? cy + nums[n + 1] : nums[n + 1];
            final c1x = cx + 2 / 3 * (x1 - cx);
            final c1y = cy + 2 / 3 * (y1 - cy);
            final c2x = x2 + 2 / 3 * (x1 - x2);
            final c2y = y2 + 2 / 3 * (y1 - y2);
            canvas.curveTo(c1x + offsetX, c1y + offsetY, c2x + offsetX,
                c2y + offsetY, x2 + offsetX, y2 + offsetY);
            cx = x2;
            cy = y2;
            lastCx = x1;
            lastCy = y1;
          }
          break;
        case 'Z':
          canvas.closePath();
          break;
      }
    }

    if (fill != null) {
      canvas.setFillColor(fillOpacity >= 1
          ? PdfColor.fromHex(fill)
          : PdfColor.fromHex(_withAlpha(fill, (fillOpacity * 255).round())));
      canvas.fillPath();
    }
    if (stroke != null) {
      canvas.setColor(stroke);
      canvas.setLineWidth(strokeWidth);
      canvas.strokePath(close: true);
    }
  }

  /// Paint a linear gradient inside [rect] by drawing thin colour bands
  /// interpolated between gradientStart and gradientEnd (pdf has no
  /// native gradient shader, so bands approximate it — 48 steps is smooth
  /// at slide scale). Angle 0 = left→right; positive = clockwise (SVG
  /// convention, matching the HTML/PPTX renderers).
  /// Track 25, P5: flat shadow — a semi-transparent copy of the shape's
  /// geometry shifted by the effect's offset. Simple and cheap in PDF terms.
  void _paintFlattenedShadow(
      PdfGraphics canvas, double w, double h, DrawnShape shape) {
    final eff = shape.effect;
    final dx = eff.shadowOffsetX * w / 100;
    final dy = eff.shadowOffsetY * h / 100;
    final shadowColor = _parseHex(eff.shadowColor) ?? PdfColors.grey;
    canvas.setFillColor(PdfColor.fromHex(_withAlpha(eff.shadowColor,
        (eff.shadowAlpha * 255).round().clamp(0, 255))));
    switch (shape.type) {
      case ShapeType.rect:
      case ShapeType.merged:
        if (shape.type == ShapeType.merged && shape.freeformPath.isNotEmpty) {
          _paintSvgPath(canvas, shape.freeformPath, w, h,
              fill: eff.shadowColor, fillOpacity: eff.shadowAlpha,
              stroke: null, strokeWidth: 0, offsetX: dx, offsetY: dy);
        } else {
          canvas.drawRect(dx, dy, w, h);
          canvas.fillPath();
        }
        break;
      case ShapeType.oval:
        canvas.drawEllipse(dx + w / 2, dy + h / 2, w / 2, h / 2);
        canvas.fillPath();
        break;
      case ShapeType.line:
        canvas.setColor(shadowColor);
        canvas.setLineWidth(shape.strokeWidth);
        canvas.drawLine(dx, dy + h, dx + w, dy);
        break;
      case ShapeType.arrow:
        canvas
          ..moveTo(dx, dy)
          ..lineTo(dx + w, dy + h / 2)
          ..lineTo(dx, dy + h)
          ..closePath();
        canvas.fillPath();
        break;
      case ShapeType.freeform:
        if (shape.freeformPath.isNotEmpty) {
          _paintSvgPath(canvas, shape.freeformPath, w, h,
              fill: eff.shadowColor, fillOpacity: eff.shadowAlpha,
              stroke: null, strokeWidth: 0, offsetX: dx, offsetY: dy);
        } else {
          canvas.drawRect(dx, dy, w, h);
          canvas.fillPath();
        }
        break;
    }
  }

  void _paintGradientFill(
    PdfGraphics canvas,
    double x,
    double y,
    double w,
    double h,
    DrawnShape shape,
  ) {
    final a = _parseHex(shape.gradientStart);
    final b = _parseHex(shape.gradientEnd);
    if (a == null || b == null || w <= 0 || h <= 0) return;
    final angleRad = shape.gradientAngle * 3.14159265 / 180;
    // Unit vector along the gradient direction (angle 0 = +x).
    final gx = math.cos(angleRad);
    final gy = math.sin(angleRad);
    final len = (w * gx.abs() + h * gy.abs()).abs();
    if (len <= 0) return;
    const steps = 48;
    final opacity = 1.0 - shape.fillTransparency;
    for (var i = 0; i < steps; i++) {
      final t0 = i / steps;
      final t1 = (i + 1) / steps;
      // Colour at band centre.
      final t = (t0 + t1) / 2;
      final r = (a.red * 255 * (1 - t) + b.red * 255 * t).round();
      final g = (a.green * 255 * (1 - t) + b.green * 255 * t).round();
      final bl = (a.blue * 255 * (1 - t) + b.blue * 255 * t).round();
      final alpha = (opacity * 255).round();
      final hex = '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${bl.toRadixString(16).padLeft(2, '0')}'
          '${alpha.toRadixString(16).padLeft(2, '0')}';
      canvas.setFillColor(PdfColor.fromHex(hex));
      // Band: the projection interval [t0,t1] along the gradient axis
      // maps to a strip perpendicular to the gradient direction.
      final p0 = t0 * len;
      final p1 = t1 * len;
      if (gx.abs() >= gy.abs()) {
        // Horizontal-ish gradient: vertical strips.
        final x0 = x + p0 * (gx < 0 ? -1 : 1) * (gx.abs() >= 0.001 ? 1 : 0);
        final x1 = x + p1 * (gx < 0 ? -1 : 1) * (gx.abs() >= 0.001 ? 1 : 0);
        final left = math.min(x0, x1);
        final right = math.max(x0, x1);
        canvas.drawRect(left, y, right - left, h);
      } else {
        // Vertical-ish gradient: horizontal strips.
        final y0 = y + p0 * (gy < 0 ? -1 : 1);
        final y1 = y + p1 * (gy < 0 ? -1 : 1);
        final top = math.min(y0, y1);
        final bottom = math.max(y0, y1);
        canvas.drawRect(x, top, w, bottom - top);
      }
      canvas.fillPath();
    }
  }

  /// Replace the alpha of a #RRGGBB hex colour with [alpha] (0..255).
  /// PdfColor.fromHex expects #RRGGBBAA (alpha last).
  String _withAlpha(String hex, int alpha) {
    final clean = hex.replaceFirst('#', '');
    final rgb = clean.length >= 6 ? clean.substring(0, 6) : '000000';
    return '#$rgb${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  PdfColor? _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return null;
    final r = int.tryParse(clean.substring(0, 2), radix: 16);
    final g = int.tryParse(clean.substring(2, 4), radix: 16);
    final b = int.tryParse(clean.substring(4, 6), radix: 16);
    if (r == null || g == null || b == null) return null;
    return PdfColor.fromInt(0xFF000000 | (r << 16) | (g << 8) | b);
  }

  /// Wrap the slide canvas with a header bar and a footer bar (Track 19, P5).
  pw.Widget _wrapWithHF(
    pw.Widget child,
    String hfHeader,
    String hfFooter,
    bool showNum,
    bool showDate,
    String dateFormat,
    int slideIndex,
  ) {
    if (hfHeader.isEmpty && hfFooter.isEmpty && !showNum && !showDate) {
      return child;
    }
    return pw.Column(
      children: [
        if (hfHeader.isNotEmpty || showDate)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (hfHeader.isNotEmpty)
                  pw.Text(hfHeader,
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                if (showDate)
                  pw.Text(_formatDate(dateFormat),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ),
        pw.Expanded(child: child),
        if (hfFooter.isNotEmpty || showNum)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (hfFooter.isNotEmpty)
                  pw.Text(hfFooter,
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                if (showNum)
                  pw.Text('$slideIndex',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ),
      ],
    );
  }

  /// Format a date string according to a simple format (yyyy-MM-dd, MM/dd/yy, etc.)
  String _formatDate(String format) {
    final now = DateTime.now();
    return format
        .replaceAll('yyyy', now.year.toString().padLeft(4, '0'))
        .replaceAll('yy', now.year.toString().substring(2))
        .replaceAll('MM', now.month.toString().padLeft(2, '0'))
        .replaceAll('dd', now.day.toString().padLeft(2, '0'));
  }

  /// Render an equation as a PDF widget (Track 18, P4): parse the MathML
  /// and build a [pw.Widget] tree that mirrors the SVG renderer — fractions
  /// get a horizontal bar, radicals get a radical sign, superscripts are
  /// raised and scaled. Falls back to italic text when the input is not
  /// parseable.
  pw.Widget _buildEquationPdf(String mathml) {
    final inner = mathml
        .trim()
        .replaceFirst(RegExp(r'^<math[^>]*>'), '')
        .replaceFirst(RegExp(r'</math>\s*$'), '')
        .trim();
    try {
      return _pdfLayoutRun(inner) ??
          pw.Text(mathml,
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 14));
    } catch (_) {
      return pw.Text(mathml,
          style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 14));
    }
  }

  pw.Widget? _pdfLayoutRun(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    final tagMatch = RegExp(r'^<([a-zA-Z]+)>(.*)</\1>$', dotAll: true)
        .firstMatch(trimmed);
    if (tagMatch == null) {
      return pw.Text(trimmed,
          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic));
    }
    final tag = tagMatch.group(1);
    final inner = tagMatch.group(2)!;
    switch (tag) {
      case 'mi':
      case 'mn':
      case 'mo':
      case 'ms':
        return pw.Text(inner,
            style: pw.TextStyle(
                fontSize: 14,
                fontStyle:
                    tag == 'mi' ? pw.FontStyle.italic : pw.FontStyle.normal));
      case 'mrow':
        return _pdfConcat(inner);
      case 'mfrac': {
        final parts = _splitTopLevelEq(inner);
        if (parts.length != 2) return pw.Text('?');
        final numW = _pdfLayoutRun(parts[0]);
        final denW = _pdfLayoutRun(parts[1]);
        if (numW == null || denW == null) return pw.Text('?');
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            numW,
            pw.Container(
                height: 1,
                color: PdfColors.black,
                margin: const pw.EdgeInsets.symmetric(vertical: 2)),
            denW,
          ],
        );
      }
      case 'msqrt': {
        final innerW = _pdfLayoutRun(inner);
        if (innerW == null) return null;
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('\u221A', style: const pw.TextStyle(fontSize: 16)),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 1)),
              ),
              child: innerW,
            ),
          ],
        );
      }
      case 'msup': {
        final parts = _splitTopLevelEq(inner);
        if (parts.length != 2) return pw.Text('?');
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _pdfLayoutRun(parts[0]) ?? pw.Text(''),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 1),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  _pdfLayoutRun(parts[1]) ?? pw.Text(''),
                ],
              ),
            ),
          ],
        );
      }
      case 'msub': {
        final parts = _splitTopLevelEq(inner);
        if (parts.length != 2) return pw.Text('?');
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _pdfLayoutRun(parts[0]) ?? pw.Text(''),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 1),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  _pdfLayoutRun(parts[1]) ?? pw.Text(''),
                ],
              ),
            ),
          ],
        );
      }
      default:
        return _pdfLayoutRun(inner);
    }
  }

  pw.Widget? _pdfConcat(String s) {
    final parts = _splitTopLevelEq(s);
    final widgets = <pw.Widget>[];
    for (final part in parts) {
      final w = _pdfLayoutRun(part);
      if (w != null) widgets.add(w);
    }
    if (widgets.isEmpty) return null;
    return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: widgets);
  }

  /// Split a MathML inner string into top-level children (same as the
  /// SVG renderer's _splitTopLevel).
  List<String> _splitTopLevelEq(String s) {
    final parts = <String>[];
    var depth = 0;
    var current = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '<') {
        final closing = i + 1 < s.length && s[i + 1] == '/';
        if (!closing) depth++;
        current.write(c);
        var j = i + 1;
        while (j < s.length && s[j] != '>') {
          current.write(s[j]);
          j++;
        }
        if (j < s.length) {
          current.write('>');
          if (closing) depth--;
          i = j;
          if (depth == 0) {
            parts.add(current.toString().trim());
            current = StringBuffer();
          }
        }
      } else {
        current.write(c);
      }
    }
    if (current.toString().trim().isNotEmpty) {
      parts.add(current.toString().trim());
    }
    return parts;
  }

  pw.RichText _richText(
    List<Map<String, String>> runs,
    double defaultSize,
    PdfColor? defaultColor,
  ) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          for (final run in runs)
            pw.TextSpan(
              text: run['isBreak'] == 'true' ? '\n' : (run['text'] ?? ''),
              style: _runStyle(run, defaultSize, defaultColor),
            ),
        ],
      ),
    );
  }

  List<List<Map<String, String>>> _groupRuns(
    List<Map<String, String>> runs,
    String startMarker,
  ) {
    final groups = <List<Map<String, String>>>[];
    var current = <Map<String, String>>[];
    for (final run in runs) {
      if (run[startMarker] == 'true' && current.isNotEmpty) {
        groups.add(current);
        current = <Map<String, String>>[];
      }
      current.add(run);
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }

  pw.TextStyle _runStyle(
      Map<String, String> run, double defaultSize, PdfColor? defaultColor) {
    double size = defaultSize;
    final sz = run['size'];
    if (sz != null && sz.isNotEmpty) {
      final parsed = int.tryParse(sz);
      if (parsed != null) size = parsed / 100.0;
    }
    PdfColor? color = defaultColor;
    final hex = run['color'];
    if (hex != null && hex.isNotEmpty) {
      color = PdfColor.fromHex(hex);
    }
    return pw.TextStyle(
      fontSize: size,
      fontWeight:
          run['bold'] == 'true' ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle:
          run['italic'] == 'true' ? pw.FontStyle.italic : pw.FontStyle.normal,
      decoration: run['underline'] == 'true'
          ? pw.TextDecoration.underline
          : (run['strike'] == 'true' ? pw.TextDecoration.lineThrough : null),
      color: color,
    );
  }

  String _extractNotes(Map<String, dynamic> slide, String html,
      {HtmlParseCache? parseCache}) {
    final explicit = (slide['notes'] ?? '').toString().trim();
    return explicit.isNotEmpty
        ? explicit
        : PPTGenerator.extractNotes(html, parseCache: parseCache);
  }

  PdfColor? _extractBgColor(Map<String, dynamic> slide) {
    final typed =
        PPTGenerator.cssColorToHex((slide['bgColor'] ?? '').toString());
    final html = (slide['htmlContent'] ?? '').toString();
    final match =
        RegExp(r"""data-bg-color=["']([^"']+)["']""", caseSensitive: false)
            .firstMatch(html);
    final hex = typed ??
        (match == null ? null : PPTGenerator.cssColorToHex(match.group(1)!));
    if (hex == null) return null;
    try {
      return PdfColor.fromHex(hex);
    } catch (_) {
      return null;
    }
  }

  /// Pick black or white text depending on background luminance.
  PdfColor _contrastColor(PdfColor bg) {
    final luminance = 0.299 * bg.red + 0.587 * bg.green + 0.114 * bg.blue;
    return luminance > 0.5 ? PdfColors.black : PdfColors.white;
  }
}

/// Paint one SmartArt diagram (Track 10, P4) — boxes / cycles / pyramids
/// with the theme palette; text is kept short (no canvas fonts).
void _paintSmartArt(PdfGraphics canvas, PdfPoint size, SmartArtGraph graph) {
  final nodes = graph.orderedNodes;
  if (nodes.isEmpty) return;
  final w = size.x;
  final h = size.y;
  final n = math.max(nodes.length, 1);

  void box(int i, double x, double y, double bw, double bh) {
    canvas
      ..setFillColor(PdfColor.fromHex(graph.colorTheme.colorAt(i)))
      ..drawRect(x, y, bw, bh);
  }

  switch (graph.layout.group) {
    case SmartArtGroup.list:
    case SmartArtGroup.relationship:
      final slotH = (h - 20) / n;
      for (var i = 0; i < nodes.length; i++) {
        box(i, 20, 10 + i * slotH, w - 40, math.max(slotH - 12, 18));
      }
    case SmartArtGroup.process:
      final slotW = (w - 30) / n;
      for (var i = 0; i < nodes.length; i++) {
        box(i, 15 + i * slotW, h / 2 - 40, slotW - 14, 80);
      }
    case SmartArtGroup.cycle:
      final cx = w / 2;
      final cy = h / 2;
      final r = math.min(w, h) / 2 - 30;
      for (var i = 0; i < nodes.length; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        box(i, cx + math.cos(a) * r - 32, cy + math.sin(a) * r - 18, 64, 36);
      }
    case SmartArtGroup.hierarchy:
      final top = nodes.where((x) => x.parentId == null).toList();
      if (top.isNotEmpty) {
        box(0, w / 2 - 70, 10, 140, 40);
        final kids = graph.childrenOf(top.first.id);
        for (var i = 0; i < kids.length; i++) {
          box(i + 1, 15 + i * (w - 30) / math.max(kids.length, 1),
              h - 70, (w - 30) / math.max(kids.length, 1) - 10, 55);
        }
      }
    case SmartArtGroup.matrix:
      for (var i = 0; i < nodes.length; i++) {
        box(i, 15 + (i % 2) * ((w - 40) / 2 + 10),
            h / 2 - 30 + (i ~/ 2) * 70, (w - 40) / 2, 60);
      }
    case SmartArtGroup.pyramid:
      final slotH = (h - 20) / n;
      for (var i = 0; i < nodes.length; i++) {
        final frac = (n - i) / n;
        final bw = (w - 40) * frac;
        canvas.setFillColor(PdfColor.fromHex(graph.colorTheme.colorAt(i)));
        canvas
          ..moveTo(w / 2 - bw / 2, 10 + i * slotH)
          ..lineTo(w / 2 + bw / 2, 10 + i * slotH)
          ..lineTo(w / 2 + bw * 0.4, 10 + (i + 1) * slotH)
          ..lineTo(w / 2 - bw * 0.4, 10 + (i + 1) * slotH)
          ..closePath()
          ..fillPath();
      }
    case SmartArtGroup.picture:
      final slotH = (h - 20) / n;
      for (var i = 0; i < nodes.length; i++) {
        box(i, 15, 10 + i * slotH, 60, math.max(slotH - 12, 18));
        box(i, 85, 10 + i * slotH, w - 100, math.max(slotH - 12, 18));
      }
  }
}

/// Mix [hex] toward white (used for translucent-looking area fills).
PdfColor _lighten(String hex) {
  final value = int.parse(hex, radix: 16);
  final r = (value >> 16) & 0xFF, g = (value >> 8) & 0xFF, b = value & 0xFF;
  int mix(int v) => v + ((255 - v) * 2 ~/ 3);
  return PdfColor.fromInt(0xFF000000 | (mix(r) << 16) | (mix(g) << 8) | mix(b));
}

/// Paint one chart onto the PDF canvas (Track 08, P5) — same colour palette
/// and geometry as the SVG/PPTX renderers.
void _paintChart(
  PdfGraphics canvas,
  PdfPoint size,
  ChartData chart,
) {
  final w = size.x;
  final h = size.y;
  const plotX = 40.0;
  const plotY = 14.0;
  final plotW = w - 56;
  final plotH = h - 30;

  switch (chart.type) {
    case ChartType.pie:
    case ChartType.donut:
    case ChartType.sunburst:
      _paintPie(canvas, chart, plotX, plotY, plotW, plotH);
    case ChartType.waterfall:
      _paintWaterfall(canvas, chart, plotX, plotY, plotW, plotH);
    case ChartType.funnel:
      _paintFunnel(canvas, chart, plotX, plotY, plotW, plotH);
    case ChartType.line:
      _paintLine(canvas, chart, plotX, plotY, plotW, plotH, area: false);
    case ChartType.area:
      _paintLine(canvas, chart, plotX, plotY, plotW, plotH, area: true);
    case ChartType.combo:
      _paintCombo(canvas, chart, plotX, plotY, plotW, plotH);
    case ChartType.column:
    case ChartType.bar:
    case ChartType.histogram:
    case ChartType.treemap:
    case ChartType.boxWhisker:
    case ChartType.map:
      _paintColumns(canvas, chart, plotX, plotY, plotW, plotH);
  }
}

void _paintColumns(
  PdfGraphics canvas,
  ChartData chart,
  double plotX,
  double plotY,
  double plotW,
  double plotH,
) {
  final maxV = chart.maxValue == 0 ? 1.0 : chart.maxValue;
  final n = math.max(chart.categories.length, 1);
  final slot = plotW / n;
  final barW = (slot * 0.55).clamp(6.0, 46.0);
  for (var c = 0; c < chart.categories.length; c++) {
    for (var s = 0; s < chart.series.length; s++) {
      final v = chart.valueAt(s, c);
      final x = plotX + slot * c + (slot - barW) / 2;
      final barH = v.abs() / maxV * plotH;
      canvas
        ..setFillColor(PdfColor.fromHex(chart.style.colorAt(s)))
        ..drawRect(x, plotY + plotH - barH, barW, barH);
    }
  }
  canvas
    ..setColor(PdfColors.grey600)
    ..drawLine(plotX, plotY + plotH, plotX + plotW, plotY + plotH);
}

void _paintLine(
  PdfGraphics canvas,
  ChartData chart,
  double plotX,
  double plotY,
  double plotW,
  double plotH, {
  required bool area,
}) {
  final n = math.max(chart.categories.length - 1, 1);
  final step = plotW / n;
  for (var s = 0; s < chart.series.length; s++) {
    final pts = <(double, double)>[
      for (var c = 0; c < chart.categories.length; c++)
        (
          plotX + c * step,
          plotY +
              plotH -
              (chart.maxValue == 0
                  ? 0
                  : chart.valueAt(s, c) / chart.maxValue) *
                  plotH,
        ),
    ];
    if (area && pts.isNotEmpty) {
      canvas.setFillColor(_lighten(chart.style.colorAt(s)));
      canvas.moveTo(pts.first.$1, plotY + plotH);
      for (final p in pts.skip(1)) {
        canvas.lineTo(p.$1, p.$2);
      }
      canvas.lineTo(pts.last.$1, plotY + plotH);
      canvas.closePath();
      canvas.fillPath();
    }
    canvas.setColor(PdfColor.fromHex(chart.style.colorAt(s)));
    for (var i = 1; i < pts.length; i++) {
      canvas.drawLine(pts[i - 1].$1, pts[i - 1].$2, pts[i].$1, pts[i].$2);
    }
  }
}

void _paintCombo(
  PdfGraphics canvas,
  ChartData chart,
  double plotX,
  double plotY,
  double plotW,
  double plotH,
) {
  final maxV = chart.maxValue == 0 ? 1.0 : chart.maxValue;
  final n = math.max(chart.categories.length, 1);
  final slot = plotW / n;
  final barW = (slot * 0.4).clamp(6.0, 40.0);
  final step = plotW / math.max(n - 1, 1);
  for (var c = 0; c < chart.categories.length; c++) {
    final v = chart.valueAt(0, c);
    canvas
      ..setFillColor(PdfColor.fromHex(chart.style.colorAt(0)))
      ..drawRect(
          plotX + slot * c + (slot - barW) / 2,
          plotY + plotH - v / maxV * plotH,
          barW,
          v / maxV * plotH);
  }
  for (var s = 1; s < chart.series.length; s++) {
    canvas.setColor(PdfColor.fromHex(chart.style.colorAt(s)));
    for (var c = 1; c < chart.categories.length; c++) {
      canvas.drawLine(
          plotX + (c - 1) * step,
          plotY + plotH - chart.valueAt(s, c - 1) / maxV * plotH,
          plotX + c * step,
          plotY + plotH - chart.valueAt(s, c) / maxV * plotH);
    }
  }
}

void _paintPie(
  PdfGraphics canvas,
  ChartData chart,
  double plotX,
  double plotY,
  double plotW,
  double plotH,
) {
  final values =
      chart.series.isNotEmpty ? chart.series.first.values : const <double>[];
  final total = values.fold<double>(0, (a, v) => a + v.abs());
  if (total <= 0) return;
  final cx = plotX + plotW / 2;
  final cy = plotY + plotH / 2;
  final r = math.min(plotW, plotH) / 2 - 6;
  var angle = -math.pi / 2;
  for (var c = 0; c < values.length; c++) {
    final sweep = values[c].abs() / total * 2 * math.pi;
    canvas.setFillColor(PdfColor.fromHex(chart.style.colorAt(c)));
    canvas.moveTo(cx, cy);
    const segments = 24;
    for (var i = 0; i <= segments; i++) {
      final a = angle + sweep * i / segments;
      canvas.lineTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
    }
    canvas.closePath();
    canvas.fillPath();
    angle += sweep;
  }
}

void _paintWaterfall(
  PdfGraphics canvas,
  ChartData chart,
  double plotX,
  double plotY,
  double plotW,
  double plotH,
) {
  final values =
      chart.series.isNotEmpty ? chart.series.first.values : const <double>[];
  final n = math.max(values.length, 1);
  final slot = plotW / n;
  final barW = (slot * 0.6).clamp(8.0, 50.0);
  final maxV = values.fold<double>(0, (a, v) => a + v.abs()) == 0
      ? 1.0
      : values.fold<double>(0, (a, v) => a + v.abs());
  final base = plotY + plotH;
  var cumulative = 0.0;
  for (var c = 0; c < values.length; c++) {
    final v = values[c];
    final barH = v.abs() / maxV * plotH;
    final y = base - cumulative / maxV * plotH;
    canvas
      ..setFillColor(PdfColor.fromHex(chart.style.colorAt(c)))
      ..drawRect(plotX + slot * c + (slot - barW) / 2, y - barH, barW, barH);
    cumulative += v;
  }
}

void _paintFunnel(
  PdfGraphics canvas,
  ChartData chart,
  double plotX,
  double plotY,
  double plotW,
  double plotH,
) {
  final values =
      chart.series.isNotEmpty ? chart.series.first.values : const <double>[];
  final maxV = values.fold<double>(0, (a, v) => v.abs() > a ? v.abs() : a);
  if (maxV <= 0) return;
  final slotH = plotH / math.max(values.length, 1);
  var y = plotY;
  for (var c = 0; c < values.length; c++) {
    final frac = values[c].abs() / maxV;
    final w = plotW * (0.95 - (1 - frac) * 0.35);
    final x = plotX + (plotW - w) / 2;
    canvas.setFillColor(PdfColor.fromHex(chart.style.colorAt(c)));
    canvas
      ..moveTo(x, y)
      ..lineTo(x + w, y)
      ..lineTo(x + w * 0.86, y + slotH)
      ..lineTo(x + w * 0.14, y + slotH)
      ..closePath()
      ..fillPath();
    y += slotH;
  }
}
