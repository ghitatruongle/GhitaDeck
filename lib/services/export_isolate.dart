import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../models/export_options.dart';
import '../models/ppt_theme_setting.dart';
import '../models/slide.dart';
import 'export_primitives.dart';
import 'html_export_service.dart';
import 'html_image_loader.dart';
import 'html_parse_codec.dart';
import 'image_codec.dart';
import 'image_optimizer_service.dart';
import 'pdf_export_service.dart';
import 'ppt_generator.dart';
import 'docx_report_service.dart';
import 'zip_codec.dart';

// Background-isolate entry points for the heavy export pipeline.
//
// PPTX/PDF generation (and HTML file export) does HTML parsing, image
// decoding and byte packing that can block the UI on large decks. These
// wrappers run the same services off the UI isolate.
//
// All services involved ([PPTGenerator], [PdfExportService],
// [HtmlExportService], [HtmlImageLoader]) are pure Dart (dart:io + the
// archive/html/image/pdf packages) and are therefore safe to run off the UI
// isolate.
//
// Track 01 additions: each job gets a unique [jobId], reports per-slide
// progress (%) over a dedicated progress port, and can be cancelled
// cooperatively — the host sends a `cancel` message on the worker port and
// the worker stops between slides; the long-lived worker also keeps a shared
// session parse cache across jobs.

typedef _ExportJob = Map<String, dynamic>;

/// Export slides to PPTX on the background worker isolate.
/// Returns the output file path.
///
/// [onProgress] receives a monotonic per-slide fraction (0..1) together with
/// the slide currently being processed; [cancelToken] stops the job
/// cooperatively between slides (throws [ExportCancelledException]).
Future<String> runPptExportInIsolate(
  List<Map<String, dynamic>> slides,
  String outputPath, {
  SlideEffect effect = SlideEffect.none,
  bool widescreen = true,
  ExportAspectRatio? aspectRatio,
  bool includeNotes = true,
  bool includeBackgrounds = true,
  int? imageMaxWidth,
  Duration? autoAdvance,
  bool fitContent = true,
  PptThemeSetting? theme,
  ExportProgressCallback? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final result = await ExportIsolateService.instance._runJob(<String, dynamic>{
    'type': 'ppt',
    'slides': slides,
    'outputPath': outputPath,
    'effect': effect.name,
    'widescreen': widescreen,
    'aspectRatio': aspectRatio?.name,
    'includeNotes': includeNotes,
    'includeBackgrounds': includeBackgrounds,
    'imageMaxWidth': imageMaxWidth,
    'autoAdvanceMs': autoAdvance?.inMilliseconds ?? 0,
    'fitContent': fitContent,
    'theme': theme?.toMap(),
    // T02: engine preference snapshot — providers/prefs don't cross isolates,
    // this bool does; the worker feeds it back into ZipEngineConfig.
    'engineRustPreferred': ZipEngineConfig.preferredRust,
    // T04: N2 image optimizer snapshot (flag + quality from host).
    'optimizeImages': ImageOptimizerConfig.betaEnabled,
    'imageJpegQuality': ImageOptimizerConfig.quality,
  }, onProgress: onProgress, cancelToken: cancelToken);
  if (result['ok'] == true) {
    ImageOptimizationStats.importWorkerSummary(
        result['imageSavings'] as String?, (result['imageCount'] as num?)?.toInt() ?? 0);
    return result['path'] as String;
  }
  throw Exception(result['error'] ?? 'PPT export failed');
}

/// Export slides to DOCX on the background worker isolate (B10 — the report
/// used to build on the UI isolate where cancel was a no-op and the progress
/// bar never reached 100%).
Future<String> runDocxExportInIsolate(
  List<Map<String, dynamic>> slides,
  String outputPath, {
  bool includeNotes = true,
  bool includeSlideList = true,
  ExportProgressCallback? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final result = await ExportIsolateService.instance._runJob(<String, dynamic>{
    'type': 'docx',
    'slides': slides,
    'outputPath': outputPath,
    'includeNotes': includeNotes,
    'includeSlideList': includeSlideList,
  }, onProgress: onProgress, cancelToken: cancelToken);
  if (result['ok'] == true) {
    return result['path'] as String;
  }
  throw Exception(result['error'] ?? 'DOCX export failed');
}

/// Export slides to PDF on the background worker isolate.
/// Returns the output file path.
Future<String> runPdfExportInIsolate(
  List<Map<String, dynamic>> slides,
  String outputPath, {
  bool widescreen = true,
  ExportAspectRatio? aspectRatio,
  bool includeNotes = false,
  bool notesPages = false,
  bool bookmarks = false,
  bool includeBackgrounds = true,
  int? imageMaxWidth,
  PdfPaperSize paperSize = PdfPaperSize.matchSlide,
  PdfMarginPreset marginPreset = PdfMarginPreset.standard,
  bool scaleToFit = true,
  bool includeHiddenSlides = false,
  ExportProgressCallback? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final result = await ExportIsolateService.instance._runJob(<String, dynamic>{
    'type': 'pdf',
    'slides': slides,
    'outputPath': outputPath,
    'effect': 'none',
    'widescreen': widescreen,
    'aspectRatio': aspectRatio?.name,
    'includeNotes': includeNotes,
    'notesPages': notesPages,
    'bookmarks': bookmarks,
    'includeBackgrounds': includeBackgrounds,
    'imageMaxWidth': imageMaxWidth,
    'autoAdvanceMs': 0,
    'paperSize': paperSize.name,
    'marginPreset': marginPreset.name,
    'scaleToFit': scaleToFit,
    'includeHiddenSlides': includeHiddenSlides,
    'optimizeImages': ImageOptimizerConfig.betaEnabled,
    'imageJpegQuality': ImageOptimizerConfig.quality,
  }, onProgress: onProgress, cancelToken: cancelToken);
  if (result['ok'] == true) {
    ImageOptimizationStats.importWorkerSummary(
        result['imageSavings'] as String?, (result['imageCount'] as num?)?.toInt() ?? 0);
    return result['path'] as String;
  }
  throw Exception(result['error'] ?? 'PDF export failed');
}

/// Export slides to a standalone HTML file on the background worker isolate.
/// Returns the output file path.
Future<String> runHtmlExportInIsolate(
  List<Map<String, dynamic>> slides,
  String outputPath, {
  ExportAspectRatio? aspectRatio,
  bool includeNotes = false,
  bool includeBackgrounds = true,
  int? imageMaxWidth,
  String playerLocale = 'en',
  ExportProgressCallback? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final result = await ExportIsolateService.instance._runJob(<String, dynamic>{
    'type': 'html',
    'slides': slides,
    'outputPath': outputPath,
    'effect': 'none',
    'widescreen': true,
    'aspectRatio': aspectRatio?.name,
    'includeNotes': includeNotes,
    'includeBackgrounds': includeBackgrounds,
    'imageMaxWidth': imageMaxWidth,
    'autoAdvanceMs': 0,
    'playerLocale': playerLocale,
    'optimizeImages': ImageOptimizerConfig.betaEnabled,
    'imageJpegQuality': ImageOptimizerConfig.quality,
  }, onProgress: onProgress, cancelToken: cancelToken);
  if (result['ok'] == true) {
    ImageOptimizationStats.importWorkerSummary(
        result['imageSavings'] as String?, (result['imageCount'] as num?)?.toInt() ?? 0);
    return result['path'] as String;
  }
  throw Exception(result['error'] ?? 'HTML export failed');
}

/// A long-lived background isolate reused for every export.
///
/// Spawning one isolate per export wastes time re-loading the AOT snapshot and
/// — for PDF — re-parsing the Windows system fonts ([PdfExportService] caches
/// the theme in its static state, which only pays off when the isolate lives
/// across calls). Keeping one worker also means the expensive services run on
/// a dedicated isolate while the UI stays responsive.
class ExportIsolateService {
  ExportIsolateService._();

  /// Timeout for the worker reply — a dead/hung worker must not hold the
  /// export forever. Overridable in tests (B7) to make the deadline cheap.
  static Duration replyTimeout = const Duration(minutes: 2);

  static final ExportIsolateService instance = ExportIsolateService._();

  Isolate? _isolate;
  SendPort? _workerPort;
  Future<void> _queue = Future<void>.value();
  int _nextJobId = 0;

  /// Serializes requests so concurrent exports can't interleave replies on the
  /// single shared worker port.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<SendPort> _ensureWorker() async {
    final cached = _workerPort;
    if (cached != null) return cached;

    final greeting = ReceivePort();
    try {
      final isolate = await Isolate.spawn(
        _isolateMain,
        greeting.sendPort,
        debugName: 'ghita-export',
      );
      _isolate = isolate;
      // Wait for the worker to hand us its request port.
      final workerPort =
          await greeting.first.timeout(const Duration(seconds: 15));
      _workerPort = workerPort as SendPort;
      return _workerPort!;
    } catch (_) {
      // Failed to start or handshake — reset so the caller can retry.
      _disposeWorker();
      rethrow;
    } finally {
      greeting.close();
    }
  }

  void _disposeWorker() {
    _workerPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  /// Run one export job, relaying worker progress to [onProgress] and
  /// honouring [cancelToken] (see the class docs for the protocol).
  Future<Map<String, dynamic>> _runJob(
    _ExportJob job, {
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) {
    return _serialized(() async {
      if (cancelToken?.isCancelled ?? false) {
        throw const ExportCancelledException();
      }
      final workerPort = await _ensureWorker();
      final jobId = _nextJobId++;
      final reply = ReceivePort();
      final progressPort = ReceivePort();
      final outputPath = (job['outputPath'] as String?) ?? '';

      // Ask the worker to stop the moment the host token is cancelled. The
      // worker cannot poll its message port while synchronously building, so
      // cancellation terminates the long-lived worker; a fresh one is
      // spawned for the next export. (Per-slide checks inside the worker
      // cover the cooperative case where cancel arrives before work starts.)
      final cancelWatch = cancelToken?.whenCancelled;
      if (cancelWatch != null) {
        cancelWatch.then((_) {
          try {
            _workerPort?.send(<String, dynamic>{
              'cmd': 'cancel',
              'jobId': jobId,
            });
          } catch (_) {
            // Worker gone — nothing to cancel.
          }
        });
      }

      StreamSubscription<dynamic>? progressSub;
      var lastSlideCount = 0;
      try {
        workerPort.send(<String, dynamic>{
          ...job,
          'jobId': jobId,
          'replyPort': reply.sendPort,
          'progressPort': onProgress != null ? progressPort.sendPort : null,
        });

        // Immediate preparing event from the host: the worker awaits the
        // engine-readiness decision before its first per-slide report, so the
        // UI gets 0% instantly (T08.7 gate) instead of after that wait.
        if (onProgress != null) {
          final total = (job['slides'] as List?)?.length ?? 0;
          onProgress(ExportProgressBudget.preparing(total));
        }

        progressSub = progressPort.listen((dynamic msg) {
          if (onProgress == null) return;
          final m = Map<String, dynamic>.from(msg as Map);
          if (m['type'] != 'progress') return;
          lastSlideCount = (m['count'] as num?)?.toInt() ?? lastSlideCount;
          onProgress(ExportProgress(
            fraction: (m['fraction'] as num).toDouble(),
            slideIndex: (m['slide'] as num?)?.toInt() ?? -1,
            slideCount: lastSlideCount,
            stage: (m['stage'] as String?) ?? 'slides',
          ));
        });

        Map<String, dynamic> result;
        if (cancelWatch == null) {
          final message =
              await reply.first.timeout(ExportIsolateService.replyTimeout);
          result = Map<String, dynamic>.from(message as Map);
        } else {
          // Whoever resolves first decides: an early cancellation wins over
          // the (possibly slow) export reply.
          final cancelled = cancelWatch.then((_) => true);
          final answered = reply.first
              .timeout(ExportIsolateService.replyTimeout)
              .then((m) => <Object?>[false, m]);
          final winner = await Future.any<Object?>([answered, cancelled]);
          if (winner == true) {
            // Cancellation lands while the worker is (still) running:
            // terminate it immediately and remove the job's scratch file.
            // The real output path is only ever touched by the final atomic
            // rename, so a pre-existing file is never corrupted (B8).
            _disposeWorker();
            await _discardScratch(outputPath);
            throw const ExportCancelledException();
          }
          result =
              Map<String, dynamic>.from((winner as List<Object?>)[1] as Map);
        }

        if (result['cancelled'] == true) {
          await _discardScratch(outputPath);
          throw const ExportCancelledException();
        }
        // The worker reports per-slide progress only; synthesize the final
        // 100% 'done' report for callers (ExportJob does the same on its own).
        if (onProgress != null) {
          onProgress(ExportProgressBudget.done(lastSlideCount));
        }
        return result;
      } on TimeoutException {
        // The worker likely died mid-job — drop it and clear the scratch
        // file so no half-written output survives (B7); the previous file at
        // the target path is still untouched.
        _disposeWorker();
        await _discardScratch(outputPath);
        rethrow;
      } finally {
        await progressSub?.cancel();
        reply.close();
        progressPort.close();
      }
    });
  }

  /// Deletes the worker's scratch (`.part`) file for [outputPath], if any.
  /// Never touches the target path itself.
  static Future<void> _discardScratch(String outputPath) async {
    if (outputPath.isEmpty) return;
    try {
      final f = File('$outputPath.part');
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}

/// Worker-isolate state shared across every export job (Track 01).
///
/// The parse cache lives on the session: the same content is tokenized once,
/// no matter how many slides/decks reference it. The HTML deck cache is
/// static inside [HtmlExportService] and survives across jobs the same way.
final HtmlParseCache _sessionParseCache = HtmlParseCache();

/// Worker isolate main loop: answers one export request per message and stays
/// alive until the app shuts down (or the isolate is killed).
///
/// Top-level + entry-point annotation so release (AOT) builds keep it.
@pragma('vm:entry-point')
Future<void> _isolateMain(SendPort initialPort) async {
  final port = ReceivePort();
  // Tell the host where to send jobs.
  initialPort.send(port.sendPort);

  int? currentJobId;
  ExportCancelToken? activeToken;

  await for (final message in port) {
    final job = Map<String, dynamic>.from(message as Map);
    // Cancel control message for the currently running job.
    if (job['cmd'] == 'cancel') {
      final id = job['jobId'] as int?;
      if (id != null && id == currentJobId) activeToken?.cancel();
      continue;
    }
    final replyPort = job['replyPort'] as SendPort?;
    if (replyPort == null) continue;

    currentJobId = job['jobId'] as int?;
    activeToken = ExportCancelToken();
    final progressPort = job['progressPort'] as SendPort?;
    double lastFraction = -1;

    void onProgress(ExportProgress p) {
      if (progressPort == null) return;
      // Monotonic guard: never send a decreasing fraction downstream.
      if (p.fraction < lastFraction) return;
      lastFraction = p.fraction;
      progressPort.send(<String, dynamic>{
        'type': 'progress',
        'fraction': p.fraction,
        'slide': p.slideIndex,
        'count': p.slideCount,
        'stage': p.stage,
      });
    }

    try {
      final path = await _doExport(
        job,
        cancelToken: activeToken,
        onProgress: onProgress,
      );
      replyPort.send(<String, dynamic>{
        'ok': true,
        'path': path,
        // N2: worker-side savings, invisible to the host isolate.
        'imageSavings': ImageOptimizationStats.summary(),
        'imageCount': ImageOptimizationStats.processedCount,
      });
    } on ExportCancelledException {
      replyPort.send(<String, dynamic>{
        'ok': false,
        'error': 'Export cancelled',
        'cancelled': true,
      });
    } catch (e) {
      replyPort.send(<String, dynamic>{'ok': false, 'error': e.toString()});
    } finally {
      currentJobId = null;
      activeToken = null;
    }
  }
}

Future<String> _doExport(
  _ExportJob job, {
  ExportCancelToken? cancelToken,
  ExportProgressCallback? onProgress,
}) async {
  final type = job['type'] as String;
  final slides = (job['slides'] as List).cast<Map<String, dynamic>>();
  final outputPath = job['outputPath'] as String;
  final widescreen = job['widescreen'] as bool? ?? true;
  final aspectRatioName = job['aspectRatio'] as String?;
  final aspectRatio = aspectRatioName == null
      ? null
      : ExportAspectRatio.values.byName(aspectRatioName);
  final includeNotes = job['includeNotes'] as bool? ?? false;
  final includeBackgrounds = job['includeBackgrounds'] as bool? ?? true;
  final imageMaxWidth = job['imageMaxWidth'] as int?;
  final effect = SlideEffect.values.byName(job['effect'] as String? ?? 'none');
  final autoAdvanceMs = job['autoAdvanceMs'] as int? ?? 0;
  final fitContent = job['fitContent'] as bool? ?? true;
  final theme = job['theme'] == null
      ? null
      : PptThemeSetting.fromMap(
          Map<String, dynamic>.from(job['theme'] as Map));

    // T02: engine preference comes from the host isolate via the job message.
    ZipEngineConfig.setPreferredRust(
        job['engineRustPreferred'] as bool? ?? true);
    // T06/T13: images/parse run on the same engine choice. AWAIT the ready
    // decision instead of racing it (B6b/B20): if the DLL loads halfway
    // through the job the whole job would silently mix Rust and Dart
    // backends — one await makes the choice uniform for every slide.
    ImageEngineConfig.setPreferredRust(
        job['engineRustPreferred'] as bool? ?? true);
    await ImageEngineConfig.ensureRustReadyOnce();
    HtmlParseEngineConfig.setPreferredRust(
        job['engineRustPreferred'] as bool? ?? true);
    await HtmlParseEngineConfig.ensureRustReadyOnce();
    // T04: N2 beta flag (image optimizer) — same cross-isolate snapshot.
    ImageOptimizerConfig.betaEnabled = job['optimizeImages'] as bool? ?? false;
    // T07 P2: JPEG re-encode quality mapped from the host's ExportQuality.
    ImageOptimizerConfig.quality =
        job['imageJpegQuality'] as int? ?? ImageOptimizerConfig.quality;

  // Track 03: prefetch remote images into the session caches before the sync
  // generators run; failed fetches become warnings, never exceptions.
  HtmlImageLoader.clearWarnings();
  await HtmlImageLoader.prefetchSlides(slides);
  cancelToken?.throwIfCancelled();

  // B7/B8: the generators write to a `.part` scratch; only the final atomic
  // rename touches the real output path. A timeout/cancel/failure therefore
  // never leaves a partial file and never corrupts a pre-existing one.
  final finalPath = outputPath;
  final partPath = '$outputPath.part';
  File(partPath).parent.createSync(recursive: true);
  try {
    final _ = switch (type) {
      'ppt' => (await PPTGenerator.generatePPT(
                slides,
                partPath,
                effect: effect,
                widescreen: widescreen,
                aspectRatio: aspectRatio,
                includeNotes: includeNotes,
                includeBackgrounds: includeBackgrounds,
                imageMaxWidth: imageMaxWidth,
                autoAdvance: autoAdvanceMs > 0
                    ? Duration(milliseconds: autoAdvanceMs)
                    : null,
                parseCache: _sessionParseCache,
                cancelToken: cancelToken,
                onProgress: onProgress,
                fitContent: fitContent,
                theme: theme,
                useEngineZip: true,
              ))
          .path,
      'pdf' => await PdfExportService()
          .exportToPdf(
            slides,
            partPath,
            widescreen: widescreen,
            aspectRatio: aspectRatio,
            includeNotes: includeNotes,
            includeBackgrounds: includeBackgrounds,
            imageMaxWidth: imageMaxWidth,
            parseCache: _sessionParseCache,
            cancelToken: cancelToken,
            onProgress: onProgress,
            paperSize: PdfPaperSize.values.byName(
                job['paperSize'] as String? ?? 'matchSlide'),
            marginPreset: PdfMarginPreset.values.byName(
                job['marginPreset'] as String? ?? 'standard'),
            scaleToFit: job['scaleToFit'] as bool? ?? true,
            includeHiddenSlides: job['includeHiddenSlides'] as bool? ?? false,
            notesPages: job['notesPages'] as bool? ?? false,
            bookmarks: job['bookmarks'] as bool? ?? false,
          ),
      'html' => await HtmlExportService().exportToHtmlPath(
            slides,
            partPath,
            aspectRatio: aspectRatio ?? ExportAspectRatio.widescreen16x9,
            includeNotes: includeNotes,
            includeBackgrounds: includeBackgrounds,
            imageMaxWidth: imageMaxWidth,
            playerLocale: job['playerLocale'] as String? ?? 'en',
            cancelToken: cancelToken,
            onProgress: onProgress,
          ),
      // B10: DOCX must never build on the UI isolate — same worker,
      // same cooperative cancel/per-slide progress as PPTX/PDF/HTML.
      'docx' => await DocxReportService.exportReport(
            slides,
            partPath,
            includeNotes: includeNotes,
            includeSlideList: job['includeSlideList'] as bool? ?? true,
            cancelToken: cancelToken,
            onProgress: onProgress,
          ),
      _ => throw Exception('Unknown export type: $type'),
    };
    // Dropped/failed images land in <output>.warnings.log (Track 03, P7).
    // The warnings log keeps the REAL output name (it is written next to the
    // final file, not the scratch).
    await HtmlImageLoader.writeWarningsLog(finalPath);

    // Promote the scratch: replace the target only when the job fully
    // succeeded (a pre-existing file survives every failure/cancel).
    try {
      final target = File(finalPath);
      if (target.existsSync()) await target.delete();
      await File(partPath).rename(finalPath);
    } catch (e) {
      try {
        final f = File(partPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      rethrow;
    }
    return finalPath;
  } catch (_) {
    // Any generation failure (including the worker's own cancel): the
    // scratch must not survive — the host clears it again as a safety net.
    try {
      final f = File(partPath);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
    rethrow;
  } finally {
    HtmlImageLoader.clearWarnings();
  }
}