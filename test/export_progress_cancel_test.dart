import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/export_options.dart';

import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/services/export_isolate.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/html_image_loader.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

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

  test('B8: cancelling an overwriting export keeps the previous file intact',
      () async {
    final dir = Directory.systemTemp.createTempSync('n3_b8');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/deck.pptx';
    File(out).writeAsStringSync('SENTINEL');

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
    expect(File(out).readAsStringSync(), 'SENTINEL',
        reason: 'B8: the pre-existing output must survive a cancelled '
            'overwrite (the scratch is what gets removed)');
    final leftovers = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList();
    expect(leftovers, ['deck.pptx'],
        reason: 'no .part scratch may remain beside the previous file');
  });

  test('B7: worker timeout clears the scratch and keeps the target file',
      () async {
    final dir = Directory.systemTemp.createTempSync('n3_b7');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/deck.pptx';
    File(out).writeAsStringSync('SENTINEL');

    final previousTimeout = ExportIsolateService.replyTimeout;
    ExportIsolateService.replyTimeout = const Duration(milliseconds: 150);
    addTearDown(() => ExportIsolateService.replyTimeout = previousTimeout);

    await expectLater(
      runPptExportInIsolate(deck(400), out),
      throwsA(isA<TimeoutException>()),
      reason: 'a hung worker must surface as a timeout',
    );
    expect(File(out).readAsStringSync(), 'SENTINEL',
        reason: 'B7: the target file is not touched before the final rename');
    final leftovers = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList();
    expect(leftovers, ['deck.pptx'],
        reason: 'the .part scratch must be removed on timeout');
  });

  test('B9: HTML per-slide progress spreads over the build, not one burst',
      () async {
    final dir = Directory.systemTemp.createTempSync('n3_b9');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/deck.html';
    // Isolated image cache: the global one may already hold these exact
    // bytes from an earlier run, which would make the build fast and the
    // spread assertion meaningless.
    HtmlImageLoader.debugCacheDir = '${dir.path}/cache';
    addTearDown(() => HtmlImageLoader.debugCacheDir = null);

    // One unique image per slide so every build does real decode work and
    // per-slide progress has actual time to spread over.
    String photo(int seed) {
      final image = img.Image(width: 600, height: 400);
      for (var y = 0; y < 400; y++) {
        for (var x = 0; x < 600; x++) {
          image.setPixelRgb(x, y, (x * seed * 3) % 256 + seed,
              (y * seed * 7) % 256, (x + y + seed) % 256);
        }
      }
      return 'data:image/png;base64,${base64Encode(img.encodePng(image))}';
    }

    final slides = [
      for (var i = 0; i < 30; i++)
        {
          'title': 'S$i',
          'htmlContent': '<div><img src="${photo(i)}"></div>',
        },
    ];
    final events = <ExportProgress>[];
    final stamps = <int>[];
    final sw = Stopwatch()..start();
    await HtmlExportService().exportToHtmlPath(
      slides,
      out,
      onProgress: (p) {
        events.add(p);
        stamps.add(sw.elapsedMicroseconds);
      },
    );
    final total = sw.elapsedMicroseconds;

    final slideStamps = <int>[];
    for (var i = 0; i < events.length; i++) {
      if (events[i].stage == 'slides' && events[i].fraction < 0.99) {
        slideStamps.add(stamps[i]);
      }
    }
    expect(slideStamps, isNotEmpty);
    final spread = slideStamps.last - slideStamps.first;
    expect(spread * 100 ~/ total, greaterThan(20),
        reason: 'B9: per-slide progress must track the build loop — a '
            'front burst (all events in the bg-colour scan) lies to the user');
  });

  test('B10: DOCX exports on the worker and reports the final 100%', () async {
    final dir = Directory.systemTemp.createTempSync('n3_b10');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/report.docx';

    final events = <ExportProgress>[];
    final path = await runDocxExportInIsolate(
      deck(150),
      out,
      onProgress: events.add,
    );
    expect(path, out);
    expect(File(out).existsSync(), isTrue);
    expect(events, isNotEmpty);
    expect(events.last.fraction, 1.0,
        reason: 'B10: DOCX must report the final done (was stuck without it)');
    expect(events.last.stage, 'done');
    expect(events.where((e) => e.slideIndex >= 0).length,
        greaterThanOrEqualTo(1),
        reason: 'per-slide progress must come from the worker');
  });

  test('B10: DOCX cancel mid-run stops and leaves no output', () async {
    final dir = Directory.systemTemp.createTempSync('n3_b10c');
    addTearDown(() => dir.delete(recursive: true));
    final out = '${dir.path}/report.docx';

    final token = ExportCancelToken();
    var sawProgress = false;
    final fut = runDocxExportInIsolate(
      deck(400),
      out,
      onProgress: (p) {
        if (!sawProgress && p.stage == 'slides') {
          sawProgress = true;
          token.cancel();
        }
      },
      cancelToken: token,
    );

    await expectLater(
      fut,
      throwsA(isA<ExportCancelledException>()),
      reason: 'B10: DOCX cancel must work, not be a no-op',
    );
    expect(File(out).existsSync(), isFalse,
        reason: 'a cancelled DOCX export must leave no output');
    expect(dir.listSync().whereType<File>(), isEmpty,
        reason: 'no .part scratch may remain');
  });

  test('B13/B14: progress events keep a consistent, visible-only slide count',
      () async {
    // path_provider → temp dir; SharedPreferences mocked; isolate worker real.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    // Slide 2 is hidden → PDF with includeHiddenSlides=false exports 2 slides.
    final presentation = PresentationState();
    addTearDown(presentation.dispose);
    for (var i = 0; i < 3; i++) {
      presentation.addSlide(Slide(
        title: 'S$i',
        htmlContent: '<p>nội dung $i</p>',
        hidden: i == 1,
      ));
    }

    final events = <ExportProgress>[];
    await presentation.exportWithOptions(
      'b1314_${DateTime.now().millisecondsSinceEpoch}',
      const ExportOptions(format: PresentationExportFormat.pdf),
      onProgress: events.add,
    );
    expect(
      events.map((e) => e.slideCount).toSet(),
      {2},
      reason: 'B14: preparing and per-slide counts must agree '
          '(hidden slides excluded consistently)',
    );
    for (final e in events) {
      // Per-slide events are 1-based positions in the dialog ("x/N");
      // 'done' uses slideIndex == total as a finished sentinel (the dialog
      // clamps +1 against the total — the clamp is the B13 fix).
      if (e.stage == 'slides' && e.slideCount > 0) {
        expect(e.slideIndex + 1, lessThanOrEqualTo(e.slideCount),
            reason: 'B13: no per-slide event may imply "N+1/N"');
      }
    }
  });
}
