import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/export_job.dart';
import 'package:ghita_ppt_converter/services/html_image_loader.dart';
import 'package:ghita_ppt_converter/services/image_codec.dart';
import 'package:ghita_ppt_converter/services/image_optimizer_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:image/image.dart' as img;

/// Track 03 tests — image pipeline: dedupe, re-encode, remote embedding.
///
///  * identical image bytes across slides embed one media part (≥50% size
///    reduction on a deck of 10 duplicated images),
///  * remote http images are fetched with the guardrails (timeout, 10 MB
///    cap, image/* validation), served from the memory + disk caches, and
///    embedded into the PPTX,
///  * large opaque PNGs re-encode as JPEG (alpha keeps PNG), EXIF orientation
///    is baked before embedding,
///  * dropped/dirty images are recorded and written to `<out>.warnings.log`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ghita_t03_');
    // flutter_test replaces dart:io HttpClient with a 400-returning mock;
    // these tests exercise the real fetch path against a localhost server.
    HttpOverrides.global = null;
    HtmlImageLoader.clearCaches();
    HtmlImageLoader.debugCacheDir = '${tempDir.path}/image_cache';
    PPTGenerator.debugDisableMediaDedupe = false;
  });

  tearDown(() async {
    HtmlImageLoader.clearCaches();
    HtmlImageLoader.debugCacheDir = null;
    await tempDir.delete(recursive: true);
  });

  Uint8List opaquePng(int width, int height) {
    final image = img.Image(width: width, height: height);
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        image.setPixelRgb(x, y, (x * 255 ~/ width), (y * 255 ~/ height), 140);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  String dataUri(Uint8List bytes) =>
      'data:image/png;base64,${base64Encode(bytes)}';

  String dataUriWith(Uint8List bytes, String mime) =>
      'data:$mime;base64,${base64Encode(bytes)}';

  Uint8List crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    crc ^= 0xFFFFFFFF;
    final out = Uint8List(4);
    out.buffer.asByteData().setUint32(0, crc & 0xFFFFFFFF);
    return out;
  }

  /// Insert an `eXIf` chunk (TIFF bytes) right after the IHDR chunk of a
  /// PNG, with a correct CRC; PNG chunk CRC-32 (poly 0xEDB88320).
  Uint8List pngWithExifChunk(Uint8List png, List<int> tiff) {
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
          ..add(crc32(chunkData));
      }
    }
    return out.toBytes();
  }

  test('10 slides sharing one image embed it once (size ≥ 50% smaller)',
      () async {
    // A large image makes media the dominant part of the deck, exactly the
    // scenario the ≥50% size gate targets.
    final png = opaquePng(600, 400);
    final src = dataUri(png);
    final deck = List<Map<String, dynamic>>.generate(10, (i) => {
          'title': 'Slide $i',
          'htmlContent': '<img src="$src">',
        });

    Future<Uint8List> exportPptx() async {
      final out = '${tempDir.path}/deck.pptx';
      await PPTGenerator.generatePPT(deck, out);
      return File(out).readAsBytesSync();
    }

    // With dedupe: exactly one media part for all ten slides.
    final deduped = await exportPptx();
    final dedupedArchive = ZipDecoder().decodeBytes(deduped);
    final dedupedMedia = dedupedArchive.files
        .where((e) => e.name.startsWith('ppt/media/'))
        .toList();
    expect(dedupedMedia.length, 1,
        reason: 'identical bytes must embed once across slides');

    // v1.6.3 behavior (dedupe disabled): ten copies.
    PPTGenerator.debugDisableMediaDedupe = true;
    final repeated = await exportPptx();
    PPTGenerator.debugDisableMediaDedupe = false;
    expect(
      ZipDecoder()
          .decodeBytes(repeated)
          .files
          .where((e) => e.name.startsWith('ppt/media/'))
          .length,
      10,
    );

    // Phase 8 gate: the deduped deck is at least 50% smaller.
    expect(deduped.length, lessThanOrEqualTo(repeated.length ~/ 2));
    // Every slide still references the media part through its own rels.
    for (var i = 1; i <= 10; i++) {
      final rels = dedupedArchive.files
          .firstWhere((e) => e.name == 'ppt/slides/_rels/slide$i.xml.rels');
      expect(utf8.decode(rels.content as List<int>),
          contains('../media/${dedupedMedia.single.name.split('/').last}'));
    }
  });

  test('remote http images are fetched, cached and embedded', () async {
    final png = opaquePng(32, 24);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('image', 'png')
        ..add(png)
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/pic.png';

    try {
      final slides = [
        {
          'title': 'Web',
          'htmlContent': '<p>Caption</p><img src="$url">',
        }
      ];
      // Prefetch populates memory + disk caches.
      await HtmlImageLoader.prefetchSlides(slides);
      expect(HtmlImageLoader.warnings, isEmpty);

      final loaded = HtmlImageLoader.load(url);
      expect(loaded, isNotNull);
      expect(loaded!.ext, 'png');
      expect(loaded.width, 32);
      expect(loaded.height, 24);

      // Disk cache exists and serves a fresh session.
      final cacheDir = Directory('${tempDir.path}/image_cache');
      final cacheFiles = cacheDir.listSync().whereType<File>().toList();
      expect(cacheFiles, isNotEmpty, reason: 'expected a disk-cache entry');
      final cachedBytes = cacheFiles.first.readAsBytesSync();
      expect(cachedBytes, orderedEquals(png),
          reason: 'disk cache must hold the fetched bytes');
      HtmlImageLoader.clearCaches();
      final fromDisk = HtmlImageLoader.load(url);
      expect(fromDisk, isNotNull, reason: 'disk cache must survive clearCaches');
      expect(fromDisk!.width, 32);

      // Full pipeline: the remote image lands inside the PPTX.
      final out = '${tempDir.path}/remote.pptx';
      await PPTGenerator.generatePPT(slides, out);
      final archive = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
      expect(
          archive.files.any((e) => e.name.startsWith('ppt/media/')), isTrue);
    } finally {
      await server.close(force: true);
    }
  });

  test('non-image responses are rejected with a warning', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('text', 'plain', charset: 'utf-8')
        ..write('definitely not an image')
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/fake.png';
    try {
      await HtmlImageLoader.prefetchSlides(
          [{'title': 'x', 'htmlContent': '<img src="$url">'}]);
      expect(HtmlImageLoader.warnings.map((w) => w.src),
          contains(url));
      expect(HtmlImageLoader.load(url), isNull);
    } finally {
      await server.close(force: true);
    }
  });

  test('oversized responses (> 10 MB) are dropped with a warning', () async {
    final big = Uint8List(11 * 1024 * 1024)
      ..[0] = 0x89
      ..[1] = 0x50
      ..[2] = 0x4E
      ..[3] = 0x47; // pretend-PNG bytes, far over the cap
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('image', 'png')
        ..add(big)
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/big.png';
    try {
      await HtmlImageLoader.prefetchSlides(
          [{'title': 'x', 'htmlContent': '<img src="$url">'}]);
      expect(
        HtmlImageLoader.warnings.any((w) => w.reason.contains('10 MB')),
        isTrue,
      );
      expect(HtmlImageLoader.load(url), isNull);
    } finally {
      await server.close(force: true);
    }
  });

  test('large opaque PNGs convert to JPEG; alpha images keep PNG', () {
    final opaque = opaquePng(600, 400); // ≥ 512 px threshold, no alpha
    final alpha = Uint8List.fromList(img.encodePng(
      img.Image(width: 600, height: 400, numChannels: 4),
    ));

    final asJpeg = HtmlImageLoader.load(dataUri(opaque),
        allowJpeg: true, jpegQuality: 80);
    expect(asJpeg, isNotNull);
    expect(asJpeg!.ext, 'jpg');

    final withAlpha = HtmlImageLoader.load(dataUri(alpha),
        allowJpeg: true, jpegQuality: 80);
    expect(withAlpha, isNotNull);
    expect(withAlpha!.ext, 'png', reason: 'transparency must stay lossless');

    // Default (HTML): no conversion, stays PNG.
    final htmlPath = HtmlImageLoader.load(dataUri(opaque));
    expect(htmlPath, isNotNull);
    expect(htmlPath!.ext, 'png');
  });

  test('EXIF orientation is baked before embedding', () {
    // 32×16 PNG carrying an eXIf chunk with orientation 6 (rotate 90° CW).
    // PNG is used because package:image's JPEG decoder already bakes JPEG
    // EXIF itself, while PNG eXIf chunks are ignored by the library — the
    // loader's own reader must handle that case. After baking the
    // dimensions swap to 16×32.
    final base = img.encodePng(img.Image(width: 32, height: 16));
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
    final pngWithExif = pngWithExifChunk(base, tiff);

    final loaded = HtmlImageLoader.load(
      'data:image/png;base64,${base64Encode(pngWithExif)}',
    );
    expect(loaded, isNotNull);
    // Orientation 6 = rotate 90° CW: 32×16 becomes 16×32.
    expect(loaded!.width, 16);
    expect(loaded.height, 32);
  });

  test('dirty images are skipped and reported in the warnings log', () async {
    final slides = [
      {
        'title': 'Dirty',
        'htmlContent':
            '<img src="data:image/png;base64,${base64Encode(Uint8List.fromList([1, 2, 3]))}">'
                '<p>Vẫn xuất được</p>',
      }
    ];
    final out = '${tempDir.path}/dirty.pptx';
    final job = ExportJob(
      slides: slides,
      outputPath: out,
      format: ExportJobFormat.pptx,
    );
    await job.run();

    // The deck is valid and contains the text but no picture.
    final archive = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
    expect(archive.files.any((e) => e.name.startsWith('ppt/media/')), isFalse);
    // The warnings log sits next to the output.
    final log = File('$out.warnings.log');
    expect(log.existsSync(), isTrue);
    expect(log.readAsStringSync(), contains('undecodable/dirty image'));
  });

  test('a clean export writes no warnings log', () async {
    final out = '${tempDir.path}/clean.pptx';
    final job = ExportJob(
      slides: [
        {
          'title': 'Sạch',
          'htmlContent': '<p>Không có ảnh lỗi.</p>',
        }
      ],
      outputPath: out,
      format: ExportJobFormat.pptx,
    );
    await job.run();
    expect(File('$out.warnings.log').existsSync(), isFalse);
  });

  test('B18: editing a local file invalidates the processed cache', () async {
    final imgPath = '${tempDir.path}/photo.png';
    File(imgPath).writeAsBytesSync(opaquePng(600, 400));
    final first = HtmlImageLoader.load(imgPath, maxWidth: 200)!;
    // Unchanged → served from the cache (same bytes, one decode only).
    final again = HtmlImageLoader.load(imgPath, maxWidth: 200)!;
    expect(again.bytes, orderedEquals(first.bytes),
        reason: 'unchanged image must be served from the cache');

    // Same path, same options, different pixels → must reprocess.
    File(imgPath).writeAsBytesSync(opaquePng(600, 300)); // different aspect
    final second = HtmlImageLoader.load(imgPath, maxWidth: 200)!;
    expect(second.height, isNot(equals(first.height)),
        reason: 'edited file must NOT reuse the stale processed entry');
    expect(second.width, 200);
    expect(second.height, 100);
  });

  test('B18: remote image is re-fetched when the server content changes',
      () async {
    var served = opaquePng(32, 24);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('image', 'png')
        ..add(served)
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/pic.png';
    try {
      // Export 1: server serves 32×24.
      await HtmlImageLoader.prefetchSlides(
          [{'title': 'x', 'htmlContent': '<img src="$url">'}]);
      expect(HtmlImageLoader.load(url)!.width, 32);
      // Export 2: same URL, new content (64×48) — the old disk cache entry
      // must not be served.
      HtmlImageLoader.clearCaches();
      served = opaquePng(64, 48);
      await HtmlImageLoader.prefetchSlides(
          [{'title': 'x', 'htmlContent': '<img src="$url">'}]);
      final loaded = HtmlImageLoader.load(url)!;
      expect(loaded.width, 64,
          reason: 'remote content change must be picked up (B18)');
      expect(loaded.height, 48);
    } finally {
      await server.close(force: true);
    }
  });

  test('B22: truncated processed-cache entry is rejected and reprocessed',
      () async {
    final imgPath = '${tempDir.path}/photo.png';
    final png = opaquePng(600, 400);
    File(imgPath).writeAsBytesSync(png);
    HtmlImageLoader.load(imgPath, maxWidth: 200); // writes the disk entry

    final cacheDir = Directory('${tempDir.path}/image_cache');
    final procFile = cacheDir
        .listSync()
        .whereType<File>()
        .firstWhere((f) =>
            f.uri.pathSegments.last.startsWith('proc_') &&
            !f.uri.pathSegments.last.endsWith('.json'));
    final goodLength = procFile.lengthSync();
    final half = procFile.readAsBytesSync().sublist(0, goodLength ~/ 2);
    procFile.writeAsBytesSync(half);
    HtmlImageLoader.clearCaches(); // force the disk read

    final loaded = HtmlImageLoader.load(imgPath, maxWidth: 200)!;
    expect(loaded.bytes, isNot(orderedEquals(half)),
        reason: 'truncated cache bytes must never be embedded');
    expect(procFile.lengthSync(), greaterThan(half.length),
        reason: 'the corrupt entry must be replaced with a valid one');
  });

  test('B23: processed-cache sidecar stays small even for a data-URI image',
      () async {
    final bigPng = opaquePng(600, 400);
    final uri = dataUri(bigPng);
    HtmlImageLoader.load(uri, maxWidth: 200);
    HtmlImageLoader.clearCaches(); // memory out — disk sidecar is read next
    HtmlImageLoader.load(uri, maxWidth: 200); // read the disk entry
    final dir = Directory('${tempDir.path}/image_cache');
    final metas = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.endsWith('.json'))
        .toList();
    expect(metas, isNotEmpty);
    for (final meta in metas) {
      expect(meta.lengthSync(), lessThan(2048),
          reason: 'meta JSON must hold a hash, not the MB-size options blob');
    }
  });

  test('B24: processed-cache hits still count optimization savings', () async {
    ImageOptimizationStats.reset();
    ImageOptimizerConfig.betaEnabled = true;
    addTearDown(() => ImageOptimizerConfig.betaEnabled = false);
    final imgPath = '${tempDir.path}/photo.png';
    File(imgPath).writeAsBytesSync(opaquePng(600, 400));
    HtmlImageLoader.load(imgPath, maxWidth: 200, allowJpeg: true); // processes
    final firstCount = ImageOptimizationStats.processedCount;
    expect(firstCount, greaterThan(0),
        reason: 'the fresh conversion must already be tallied');

    // Next export (new session, same disk cache): everything comes from the
    // processed cache — the saving must still be counted (B24).
    HtmlImageLoader.clearCaches();
    HtmlImageLoader.load(imgPath, maxWidth: 200, allowJpeg: true);
    expect(ImageOptimizationStats.processedCount, greaterThan(firstCount),
        reason: 'cache hits must keep tallying savings (B24)');
    expect(ImageOptimizationStats.savedBytes, greaterThan(0));
  });

  test('B19: decompression bombs are rejected before any decode', () {
    // Tiny PNG whose IHDR claims 40000×40000: decoding would allocate ~6 GB.
    final bomb = pngWithFakeDims(40000, 40000);
    expect(HtmlImageLoader.load(dataUri(bomb)), isNull,
        reason: 'data-URI bomb must be dropped before decode');
    expect(HtmlImageLoader.warnings.any((w) => w.reason.contains('pixel')),
        isTrue);

    final imgPath = '${tempDir.path}/bomb.png';
    File(imgPath).writeAsBytesSync(bomb);
    expect(HtmlImageLoader.load(imgPath), isNull,
        reason: 'local-file bomb must also be dropped');
  });

  test('B21: WebP/BMP/SVG are dropped with an accurate warning', () {
    final webp = Uint8List.fromList(
        [0x52, 0x49, 0x46, 0x46, 20, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0, 0, 0, 0]);
    final bmp = Uint8List.fromList([0x42, 0x4D, 0, 0, 0, 0, 0, 0, 0, 0]);
    final svg = Uint8List.fromList(
        '<svg xmlns="http://www.w3.org/2000/svg"></svg>'.codeUnits);

    expect(HtmlImageLoader.load(dataUriWith(webp, 'image/webp')), isNull);
    expect(HtmlImageLoader.warnings.last.reason,
        contains('unsupported format webp'),
        reason: 'B21: must name the real problem, not "not an image"');
    expect(HtmlImageLoader.load(dataUriWith(bmp, 'image/bmp')), isNull);
    expect(HtmlImageLoader.warnings.last.reason,
        contains('unsupported format bmp'));
    expect(HtmlImageLoader.load(dataUriWith(svg, 'image/svg+xml')), isNull);
    expect(HtmlImageLoader.warnings.last.reason,
        contains('unsupported format svg'),
        reason: 'B21: SVG falls through to the icon pipeline — a plain <img> '
            'must be reported accurately, never "file not found"');
  });

  test('B21: remote WebP (image/webp MIME) drops with the same warning',
      () async {
    final webp = Uint8List.fromList(
        [0x52, 0x49, 0x46, 0x46, 20, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0, 0, 0, 0]);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('image', 'webp')
        ..add(webp)
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/pic.webp';
    try {
      await HtmlImageLoader.prefetchSlides(
          [{'title': 'x', 'htmlContent': '<img src="$url">'}]);
      expect(HtmlImageLoader.load(url), isNull);
      expect(
          HtmlImageLoader.warnings.any((w) => w.reason.contains('webp')),
          isTrue,
          reason: 'MIME-recognized formats must be reported accurately');
    } finally {
      await server.close(force: true);
    }
  });

  test('B20/B6a: backend tag splits the processed cache; dartOnly never Rust',
      () async {
    ImageEngineConfig.setPreferredRust(false);
    addTearDown(() => ImageEngineConfig.setPreferredRust(false));
    final imgPath = '${tempDir.path}/photo.png';
    File(imgPath).writeAsBytesSync(opaquePng(600, 400));
    final cacheDir = Directory('${tempDir.path}/image_cache');
    int procCount() => cacheDir.existsSync()
        ? cacheDir
            .listSync()
            .whereType<File>()
            .where((f) =>
                f.uri.pathSegments.last.startsWith('proc_') &&
                !f.uri.pathSegments.last.endsWith('.json'))
            .length
        : 0;

    HtmlImageLoader.load(imgPath); // dart-tagged entry
    final dartCount = procCount();
    expect(dartCount, 1);

    // "Rust ready" with no DLL: process() falls back internally, but the
    // cache KEY still separates the backends (no cross-serving Rust output
    // into a Dart run or vice versa).
    ImageEngineConfig.setPreferredRust(true);
    ImageEngineConfig.markRustReady();
    HtmlImageLoader.load(imgPath); // rust-tagged entry
    expect(procCount(), dartCount + 1,
        reason: 'B20: dart/rust tagged entries must not share a cache slot');

    // B6a: the UI-isolate renderer forces dartOnly — its load must never
    // route to the (synchronous) Rust FRB call, even when Rust is ready.
    final loaded =
        HtmlImageLoader.load(imgPath, maxWidth: 200, dartOnly: true);
    expect(loaded, isNotNull);
    expect(ImageCodec.lastBackend, 'dart',
        reason: 'B6a: dartOnly must use the Dart implementation');
  });
}

/// A valid small PNG with the IHDR dimensions overwritten to [w]×[h] — the
/// header check (B19) reads these without validating the chunk CRC, so the
/// decoder never runs.
Uint8List pngWithFakeDims(int w, int h) {
  final small = img.encodePng(img.Image(width: 16, height: 16));
  final out = Uint8List.fromList(small);
  final bd = ByteData.sublistView(out);
  bd.setUint32(16, w);
  bd.setUint32(20, h);
  return out;
}