import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/image_codec.dart';
import 'package:ghita_ppt_converter/src/rust/api/image.dart' as rust_api;
import 'package:image/image.dart' as img;

/// Track 06 (ghita_image) benchmark — deck image pipeline.
///
/// Measures the full deterministic pipeline (decode → EXIF bake → resize →
/// re-encode at q80) for 20 realistic-size photos (10 JPEG 2048×1536 +
/// 10 PNG 1400×1050, photo-like entropy):
///
///  * Dart `image` implementation ([ImageCodec.processDart]) — always;
///  * Rust `ghita_core` module through the real DLL — only when
///    GHITA_IMG_RUST=1 (flutter test CWD = project root, the FRB non-packaged
///    loader resolves rust/target/release/ from there).
///
/// Media pixels are generated once and cached under build/img_bench_media/
/// so re-runs (and the regular suite) don't pay the encode cost.
/// Results are appended to tool/benchmark_results_image.md when
/// GHITA_BENCH_LABEL is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Image pipeline benchmark: Dart baseline + optional Rust engine',
      () async {
    // Not a fast-retry suite test: measure best-of-5 of a 72 MB pipeline;
    // the default 30 s package:test timeout is far too short.
    final jobs = _loadOrBuildMedia(10);

    // One full job set: every image processed with the export options the
    // PPTX/PDF/HTML generators use (maxWidth 1600, PNG→JPEG allowed @80).
    final inputBytes = jobs.fold<int>(0, (a, j) => a + j.bytes.length);

    final dartRows = <String>[];

    // Warm-up + measurement rounds; report the best round (optimiser noise
    // and page cache skew the first runs).
    const rounds = 5;
    var dartBest = 0.0;
    for (var r = 0; r < rounds; r++) {
      final sw = Stopwatch()..start();
      var out = 0;
      for (final j in jobs) {
        final res = ImageCodec.processDart(
          j.bytes,
          j.ext,
          maxWidth: 1600,
          allowJpeg: true,
          jpegQuality: 80,
        );
        out += res.bytes.length;
      }
      sw.stop();
      if (r > 0) dartBest = dartBest == 0 ? sw.elapsedMicroseconds / 1000 : min(dartBest, sw.elapsedMicroseconds / 1000);
      expect(out, greaterThan(0));
    }

    dartRows.add('| Pipeline **Dart `image`** | ${_fmt(dartBest)} ms | '
        '${_fmtBytes(inputBytes)} → ${_fmtBytes(_processedBytes(jobs))} |');

    if (Platform.environment['GHITA_IMG_RUST'] == '1') {
      ImageEngineConfig.setPreferredRust(true);
      final ok = await ImageEngineConfig.ensureRustReadyOnce();
      expect(ok, isTrue, reason: 'GHITA_IMG_RUST=1 but the DLL did not load');

      // T07 P6: Rust vs Dart equivalence — byte delta + pixel PSNR (the gate
      // is visual, not bit-perfect: JPEG quantization differs by encoder).
      var byteDelta = 0;
      var mse = 0.0;
      var maxPsnr = double.infinity;
      for (final j in jobs) {
        final dartRes = ImageCodec.processDart(
          j.bytes,
          j.ext,
          maxWidth: 1600,
          allowJpeg: true,
          jpegQuality: 80,
        );
        final rustRes = ImageCodec.process(
          j.bytes,
          j.ext,
          maxWidth: 1600,
          allowJpeg: true,
          jpegQuality: 80,
        );
        expect(rustRes.ext, dartRes.ext);
        expect(rustRes.width, dartRes.width);
        expect(rustRes.height, dartRes.height);
        byteDelta += (rustRes.bytes.length - dartRes.bytes.length).abs();
        final psnr = _psnr(dartRes.bytes, rustRes.bytes);
        if (psnr < maxPsnr) maxPsnr = psnr;
        mse += psnr;
      }
      final avgPsnr = mse / jobs.length;
      dartRows.add('| **Đối chiếu Rust vs Dart (T07 P6)** | byte lệch '
          '${_fmtBytes(byteDelta)} · PSNR trung bình ${avgPsnr.toStringAsFixed(1)} dB · '
          'PSNR tệ nhất ${maxPsnr.toStringAsFixed(1)} dB | — |');

      var rustBest = 0.0;
      for (var r = 0; r < rounds; r++) {
        final sw = Stopwatch()..start();
        for (final j in jobs) {
          final res = ImageCodec.process(
            j.bytes,
            j.ext,
            maxWidth: 1600,
            allowJpeg: true,
            jpegQuality: 80,
          );
          expect(res.bytes.length, greaterThan(0));
        }
        sw.stop();
        if (r > 0) {
          rustBest = rustBest == 0
              ? sw.elapsedMicroseconds / 1000
              : min(rustBest, sw.elapsedMicroseconds / 1000);
        }
      }
      final speedup = dartBest / rustBest;
      dartRows.add('| Pipeline **ghita_image (Rust, tuần tự)** | ${_fmt(rustBest)} ms | '
          '${_fmtBytes(inputBytes)} → ${_fmtBytes(_processedBytes(jobs))} |');
      dartRows.add('| **Speedup (Dart/Rust tuần tự)** | '
          '${speedup.toStringAsFixed(2)}× | — |');

      // Batch API (rayon): what the N2 optimizer path uses — the export
      // hot-path stays sequential (one image per slide embed).
      var batchBest = 0.0;
      final rustJobs = [
        for (final j in jobs)
          rust_api.ImageJob(
            bytes: j.bytes,
            ext: j.ext,
            maxWidth: 1600,
            allowJpeg: true,
            jpegQuality: 80,
          ),
      ];
      for (var r = 0; r < rounds; r++) {
        final sw = Stopwatch()..start();
        final results = await rust_api.imgProcessBatch(jobs: rustJobs);
        expect(results.length, jobs.length);
        sw.stop();
        if (r > 0) {
          batchBest = batchBest == 0
              ? sw.elapsedMicroseconds / 1000
              : min(batchBest, sw.elapsedMicroseconds / 1000);
        }
      }
      dartRows.add('| Pipeline **ghita_image (Rust, batch/rayon)** | '
          '${_fmt(batchBest)} ms | — |');
      dartRows.add('| **Speedup (Dart/Rust batch)** | '
          '${(dartBest / batchBest).toStringAsFixed(2)}× | — |');
    } else {
      dartRows.add('| Pipeline ghita_image (Rust) | (bỏ qua — chưa bật'
          ' GHITA_IMG_RUST=1) | — |');
    }

    final label = Platform.environment['GHITA_BENCH_LABEL'];
    if (label != null) {
      final file = File('tool/benchmark_results_image.md');
      final existing = file.existsSync() ? file.readAsStringSync() : '';
      final header = existing.isEmpty
          ? '# Benchmark image pipeline — ghita_image (T06)\n\n'
              '> Cùng máy, cùng ảnh giả lập (10 JPEG 2048×1536 + 10 PNG '
              '1400×1050); decode → EXIF bake → resize 1600 → re-encode q80.\n'
              '> Ngày: ${DateTime.now().toIso8601String()}\n\n'
              '| Kịch bản | Thời gian (tốt nhất 5 lần) | Kích thước |\n'
              '|---|---|---|\n'
          : '';
      file.writeAsStringSync(
          '$header${dartRows.join('\n')}\n\n', mode: FileMode.append);
    } else {
      // Suite verbosity gate: printed always so the local run still shows
      // numbers in the test log.
      // ignore: avoid_print
      print('IMG bench (Dart) = ${_fmt(dartBest)} ms; Rust skipped/env');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

int _processedBytes(List<_Job> jobs) {
  var out = 0;
  for (final j in jobs) {
    out += ImageCodec.processDart(j.bytes, j.ext, maxWidth: 1600, allowJpeg: true).bytes.length;
  }
  return out;
}

String _fmt(double ms) => ms >= 1000
    ? '${(ms / 1000).toStringAsFixed(2)} s'
    : '${ms.toStringAsFixed(1)} ms';

/// PSNR (dB) between two PNG/JPEG payloads: decode both to rasters and
/// compare channel-wise MSE over the common region; infinite when identical.
double _psnr(Uint8List encodedA, Uint8List encodedB) {
  final a = img.decodeImage(encodedA);
  final b = img.decodeImage(encodedB);
  if (a == null || b == null) return 0;
  final w = min(a.width, b.width);
  final h = min(a.height, b.height);
  var error = 0.0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final pa = a.getPixel(x, y);
      final pb = b.getPixel(x, y);
      error += pow(pa.r - pb.r, 2) + pow(pa.g - pb.g, 2) + pow(pa.b - pb.b, 2);
    }
  }
  final mse = error / (w * h * 3);
  if (mse == 0) return double.infinity;
  return 10 * log(255 * 255 / mse) / ln10;
}

String _fmtBytes(int bytes) =>
    bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : bytes >= 1024
            ? '${(bytes / 1024).toStringAsFixed(0)} KB'
            : '$bytes B';

class _Job {
  final Uint8List bytes;
  final String ext;
  _Job(this.bytes, this.ext);
}

List<_Job> _loadOrBuildMedia(int perFormat) {
  final dir = Directory('build/img_bench_media');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final jobs = <_Job>[];
  for (var i = 0; i < perFormat; i++) {
    final jpgFile = File('${dir.path}/photo$i.jpg');
    final pngFile = File('${dir.path}/photo$i.png');
    jobs.add(_Job(
      jpgFile.existsSync()
          ? jpgFile.readAsBytesSync()
          : _buildJpg(2048, 1536, i),
      'jpg',
    ));
    jobs.add(_Job(
      pngFile.existsSync()
          ? pngFile.readAsBytesSync()
          : _buildPng(1400, 1050, i),
      'png',
    ));
  }
  return jobs;
}

Uint8List _buildJpg(int w, int h, int seed) {
  final image = _noiseImage(w, h, seed);
  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
  File('build/img_bench_media/photo$seed.jpg')
      .writeAsBytesSync(bytes, flush: true);
  return bytes;
}

Uint8List _buildPng(int w, int h, int seed) {
  final image = _noiseImage(w, h, seed);
  final bytes = Uint8List.fromList(img.encodePng(image));
  File('build/img_bench_media/photo$seed.png')
      .writeAsBytesSync(bytes, flush: true);
  return bytes;
}

/// Photo-like entropy: smooth gradient + seeded per-pixel noise (JPEG and
/// PNG encoders both have real work to do, and the PNG payload is opaque).
img.Image _noiseImage(int w, int h, int seed) {
  final rng = Random(seed);
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final base = 100 + (x * 137 + y * 71) % 120;
      image.setPixelRgb(
        x,
        y,
        (base + rng.nextInt(40) - 20).clamp(0, 255),
        (base + 10 + rng.nextInt(40) - 20).clamp(0, 255),
        (base + 30 + rng.nextInt(40) - 20).clamp(0, 255),
      );
    }
  }
  return image;
}
