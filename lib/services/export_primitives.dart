/// Shared primitives of the standardized export pipeline (Track 01).
///
/// Leaf library: [PPTGenerator], the PDF/HTML exporters and [ExportJob] all
/// import these types, so keep this file free of service imports to avoid
/// import cycles.
library;

import 'dart:async';

/// Lifecycle state exposed by export orchestration and UI.
enum ExportLifecycleState { idle, exporting, success, failed, cancelled }

/// Thrown when an export is cancelled through its [ExportCancelToken].
class ExportCancelledException implements Exception {
  const ExportCancelledException();

  @override
  String toString() => 'ExportCancelledException: export was cancelled';
}

/// Cooperative cancellation shared by every export format.
///
/// Host-side state: the worker isolate receives a `cancel` message and sets a
/// worker-local token, which the export services poll with
/// [throwIfCancelled] between slides.
class ExportCancelToken {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  /// Completes when [cancel] is called — used to wake up anyone waiting on a
  /// slow job (e.g. the isolate host).
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completer.complete();
  }

  /// Cooperative check: throws [ExportCancelledException] once cancelled.
  /// Services call this between slides so a cancelled export stops quickly
  /// instead of running to completion.
  void throwIfCancelled() {
    if (_cancelled) throw const ExportCancelledException();
  }
}

/// One progress report during an export.
class ExportProgress {
  const ExportProgress({
    required this.fraction,
    required this.slideIndex,
    required this.slideCount,
    required this.stage,
  });

  /// Monotonic 0..1 fraction of the whole export.
  final double fraction;

  /// 0-based index of the slide currently being processed; -1 while the job
  /// is preparing or finalizing (not slide-bound).
  final int slideIndex;

  /// Total number of slides in the deck.
  final int slideCount;

  /// 'preparing' | 'slides' | 'finalizing' | 'done'.
  final String stage;

  @override
  String toString() =>
      'ExportProgress(${(fraction * 100).toStringAsFixed(1)}%, '
      'slide $slideIndex/$slideCount, $stage)';
}

typedef ExportProgressCallback = void Function(ExportProgress progress);

/// Canonical progress mapping shared by every exporter so PPTX, PDF and HTML
/// report the same scale: 0% preparing → 5–95% across slides → 100%.
abstract final class ExportProgressBudget {
  static double slideFraction(int done, int total) =>
      total <= 0 ? 1.0 : 0.05 + 0.90 * done / total;

  static ExportProgress preparing(int total) => ExportProgress(
      fraction: 0.0, slideIndex: -1, slideCount: total, stage: 'preparing');

  static ExportProgress forSlide(int done, int total) => ExportProgress(
      fraction: slideFraction(done, total),
      slideIndex: done,
      slideCount: total,
      stage: 'slides');

  static ExportProgress finalizing(int total) => ExportProgress(
      fraction: 0.99, slideIndex: -1, slideCount: total, stage: 'finalizing');

  static ExportProgress done(int total) => ExportProgress(
      fraction: 1.0, slideIndex: total, slideCount: total, stage: 'done');
}

/// Per-stage timings recorded by the pipeline (used for benchmarking before
/// vs after optimizations).
class ExportTimings {
  double parseMs = 0; // HTML tokenize + block extraction (all slides)
  double buildMs = 0; // shape/XML building (parse excluded)
  double zipMs = 0; // ZIP encoding
  double totalMs = 0;
  int bytes = 0;

  String toTableRow(String label) {
    String fmt(double v) =>
        v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '| $label | ${fmt(parseMs)} ms | ${fmt(buildMs)} ms | '
        '${fmt(zipMs)} ms | ${fmt(totalMs)} ms | $bytes B |';
  }
}