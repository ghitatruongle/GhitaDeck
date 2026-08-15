import 'dart:async';
import 'dart:io';
import '../models/export_options.dart';
import '../models/ppt_theme_setting.dart';
import '../models/slide.dart';
import 'export_primitives.dart';
import 'html_export_service.dart';
import 'html_image_loader.dart';
import 'pdf_export_service.dart';
import 'ppt_generator.dart';

/// Standardized export pipeline (Track 01).
///
/// One [ExportJob] describes *what* to export (slides + options), and carries
/// the three cross-format primitives shared by PPTX/PDF/HTML:
///
///  * a **progress callback** ([onProgress]) reporting a monotonic 0..1
///    fraction together with the slide currently being processed,
///  * a **cancel token** ([cancelToken]) enabling cooperative cancellation
///    between slide iterations,
///  * a **parse cache** ([parseCache]) so identical slide HTML is tokenized
///    only once per session and the resulting block tree is shared between
///    the PPTX and PDF pipelines.
enum ExportJobFormat { pptx, pdf, html }

/// Options shared by the three export formats.
class ExportJobOptions {
  const ExportJobOptions({
    this.widescreen = true,
    this.aspectRatio,
    this.includeNotes = true,
    this.includeBackgrounds = true,
    this.imageMaxWidth,
    this.effect = SlideEffect.none,
    this.autoAdvance,
    this.fitContent = true,
    this.theme,
    this.pdfPaperSize = PdfPaperSize.matchSlide,
    this.pdfMarginPreset = PdfMarginPreset.standard,
    this.pdfScaleToFit = true,
    this.includeHiddenSlides = false,
  });

  final bool widescreen;
  final ExportAspectRatio? aspectRatio;
  final bool includeNotes;
  final bool includeBackgrounds;
  final int? imageMaxWidth;

  /// PPTX only: deck-wide transition effect.
  final SlideEffect effect;

  /// PPTX only: per-slide auto-advance timing.
  final Duration? autoAdvance;

  /// PPTX only: shrink overflowing text recursively (90%/pass) so content
  /// fits the slide (PowerPoint "Shrink text on overflow" style).
  final bool fitContent;

/// PPTX only: user theme (colors + fonts) written into the theme part;
  /// null keeps the v1.6.3 Office defaults.
  final PptThemeSetting? theme;

  /// PDF only: page size (default = match slide, the v1.6.3 behavior).
  final PdfPaperSize pdfPaperSize;

  /// PDF only: page margins in points.
  final PdfMarginPreset pdfMarginPreset;

  /// PDF only: scale the slide canvas to fit the page minus margins.
  final bool pdfScaleToFit;

  /// PDF only: keep hidden slides in the exported document.
  final bool includeHiddenSlides;
}

/// A single, standardized export of [slides] to [outputPath] in [format].
///
/// Runs on the calling isolate (the UI wraps this in
/// [ExportIsolateService]); the services it drives are pure Dart and safe
/// off the UI isolate, but callers may run it anywhere.
class ExportJob {
  ExportJob({
    required this.slides,
    required this.outputPath,
    required this.format,
    this.options = const ExportJobOptions(),
    this.cancelToken,
    this.onProgress,
    this.parseCache,
  })  : assert(slides.isNotEmpty, 'Cannot export an empty presentation'),
        assert(cancelToken == null || !cancelToken.isCancelled);

  final List<Map<String, dynamic>> slides;
  final String outputPath;
  final ExportJobFormat format;
  final ExportJobOptions options;
  final ExportCancelToken? cancelToken;
  final ExportProgressCallback? onProgress;
  final HtmlParseCache? parseCache;

  double _lastFraction = -1;

  void _report(ExportProgress p) {
    // Guarded monotonic: consumers (progress bars, tests) must never observe
    // a decrease, whatever the underlying service reports.
    if (p.fraction < _lastFraction) return;
    _lastFraction = p.fraction;
    onProgress?.call(p);
  }

  /// Run the export and return the written file path.
  ///
  /// Throws [ExportCancelledException] when cancelled mid-run; the output
  /// file is then left untouched (services write only after completion).
  Future<String> run({ExportTimings? timings}) async {
    final total = slides.length;
    final token = cancelToken;
    token?.throwIfCancelled();
    _report(ExportProgressBudget.preparing(total));

    // Track 03: prefetch remote images into the caches before the sync
    // generators run; failed fetches become warnings, never exceptions.
    HtmlImageLoader.clearWarnings();
    await HtmlImageLoader.prefetchSlides(slides);
    token?.throwIfCancelled();

    void onSlide(ExportProgress p) {
      token?.throwIfCancelled();
      _report(p);
    }

    String path;
    final watch = Stopwatch()..start();
    switch (format) {
      case ExportJobFormat.pptx:
        path = (await PPTGenerator.generatePPT(
          slides,
          outputPath,
          effect: options.effect,
          widescreen: options.widescreen,
          aspectRatio: options.aspectRatio,
          includeNotes: options.includeNotes,
          includeBackgrounds: options.includeBackgrounds,
          imageMaxWidth: options.imageMaxWidth,
          autoAdvance: options.autoAdvance,
          parseCache: parseCache,
          cancelToken: token,
          onProgress: onSlide,
          timings: timings,
          fitContent: options.fitContent,
          theme: options.theme,
        ))
            .path;
      case ExportJobFormat.pdf:
        final svc = PdfExportService();
        path = await svc.exportToPdf(
          slides,
          outputPath,
          widescreen: options.widescreen,
          aspectRatio: options.aspectRatio,
          includeNotes: options.includeNotes,
          includeBackgrounds: options.includeBackgrounds,
          imageMaxWidth: options.imageMaxWidth,
          parseCache: parseCache,
          cancelToken: token,
          onProgress: onSlide,
          paperSize: options.pdfPaperSize,
          marginPreset: options.pdfMarginPreset,
          scaleToFit: options.pdfScaleToFit,
          includeHiddenSlides: options.includeHiddenSlides,
        );
      case ExportJobFormat.html:
        final svc = HtmlExportService();
        path = await svc.exportToHtmlPath(
          slides,
          outputPath,
          aspectRatio: options.aspectRatio ?? ExportAspectRatio.widescreen16x9,
          includeNotes: options.includeNotes,
          includeBackgrounds: options.includeBackgrounds,
          imageMaxWidth: options.imageMaxWidth,
          cancelToken: token,
        );
    }

    token?.throwIfCancelled();
    watch.stop();
    timings
      ?..totalMs = watch.elapsedMicroseconds / 1000
      ..bytes = File(path).lengthSync();
    await HtmlImageLoader.writeWarningsLog(path);
    _report(ExportProgressBudget.done(total));
    return path;
  }

  /// Create a job already wired to the shared session parse cache.
  factory ExportJob.withSharedCache({
    required List<Map<String, dynamic>> slides,
    required String outputPath,
    required ExportJobFormat format,
    ExportJobOptions options = const ExportJobOptions(),
    ExportCancelToken? cancelToken,
    ExportProgressCallback? onProgress,
  }) {
    return ExportJob(
      slides: slides,
      outputPath: outputPath,
      format: format,
      options: options,
      cancelToken: cancelToken,
      onProgress: onProgress,
      parseCache: HtmlParseCache.shared,
    );
  }
}