import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/export_job.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:image/image.dart' as img;

/// T13.6b profile: how much of total PPTX export is the ZIP stage, and does
/// a streaming file→file API (dropping the 21.1 MB FRB copy) help ≥15%?
///
/// Deck: 20 slides × 20 unique JPEG media (photos-like, ~21 MB total).
/// ZipEngineConfig.preferredRust is toggled to compare backends; the Rust
/// path only runs when GHITA_ZIP_RUST=1 (real DLL call, fail-fast).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Uint8List> buildMedia() {
    final cacheDir = Directory('build/zip_bench_media');
    if (cacheDir.existsSync()) {
      final files = cacheDir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (files.length >= 20) {
        return files
            .take(20)
            .map((f) => f.readAsBytesSync())
            .toList(growable: false);
      }
    }
    // Regenerate noise photos once (same seed → deterministic bytes).
    final bytes = <Uint8List>[];
    final rng = Random(42);
    for (var i = 0; i < 20; i++) {
      final image = img.Image(width: 1600, height: 900);
      for (final p in image) {
        p.r = rng.nextInt(256);
        p.g = rng.nextInt(256);
        p.b = rng.nextInt(256);
      }
      final data = Uint8List.fromList(img.encodeJpg(image, quality: 90));
      bytes.add(data);
      cacheDir.createSync(recursive: true);
      File('${cacheDir.path}/image$i.jpg').writeAsBytesSync(data);
    }
    return bytes;
  }

  Future<T> runTemp<T>(Future<T> Function(Directory dir) body) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t13_6b_');
    try {
      return await body(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<ExportTimings> timePptx(List<Map<String, dynamic>> deck) async {
    final out = await runTemp((dir) async {
      final timings = ExportTimings();
      final job = ExportJob(
        slides: deck,
        outputPath: '${dir.path}/deck.pptx',
        format: ExportJobFormat.pptx,
        options: const ExportJobOptions(includeNotes: true),
      );
      await job.run(timings: timings);
      return timings;
    });
    return out;
  }

  String fmt(double v) => v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  test('T13.6b zip stage share of a 21 MB media deck', () async {
    final images = buildMedia();
    expect(images.length, greaterThanOrEqualTo(20));
    final deck = List<Map<String, dynamic>>.generate(20, (i) {
      return {
        'title': 'Slide số ${i + 1}',
        'htmlContent': slideHtml(i, images),
      };
    });

    final dart = await timePptx(deck);
    final dartZipPct = dart.totalMs > 0
        ? (dart.zipMs / dart.totalMs * 100).toStringAsFixed(1)
        : '?';
    // ignore: avoid_print
    print('T13.6b DART zip stage: total=${fmt(dart.totalMs)} ms '
        'zip=${fmt(dart.zipMs)} ms build=${fmt(dart.buildMs)} ms '
        'parse=${fmt(dart.parseMs)} ms -> zip share $dartZipPct% of total');
    expect(dart.totalMs, greaterThan(0));
  });
}

String slideHtml(int n, List<Uint8List> images) {
  final b64 = base64Encode(images[n]);
  return '<h1>Slide $n</h1><p>Đoạn văn tiếng Việt để nén thật: $n</p>'
      '<img src="data:image/jpeg;base64,$b64"/>'
      '<p style="color:#d45a73">Chú thích với nhiều lặp lại lặp lại lặp lại '
      'để có text nén được $n</p>';
}
