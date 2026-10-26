import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/export_isolate.dart';
import 'package:ghita_deck/services/html_image_loader.dart';
import 'package:ghita_deck/services/image_codec.dart';
import 'package:image/image.dart' as img;

/// T19 — RAM profiling of the export pipeline (deterministic, no DevTools).
///
/// Measures the resident set of THIS test process before/after exports so the
/// cache behaviour introduced in T20 can be compared against a baseline. The
/// in-app RSS of the shipped Release build is measured separately by
/// `tool/measure_ram.ps1` (that is what the <150 MB idle gate refers to).
///
/// Run standalone and capture the table:
///   flutter test tool/ram_profile_test.dart
///   (set GHITA_RAM_LABEL to tag the rows, e.g. "Before T20" / "After T20")
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const label = String.fromEnvironment('GHITA_RAM_LABEL',
      defaultValue: 'baseline');

  /// Resident set of the current process, in MB (Windows: WorkingSet).
  double rssMb() {
    final result = Process.runSync('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-Process -Id \$PID).WorkingSet64',
    ]);
    final value = int.tryParse((result.stdout as String).trim());
    return value == null ? -1 : value / (1024 * 1024);
  }

  Uint8List photoPng(int seed, {int w = 800, int h = 600}) {
    final image = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        image.setPixelRgb(x, y, (x * seed) % 256, (y * seed * 3) % 256,
            (x + y + seed * 7) % 256);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  List<Map<String, dynamic>> photoDeck(int slides, int uniquePhotos) {
    final uris = [
      for (var i = 0; i < uniquePhotos; i++)
        'data:image/png;base64,${base64Encode(photoPng(i + 1))}',
    ];
    return [
      for (var i = 0; i < slides; i++)
        {
          'title': 'RAMS $i',
          'htmlContent':
              '<h1>Slide $i</h1><p>nội dung ${i * 7}</p>'
              '<div><img src="${uris[i % uniquePhotos]}"></div>',
          'transition': 'none',
        },
    ];
  }

  setUp(() {
    HtmlImageLoader.clearCaches();
    HtmlImageLoader.debugCacheDir =
        Directory.systemTemp.createTempSync('t19_cache').path;
    ImageEngineConfig.setPreferredRust(false);
  });

  tearDown(() {
    HtmlImageLoader.clearCaches();
    HtmlImageLoader.debugCacheDir = null;
  });

  test('T19.2: RSS across a 100-slide / 40-photo export (engine: Dart)',
      () async {
    final tmp = Directory.systemTemp.createTempSync('t19_ram');
    addTearDown(() => tmp.delete(recursive: true));
    final out = '${tmp.path}/ram.pptx';

    final before = rssMb();
    await runPptExportInIsolate(photoDeck(100, 40), out);
    final afterFirst = rssMb();

    // Second export: everything is cached now — the delta shows what the
    // caches cost vs what a warm run re-uses.
    await runPptExportInIsolate(photoDeck(100, 40), '${tmp.path}/ram2.pptx');
    final afterSecond = rssMb();

    final rows = [
      '| Run | RSS before | RSS after | Delta |',
      '|---|---|---|---|',
      '| 100 slide / 40 photo (cold) | ${before.toStringAsFixed(1)} MB | '
          '${afterFirst.toStringAsFixed(1)} MB | '
          '${(afterFirst - before).toStringAsFixed(1)} MB |',
      '| 100 slide / 40 photo (warm) | ${afterFirst.toStringAsFixed(1)} MB | '
          '${afterSecond.toStringAsFixed(1)} MB | '
          '${(afterSecond - afterFirst).toStringAsFixed(1)} MB |',
    ];

    File('tool/ram_results_beta3.md').writeAsStringSync(
      '\n\n## Export RSS ($label - ${DateTime.now().toIso8601String()})\n\n'
      '${rows.join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );

    // The export must complete (sanity) — the numbers above are the artifact.
    expect(File(out).existsSync(), isTrue);
    expect(before, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('T19.9: three consecutive exports do not grow RSS without bound',
      () async {
    final tmp = Directory.systemTemp.createTempSync('t19_leak');
    addTearDown(() => tmp.delete(recursive: true));

    await runPptExportInIsolate(photoDeck(60, 20), '${tmp.path}/a.pptx');
    final afterFirst = rssMb();
    await runPptExportInIsolate(photoDeck(60, 20), '${tmp.path}/b.pptx');
    final afterSecond = rssMb();
    await runPptExportInIsolate(photoDeck(60, 20), '${tmp.path}/c.pptx');
    final afterThird = rssMb();

    final growth1 = afterSecond - afterFirst;
    final growth2 = afterThird - afterSecond;

    File('tool/ram_results_beta3.md').writeAsStringSync(
      '\n\n## Leak check ($label)\n\n'
      '| Export | RSS after | Delta vs previous |\n|---|---|---|\n'
      '| #1 | ${afterFirst.toStringAsFixed(1)} MB | - |\n'
      '| #2 | ${afterSecond.toStringAsFixed(1)} MB | '
          '${growth1.toStringAsFixed(1)} MB |\n'
      '| #3 | ${afterThird.toStringAsFixed(1)} MB | '
          '${growth2.toStringAsFixed(1)} MB |\n',
      mode: FileMode.append,
      flush: true,
    );

    // A leak would keep climbing; warm runs must plateau (allow 25 MB of
    // noise from the VM/heap and the cached deck).
    expect(growth2, lessThan(25),
        reason: 'T19.9: repeated exports must not grow RSS without bound '
            '(first delta ${growth1.toStringAsFixed(1)} MB, '
            'second ${growth2.toStringAsFixed(1)} MB)');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
