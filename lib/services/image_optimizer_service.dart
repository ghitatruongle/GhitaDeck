/// N2 — Image Optimizer v2 (beta flag, T04).
///
/// The loader already performs EXIF baking / downscale / PNG→JPEG conversion
/// (Track 03). This module adds the demo-beta controls on top:
///  * [ImageOptimizerConfig.betaEnabled] — the Settings toggle. When off the
///    pipeline runs exactly as before (bit-perfect, no stats bookkeeping);
///  * [ImageOptimizerConfig.quality] — JPEG quality used by the conversion
///    (mapped from ExportQuality once wired); the default stays 80, matching
///    the legacy pipeline;
///  * [ImageOptimizationStats] — per-export savings bookkeeping shown in the
///    export success message ("Tiết kiệm X KB (Y%)") and covered by tests.
library;

class ImageOptimizerConfig {
  ImageOptimizerConfig._();

  /// Settings toggle (SharedPreferences `app_image_optimizer_beta`).
  static bool betaEnabled = false;

  /// JPEG quality for the PNG→JPEG re-encode while beta is on.
  static int quality = 80;
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

  /// "1.234 KB (45%)" style summary, or null when nothing was saved.
  static String? summary() {
    if (processedCount == 0 || savedBytes <= 0) return null;
    final percent = (savedBytes * 100) / originalBytes;
    return '${_fmtBytes(savedBytes)} (${percent.toStringAsFixed(0)}%)';
  }

  static String _fmtBytes(int bytes) =>
      bytes >= 1024 ? '${(bytes / 1024).toStringAsFixed(0)} KB' : '$bytes B';
}
