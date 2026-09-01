import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/html_image_loader.dart';
import 'package:ghita_ppt_converter/services/image_optimizer_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:image/image.dart' as img;

/// Track 04 (N2) — image-optimizer beta flag: savings gate (≥40% on a
/// 10-image deck), boundary images (alpha/small/EXIF/corrupt) and the
/// bit-perfect-off contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ImageOptimizerConfig.betaEnabled = false;
    ImageOptimizerConfig.quality = 80;
    HtmlImageLoader.clearCaches();
    HtmlImageLoader.clearWarnings();
    ImageOptimizationStats.reset();
  });

  Uint8List noisyPng(int w, int h, int seed, {bool alpha = false}) {
    final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
    final rng = Random(seed * 7919 + 17);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final noise = rng.nextInt(90) - 45;
        image.setPixelRgb(x, y, (x + seed) % 256, (y + noise) % 256,
            (125 + noise).clamp(0, 255));
      }
    }
    if (alpha) {
      // Alpha-only pattern at the center so hasAlpha is true.
      for (var y = 0; y < h; y += 2) {
        for (var x = 0; x < w; x += 2) {
          image.setPixelRgba(x, y, 10, 20, 30, 0);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  String dataUri(Uint8List bytes) =>
      'data:image/png;base64,${base64Encode(bytes)}';

  Map<String, dynamic> slideWith(String title, String html) => {
        'title': title,
        'htmlContent': html,
        'transition': 'none',
      };

  Future<Uint8List> exportPptx(List<Map<String, dynamic>> slides) async {
    final tmp = await Directory.systemTemp.createTemp('n2_opt');
    addTearDown(() => tmp.delete(recursive: true));
    final out = '${tmp.path}/deck.pptx';
    await PPTGenerator.generatePPT(slides, out);
    return File(out).readAsBytesSync();
  }

  int mediaTotalBytes(Archive decoded) {
    var total = 0;
    for (final f in decoded.files) {
      if (f.name.startsWith('ppt/media/')) {
        total += (f.content as List<int>).length;
      }
    }
    return total;
  }

  test('flag ON: 10-image deck saves ≥40% and stats are recorded', () async {
    final originals = [
      for (var i = 0; i < 10; i++) noisyPng(600, 450, i),
    ];
    final inBytes =
        originals.fold<int>(0, (a, b) => a + b.length);

    ImageOptimizerConfig.betaEnabled = true;
    final bytes = await exportPptx([
      for (var i = 0; i < 10; i++)
        slideWith('Slide $i', '<img src="${dataUri(originals[i])}"/>'),
    ]);

    final decoded = ZipDecoder().decodeBytes(bytes);
    final media = decoded.files.where((f) => f.name.startsWith('ppt/media/'));
    expect(media, isNotEmpty);
    // All converted: media parts are JPEGs now.
    expect(media.every((f) => f.name.endsWith('.jpg')), isTrue,
        reason: 'large opaque PNGs must be converted to JPEG');
    final outBytes = mediaTotalBytes(decoded);
    final saved = (inBytes - outBytes) / inBytes;
    debugPrint('N2: ${(saved * 100).toStringAsFixed(1)}% saved '
        '(in ${inBytes ~/ 1024} KB → ${outBytes ~/ 1024} KB)');
    expect(saved, greaterThanOrEqualTo(0.40),
        reason: 'savings ${(saved * 100).toStringAsFixed(1)}% < 40%');

    expect(ImageOptimizationStats.hasData, isTrue);
    expect(ImageOptimizationStats.summary(), isNotNull);
    expect(ImageOptimizationStats.processedCount, greaterThan(0));
  });

  test('flag OFF: output is byte-identical across runs (bit-perfect)', () async {
    final png = noisyPng(600, 450, 3);
    final slides = [
      slideWith('S', '<img src="${dataUri(png)}"/>'),
    ];
    final a = await exportPptx(slides);
    final b = await exportPptx(slides);
    expect(a, b, reason: 'flag-off must be fully deterministic');
    expect(ImageOptimizationStats.hasData, isFalse,
        reason: 'no stats bookkeeping while the flag is off');

    // Same pipeline but beta-quality override: output changes accordingly.
    ImageOptimizerConfig.betaEnabled = true;
    ImageOptimizerConfig.quality = 95;
    final c = await exportPptx(slides);
    expect(c, isNot(equals(a)),
        reason: 'beta quality must drive a different re-encode');
    expect(ImageOptimizationStats.hasData, isTrue);
    expect(ImageOptimizationStats.summary(), isNotNull);
  });

  test('stats display: local tally and worker-imported summary', () {
    ImageOptimizationStats.reset();
    ImageOptimizationStats.record(1000, 400);
    ImageOptimizationStats.record(2000, 1200);
    expect(ImageOptimizationStats.hasData, isTrue);
    // 1400 B saved of 3000 B = 46.7% → displayed "1 KB (47%)".
    expect(ImageOptimizationStats.summary(), '1 KB (47%)');
    expect(ImageOptimizationStats.displayCount, 2);

    // Worker reply takes precedence over the local tally.
    ImageOptimizationStats.importWorkerSummary('1 KB (50%)', 3);
    expect(ImageOptimizationStats.displaySummary(), '1 KB (50%)');
    expect(ImageOptimizationStats.displayCount, 3);

    ImageOptimizationStats.reset();
    expect(ImageOptimizationStats.hasData, isFalse);
    expect(ImageOptimizationStats.displaySummary(), isNull);
  });

  test('boundaries: alpha and small PNGs stay PNG', () {
    final alpha = noisyPng(600, 400, 5, alpha: true);
    final small = noisyPng(300, 200, 6);
    ImageOptimizerConfig.betaEnabled = true;

    expect(HtmlImageLoader.load(dataUri(alpha), allowJpeg: true)!.ext, 'png',
        reason: 'transparency must stay lossless');
    expect(HtmlImageLoader.load(dataUri(small), allowJpeg: true)!.ext, 'png',
        reason: 'below the 512 px threshold stays PNG');
  });

  test('boundaries: EXIF orientation still bakes with the flag on', () {
    // 32×16 PNG + eXIf orientation 6 → 16×32 after bake.
    final tiff = <int>[
      0x49, 0x49, 0x2A, 0x00, // II, 42
      0x08, 0x00, 0x00, 0x00, // IFD0 offset
      0x01, 0x00, // 1 entry
      0x12, 0x01, // tag 0x0112 orientation
      0x03, 0x00, // SHORT
      0x01, 0x00, 0x00, 0x00, // count 1
      0x06, 0x00, 0x00, 0x00, // value 6
      0x00, 0x00, 0x00, 0x00, // next IFD
    ];
    final bytes = Uint8List.fromList(img.encodePng(
      img.Image(width: 32, height: 16),
    ));
    // Inject the eXIf chunk the same way html_image_pipeline_test does.
    final withExif = _pngWithExifChunk(bytes, tiff);
    ImageOptimizerConfig.betaEnabled = true;
    final loaded = HtmlImageLoader.load(
        'data:image/png;base64,${base64Encode(withExif)}');
    expect(loaded, isNotNull);
    expect(loaded!.width, 16);
    expect(loaded.height, 32);
  });

  test('boundaries: corrupt image does not crash the export', () async {
    ImageOptimizerConfig.betaEnabled = true;
    final bytes = await exportPptx([
      slideWith('Bad', '<img src="data:image/png;base64,AAAAAQ==" />'),
    ]);
    expect(ZipDecoder().decodeBytes(bytes).files, isNotEmpty);
    expect(HtmlImageLoader.warnings, isNotEmpty,
        reason: 'dirty image must be reported, not thrown');
  });
}

/// Local crc32 (PNG chunk checksum) — same helper as html_image_pipeline_test.
Uint8List _crc32Uint8List(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return Uint8List(4)
    ..buffer.asByteData().setUint32(0, (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF);
}

/// Appends an `eXIf` chunk to [png] — same proven helper as
/// html_image_pipeline_test.dart (chunk with proper CRC, after IHDR).
Uint8List _pngWithExifChunk(Uint8List png, List<int> tiff) {
  final out = BytesBuilder();
  out.add(png.sublist(0, 8)); // signature
  var offset = 8;
  while (offset < png.length) {
    final len = ByteData.sublistView(png).getUint32(offset);
    final type = png.sublist(offset + 4, offset + 8);
    out.add(png.sublist(offset, offset + 8 + len + 4)); // whole chunk
    offset += 12 + len;
    if (String.fromCharCodes(type) == 'IHDR') {
      final chunkData = <int>[...ascii.encode('eXIf'), ...tiff];
      out
        ..add(Uint8List(4)..buffer.asByteData().setUint32(0, tiff.length))
        ..add(chunkData)
        ..add(_crc32Uint8List(chunkData));
    }
  }
  return out.toBytes();
}
