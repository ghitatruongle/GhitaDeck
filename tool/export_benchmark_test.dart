import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/export_job.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:image/image.dart' as img;

/// Track 01 benchmark (phases 1 & 7).
///
/// Measures the export pipeline on a standard 20-slide deck:
///
///  * _before_ — v1.6.3 encoder behavior (deflate level 1, media compressed,
///    per-slide parse without a session cache),
///  * _after_ — level 9 text compression, already-compressed media stored,
///    and the shared session parse cache.
///
/// Run standalone:
///   flutter test tool/export_benchmark_test.dart
/// To capture the markdown table, set GHITA_BENCH_LABEL (e.g. "Trước (v1.6.3)"
/// / "Sau (T01)") — results are appended to tool/benchmark_results_t01.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------- Standard 20-slide deck ----------
  final pngBytes = _makePng(128, 96);
  final pngDataUri = 'data:image/png;base64,${base64Encode(pngBytes)}';

  String slideWithNotes(int n) =>
      '<h2>Tiêu đề phụ $n</h2><p>Đoạn văn bản tiếng Việt có dấu '
      '<b>đậm</b> và <i>nghiêng</i> $n</p>'
      '<ul><li>Mục một — bullet $n</li><li>Mục hai</li>'
      '<li>Mục ba với nội dung dài hơn để tăng kích thước slide</li></ul>'
      '<aside class="notes">Ghi chú diễn giả $n với tiếng Việt.</aside>';

  String slideWithTable(int n) {
    final rows = StringBuffer();
    for (var r = 0; r < 5; r++) {
      rows.write('<tr>');
      for (var c = 0; c < 4; c++) {
        rows.write('<td>Ô $r-$c dữ liệu $n</td>');
      }
      rows.write('</tr>');
    }
    return '<h1>Bảng dữ liệu $n</h1><table><tr>'
        '<th>Cột A</th><th>Cột B</th><th>Cột C</th><th>Cột D</th></tr>'
        '$rows</table>';
  }

  String slideWithImage(int n) =>
      '<h1>Slide ảnh $n</h1><img src="$pngDataUri"/>'
      '<p>Chú thích ảnh $n</p>';

  String slideStyled(int n) =>
      '<h1>Đầu đề $n</h1><h2>Phụ đề $n</h2>'
      '<p style="color:#ff0000">Chữ màu đỏ $n</p>'
      '<p style="font-size:150%">Chữ cỡ lớn $n</p>'
      '<p style="text-decoration:underline">Chữ gạch chân $n</p>';

  // 4 unique contents; n cycles 1..4 so identical HTML repeats every 4
  // slides — exactly the duplicated-slide pattern the parse cache targets.
  final contentTemplates = [
    slideWithNotes,
    slideWithTable,
    slideWithImage,
    slideStyled,
  ];
  final slides = List<Map<String, dynamic>>.generate(20, (i) {
    final n = (i % 4) + 1;
    return {
      'title': 'Slide số ${i + 1}',
      'htmlContent': contentTemplates[i % 4](n),
      if (i.isEven) 'effect': 'fade',
      if (i % 3 == 0) 'bgColor': '#f2f6ff',
    };
  });

  Future<void> runTemp(
      Future<void> Function(Directory dir) body) async {
    final dir = await Directory.systemTemp.createTemp('ghita_bench_');
    try {
      await body(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  // Parse-only measurement (v1.6.3 path): one untcached tokenization per slide.
  double measureParseMs(List<Map<String, dynamic>> deck) {
    final watch = Stopwatch()..start();
    for (final slide in deck) {
      PPTGenerator.parseHtmlContentFull(
          (slide['htmlContent'] ?? '').toString());
    }
    watch.stop();
    return watch.elapsedMicroseconds / 1000;
  }

  test('benchmark 20-slide deck before vs after', () async {
    // ---- Row 1: before (v1.6.3 encoder behavior, no parse cache) ----
    PPTGenerator.debugZipLevel = Deflate.BEST_SPEED; // 1 (v1.6.3 default)
    PPTGenerator.debugStoreCompressedMedia = false;
    final beforeParseMs = measureParseMs(slides);

    final beforeTimings = ExportTimings();
    await runTemp((dir) async {
      final job = ExportJob(
        slides: slides,
        outputPath: '${dir.path}/before.pptx',
        format: ExportJobFormat.pptx,
        options: const ExportJobOptions(includeNotes: true),
      );
      await job.run(timings: beforeTimings);
    });

    // ---- Rows 2-4: after (level 9 + stored media + shared parse cache) ----
    PPTGenerator.debugZipLevel = Deflate.BEST_COMPRESSION; // 9
    PPTGenerator.debugStoreCompressedMedia = true;

    final afterCache = HtmlParseCache();
    final afterTimings = ExportTimings();
    await runTemp((dir) async {
      final job = ExportJob(
        slides: slides,
        outputPath: '${dir.path}/after.pptx',
        format: ExportJobFormat.pptx,
        options: const ExportJobOptions(includeNotes: true),
        parseCache: afterCache,
      );
      await job.run(timings: afterTimings);
    });

    // Second identical PPTX run — the cache now serves every slide.
    final warmTimings = ExportTimings();
    await runTemp((dir) async {
      final job = ExportJob(
        slides: slides,
        outputPath: '${dir.path}/warm.pptx',
        format: ExportJobFormat.pptx,
        options: const ExportJobOptions(includeNotes: true),
        parseCache: afterCache,
      );
      await job.run(timings: warmTimings);
    });

    // PDF + HTML totals (after-mode) for the same deck.
    final pdfTimings = ExportTimings();
    await runTemp((dir) async {
      final job = ExportJob(
        slides: slides,
        outputPath: '${dir.path}/deck.pdf',
        format: ExportJobFormat.pdf,
        options: const ExportJobOptions(includeNotes: true),
        parseCache: afterCache,
      );
      await job.run(timings: pdfTimings);
    });
    final htmlTimings = ExportTimings();
    await runTemp((dir) async {
      final job = ExportJob(
        slides: slides,
        outputPath: '${dir.path}/deck.html',
        format: ExportJobFormat.html,
        options: const ExportJobOptions(includeNotes: true),
        parseCache: afterCache,
      );
      await job.run(timings: htmlTimings);
    });

    // Warm-run parse stays at 0 because every slide is served from the cache;
    // the first run tokenized exactly the 4 unique contents once each.
    expect(warmTimings.parseMs, lessThan(1.0));
    expect(afterTimings.parseMs, greaterThan(0));
    expect(afterCache.misses, equals(4));
    expect(afterCache.hits, greaterThan(0));

    final lines = <String>[
      '| Đo lường | Parse | Build XML | Nén ZIP | Tổng | Dung lượng |',
      '|---|---|---|---|---|---|',
      '| Trước (v1.6.3): parse lẻ + ZIP mức 1, nén cả media | '
          '${_fmt(beforeParseMs)} ms | — (nằm trong Tổng) | — | '
          '${_fmt(beforeTimings.totalMs)} ms | ${beforeTimings.bytes} B |',
      afterTimings.toTableRow('Sau (T01): parse 1 lần + ZIP mức 9, media stored'),
      warmTimings.toTableRow('Sau, lần 2 cùng phiên (cache đã ấm)'),
      '| Sau (T01): PDF (tổng) | — | — | — | ${_fmt(pdfTimings.totalMs)} ms | '
          '${pdfTimings.bytes} B |',
      '| Sau (T01): HTML (tổng) | — | — | — | ${_fmt(htmlTimings.totalMs)} ms | '
          '${htmlTimings.bytes} B |',
      '| Tham khảo | deck 20 slide, 4 nội dung duy nhất (lặp 5 lần), có ảnh PNG 128x96 | — | — | — | — |',
    ];

    final label = Platform.environment['GHITA_BENCH_LABEL'];
    if (label != null) {
      final file = File('tool/benchmark_results_t01.md');
      final out = StringBuffer();
      if (file.existsSync()) out.write(file.readAsStringSync());
      out
        ..writeln()
        ..writeln('## $label — ${DateTime.now().toString().substring(0, 19)}')
        ..writeln();
      for (final l in lines) {
        out.writeln(l);
      }
      await file.writeAsString(out.toString(), flush: true);
    }
  });
}

String _fmt(double v) =>
    v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

Uint8List _makePng(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      image.setPixelRgb(x, y, (x * 255 ~/ w), (y * 255 ~/ h), 140);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}