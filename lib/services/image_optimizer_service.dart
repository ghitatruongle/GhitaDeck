/// N2 — Image Optimizer v2 (T04 beta flag → T07 regular option).
///
/// The loader already performs EXIF baking / downscale / PNG→JPEG conversion.
/// This module adds the optimizer controls on top:
///  * [ImageOptimizerConfig.enabled] — the Settings toggle. When off the
///    pipeline runs exactly as before (bit-perfect, no stats bookkeeping);
///  * [ImageOptimizerConfig.quality] — JPEG quality used by the conversion,
///    mapped from the export's [ExportQuality] choice (150/300/600 px);
///  * [ImageOptimizationStats] — per-export savings bookkeeping shown in the
///    export success message ("4.462 KB → 2.053 KB (54%)") and covered by
///    tests.
library;

import '../models/export_options.dart';

class ImageOptimizerConfig {
  ImageOptimizerConfig._();

  /// Settings toggle (SharedPreferences `app_image_optimizer_beta` — legacy
  /// key kept so existing prefs carry over; T07 removed the "beta" framing).
  static bool betaEnabled = false;

  /// JPEG quality for the PNG→JPEG re-encode while the optimizer is on.
  static int quality = 80;

  /// T07 P2: map the export quality (bitmap ceiling 150/300/600 px) to the
  /// JPEG re-encode quality — lower ceiling → smaller, lower-fidelity output.
  static int qualityForExport(ExportQuality exportQuality) {
    switch (exportQuality) {
      case ExportQuality.low:
        return 60;
      case ExportQuality.medium:
        return 80;
      case ExportQuality.high:
        return 95;
    }
  }
}

/// Per-export savings bookkeeping. Reset on every export job (same hook that
/// clears [HtmlImageLoader.warnings]); read by the export dialog after a
/// successful export to enrich the summary, then reset again.
class ImageOptimizationStats {
  ImageOptimizationStats._();

  static int originalBytes = 0;
  static int savedBytes = 0;
  static int processedCount = 0;

  // Worker-isolate results are invisible to the host; the worker ships its
  // summary back inside the export reply and the host reinstates it here.
  static String? _workerSummary;
  static int _workerCount = 0;

  static void reset() {
    originalBytes = 0;
    savedBytes = 0;
    processedCount = 0;
    _workerSummary = null;
    _workerCount = 0;
  }

  static void record(int before, int after) {
    if (after >= before) return;
    originalBytes += before;
    savedBytes += before - after;
    processedCount++;
  }

  /// Called on the host isolate when an export job replies with its savings.
  static void importWorkerSummary(String? summary, int count) {
    _workerSummary = summary;
    _workerCount = count;
  }

  /// Savings the export dialog should show: worker summary when available
  /// (isolate exports), otherwise the host-side tally.
  static bool get hasData =>
      _workerSummary != null || (processedCount > 0 && savedBytes > 0);

  static String? displaySummary() {
    if (_workerSummary != null) return _workerSummary;
    final local = summary();
    if (local == null || processedCount == 0) return null;
    return local;
  }

  static int get displayCount => _workerCount > 0 ? _workerCount : processedCount;

  /// "4.462 KB → 2.053 KB (54%)" style summary, or null when nothing saved.
  static String? summary() {
    if (processedCount == 0 || savedBytes <= 0) return null;
    final percent = (savedBytes * 100) / originalBytes;
    final after = originalBytes - savedBytes;
    return '${_fmtBytes(originalBytes)} → ${_fmtBytes(after)} '
        '(${percent.toStringAsFixed(0)}%)';
  }

  static String _fmtBytes(int bytes) =>
      bytes >= 1024 ? '${(bytes / 1024).toStringAsFixed(0)} KB' : '$bytes B';
}
