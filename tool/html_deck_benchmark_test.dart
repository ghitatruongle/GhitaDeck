import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;

/// Track 07 benchmark (phases 1 & 7): weight of a standard HTML deck.
///
/// Deck: 10 slides, 10 distinct images (base64-embedded), several effects.
/// Measures total bytes, the CSS/JS/image payload split, and the time to
/// tokenize the deck (the first-slide paint proxy in this environment).
///
/// Run standalone:
///   flutter test tool/html_deck_benchmark_test.dart
/// With GHITA_BENCH_LABEL set, results are appended to
/// tool/benchmark_results_t07.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String makeImage(int seed) {
    final image = img.Image(width: 320, height: 200);
    for (var x = 0; x < 320; x++) {
      for (var y = 0; y < 200; y++) {
        image.setPixelRgb(x, y, (x + seed) % 256, (y + seed) % 256, 130);
      }
    }
    return base64Encode(img.encodePng(image));
  }

  test('benchmark 10-slide / 10-image HTML deck', () async {
    const effects = [
      'fade',
      'pushLeft',
      'wipe',
      'splitIn',
      'checkerboard',
      'blinds',
      'clock',
      'zoom',
      'flyIn',
      'arc',
    ];
    final slides = List<Map<String, dynamic>>.generate(10, (i) {
      final image = makeImage(i);
      return {
        'title': 'Slide $i',
        'effect': effects[i % effects.length],
        'htmlContent':
            '<h2>Phụ đề $i</h2><p>Nội dung tiếng Việt có dấu $i.</p>'
                '<img src="data:image/png;base64,$image">',
      };
    });

    final dir = await Directory.systemTemp.createTemp('ghita_t07_bench_');
    final out = '${dir.path}/deck.html';
    try {
      HtmlExportService.clearDeckCache();
      final service = HtmlExportService();
      final watch = Stopwatch()..start();
      final path = await service.exportToHtmlPath(slides, out);
      watch.stop();
      final bytes = File(path).readAsStringSync();
      final byteLength = utf8.encode(bytes).length;

      final parseWatch = Stopwatch()..start();
      html_parser.parse(bytes);
      parseWatch.stop();

      final cssStart = bytes.indexOf('@keyframes');
      final cssEnd = bytes.indexOf('</style>');
      final cssBytes = utf8
          .encode(bytes.substring(cssStart, cssEnd))
          .length;
      final imgCount = RegExp('data:image/png;base64,').allMatches(bytes).length;

      final lines = <String>[
        '| Deck chuẩn 10 slide / 10 ảnh | Giá trị |',
        '|---|---|',
        '| Tổng dung lượng (UTF-8 bytes) | $byteLength B |',
        '| Thời gian build + ghi file | ${watch.elapsedMicroseconds / 1000} ms |',
        '| Thời gian parse HTML (proxy tải slide đầu) | '
            '${parseWatch.elapsedMicroseconds / 1000} ms |',
        '| CSS keyframes (bytes) | $cssBytes B |',
        '| Ảnh base64 nhúng (số lần) | $imgCount |',
      ];

      final label = Platform.environment['GHITA_BENCH_LABEL'];
      if (label != null) {
        final file = File('tool/benchmark_results_t07.md');
        final outBuf = StringBuffer();
        if (file.existsSync()) outBuf.write(file.readAsStringSync());
        outBuf
          ..writeln()
          ..writeln('## $label — ${DateTime.now().toString().substring(0, 19)}')
          ..writeln();
        for (final l in lines) {
          outBuf.writeln(l);
        }
        await file.writeAsString(outBuf.toString(), flush: true);
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}