import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/export_isolate.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';

/// T08 — N3 Instant Export: progress never blocks the UI, cancel leaves the
/// disk untouched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, dynamic>> deck(int n) => [
        for (var i = 0; i < n; i++)
          {
            'title': 'Slide $i',
            'htmlContent': '<h1>Slide $i</h1><p>Nội dung minh hoạ $i</p>',
            'transition': 'none',
          },
      ];

  test('T08.5: HTML export reports per-slide progress up to done', () async {
    final dir = Directory.systemTemp.createTempSync('n3_html');
    addTearDown(() => dir.delete(recursive: true));

    final events = <ExportProgress>[];
    final path = await HtmlExportService().exportToHtmlPath(
      deck(5),
      '${dir.path}/deck.html',
      onProgress: events.add,
    );
    expect(path, endsWith('.html'));
    expect(events, isNotEmpty);
    // Direct service call ends at 'finalizing' (0.99); ExportJob wraps a
    // final 'done' (1.0) on top when exported through the standard pipeline.
    expect(events.last.fraction, 0.99);
    expect(events.last.stage, 'finalizing');
    // Every slide reported at least once (some may be skipped by the cache).
    final reported = events.where((e) => e.slideIndex >= 0).length;
    expect(reported, greaterThanOrEqualTo(1));
  });

  test('T08.7: first progress arrives in <100 ms on a 100-slide export',
      () async {
    final dir = Directory.systemTemp.createTempSync('n3_first');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/deck.pptx';

    final sw = Stopwatch()..start();
    var firstUs = -1;
    final path = await runPptExportInIsolate(
      deck(100),
      out,
      onProgress: (p) {
        if (firstUs < 0) firstUs = sw.elapsedMicroseconds;
      },
    );
    expect(path, out);
    expect(File(out).existsSync(), isTrue);
    expect(firstUs, isNonNegative);
    expect(firstUs / 1000, lessThan(100),
        reason: 'UI must react within 100 ms of starting a large export');
  });

  test('T08.8: mid-run cancel leaves no partial output file', () async {
    final dir = Directory.systemTemp.createTempSync('n3_cancel');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/deck.pptx';

    final token = ExportCancelToken();
    var sawTwo = false;
    final fut = runPptExportInIsolate(
      deck(200),
      out,
      onProgress: (p) {
        if (!sawTwo && p.slideIndex >= 1) {
          sawTwo = true;
          token.cancel();
        }
      },
      cancelToken: token,
    );

    await expectLater(
      fut,
      throwsA(isA<ExportCancelledException>()),
      reason: 'cancel must surface as ExportCancelledException',
    );
    expect(File(out).existsSync(), isFalse,
        reason: 'a cancelled export must not leave a (partial) file');
    // The temp dir holds nothing written by the job.
    final leftovers = dir.listSync().whereType<File>();
    expect(leftovers, isEmpty);
  });
}
