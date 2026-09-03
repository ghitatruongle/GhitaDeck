import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/export_job.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/html_parse_codec.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:image/image.dart' as img;

/// T13.1 profile: what fraction of total PPTX export time is HTML parsing?
///
/// Deck: 100 slides from 40 unique HTML bodies (duplicated-slide pattern the
/// session parse cache is designed for) plus a worst-case variant with 100
/// fully unique bodies (cache miss every slide).
///
/// Run: flutter test tool/t13_parse_profile_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String slideBody(int n) =>
      '<h1>Tiêu đề $n</h1><h2>Phụ đề $n</h2>'
      '<p>Đoạn văn tiếng Việt có dấu <b>đậm</b> và <i>nghiêng</i> $n</p>'
      '<ul><li>Mục một — bullet $n</li><li>Mục hai</li>'
      '<li>Mục ba với nội dung dài hơn để tăng kích thước slide</li></ul>'
      '<table><tr><th>Cột A</th><th>Cột B</th><th>Cột C</th></tr>'
      '<tr><td>Ô 1</td><td>Ô 2</td><td>Ô 3</td></tr></table>'
      '<aside class="notes">Ghi chú diễn giả $n.</aside>';

  // Realistic deck: 80 rich text slides + 20 slides with one photo each
  // (JPEG 800x450 ~ 80–120 KB) — the distribution typical of real decks.
  Uint8List? photoCache;
  Uint8List photo() => photoCache ??= () {
        final rng = Random(7);
        final image = img.Image(width: 800, height: 450);
        for (final p in image) {
          p.r = rng.nextInt(256);
          p.g = rng.nextInt(256);
          p.b = rng.nextInt(256);
        }
        return Uint8List.fromList(img.encodeJpg(image, quality: 85));
      }();

  String realisticBody(int i) {
    if (i >= 80) {
      return '<h1>Slide ảnh $i</h1>'
          '<img src="data:image/jpeg;base64,${base64Encode(photo())}"/>'
          '<p>Chú thích ảnh $i với tiếng Việt.</p>';
    }
    return slideBody(i % 40 + 1);
  }

  Map<String, dynamic> slideFor(int i, int uniqueCount) {
    final n = uniqueCount == 40 ? (i % 40) + 1 : i + 1;
    return {
      'title': 'Slide số ${i + 1}',
      'htmlContent': slideBody(n),
      if (i.isEven) 'effect': 'fade',
    };
  }

  Future<T> runTemp<T>(Future<T> Function(Directory dir) body) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t13_');
    try {
      return await body(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<ExportTimings> timePptx(
      List<Map<String, dynamic>> deck, HtmlParseCache cache) {
    return runTemp((dir) async {
      final timings = ExportTimings();
      final job = ExportJob(
        slides: deck,
        outputPath: '${dir.path}/deck.pptx',
        format: ExportJobFormat.pptx,
        options: const ExportJobOptions(includeNotes: true),
        parseCache: cache,
      );
      await job.run(timings: timings);
      return timings;
    });
  }

  String profileRow(String label, ExportTimings t) {
    if (t.totalMs <= 0) return '$label: totalMs=0 (thrown?)';
    final pct = (t.parseMs / t.totalMs * 100).toStringAsFixed(1);
    return '$label: parse=${t.parseMs.toStringAsFixed(1)} ms '
        'build=${t.buildMs.toStringAsFixed(1)} ms '
        'zip=${t.zipMs.toStringAsFixed(1)} ms '
        'total=${t.totalMs.toStringAsFixed(1)} ms -> parse $pct%';
  }

  test('profile: 100 slides / 40 unique (cache-friendly deck)', () async {
    await HtmlParseEngineConfig.ensureRustReadyOnce();
    final deck = List<Map<String, dynamic>>.generate(100, (i) => slideFor(i, 40));
    final cold = await timePptx(deck, HtmlParseCache());
    // ignore: avoid_print
    print('T13.1 ${profileRow('40-unique cold', cold)}');
    expect(cold.totalMs, greaterThan(0));
  });

  test('profile: 100 slides / 100 unique (cache-miss worst case)', () async {
    await HtmlParseEngineConfig.ensureRustReadyOnce();
    final deck =
        List<Map<String, dynamic>>.generate(100, (i) => slideFor(i, 100));
    final cold = await timePptx(deck, HtmlParseCache());
    // ignore: avoid_print
    print('T13.1 ${profileRow('100-unique cold', cold)}');
    expect(cold.totalMs, greaterThan(0));
  });

  test('profile: 100 slides realistic (80 text + 20 photo)', () async {
    await HtmlParseEngineConfig.ensureRustReadyOnce();
    final deck = List<Map<String, dynamic>>.generate(100, (i) => {
          'title': 'Slide số ${i + 1}',
          'htmlContent': realisticBody(i),
          if (i.isEven) 'effect': 'fade',
        });
    final cold = await timePptx(deck, HtmlParseCache());
    // ignore: avoid_print
    print('T13.1 ${profileRow('realistic 80/20 cold', cold)}');
    expect(cold.totalMs, greaterThan(0));
  });
}
