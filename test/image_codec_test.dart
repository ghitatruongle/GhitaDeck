import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/image_codec.dart';
import 'package:image/image.dart' as img;

/// T06 — ghita_image contract tests.
///
/// Both backends (Dart reference and the Rust `ghita_image` module when the
/// DLL is available) must implement the same pipeline. The engine-selection
/// tests here never initialize the real DLL (unit tests have no exe dir), so
/// the Rust side is validated in `integration_test/rust_engine_probe_test.dart`
/// (real DLL round-trips) and by the pixel-diff benchmark in
/// `tool/image_benchmark_test.dart`.
void main() {
  setUp(() {
    // Static engine state must not leak between tests (combo runs).
    ImageEngineConfig.setPreferredRust(false);
    ImageEngineConfig.rustReadyProbe = null;
  });

  group('ImageCodec.processDart (reference implementation)', () {
    test('opaque PNG larger than 512 px converts to JPEG at quality', () {
      final png = _png(600, 400, alpha: false);
      final result = ImageCodec.processDart(
        png,
        'png',
        allowJpeg: true,
        jpegQuality: 80,
      );
      expect(result.ext, 'jpg');
      expect(result.changed, isTrue);
      expect(result.width, 600);
      expect(result.height, 400);
    });

    test('transparent PNG stays PNG (alpha preserved)', () {
      final png = _png(600, 400, alpha: true);
      final result = ImageCodec.processDart(
        png,
        'png',
        allowJpeg: true,
        jpegQuality: 80,
      );
      expect(result.ext, 'png', reason: 'alpha images must keep PNG');
      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.hasAlpha, isTrue);
    });

    test('wide images are downscaled and re-encoded', () {
      final png = _png(2000, 1000, alpha: false);
      final result = ImageCodec.processDart(
        png,
        'png',
        maxWidth: 1200,
        allowJpeg: false,
      );
      expect(result.ext, 'png');
      expect(result.resized, isTrue);
      expect(result.width, 1200);
      expect(result.height, 600);
    });

    test('JPEG passthrough keeps the original bytes', () {
      final jpg = _jpg(400, 300);
      final result = ImageCodec.processDart(jpg, 'jpg');
      expect(result.changed, isFalse);
      expect(result.bytes, jpg);
    });

    test('GIF passthrough keeps animation-capable bytes', () {
      final gif = _gif(64, 64);
      final result = ImageCodec.processDart(gif, 'gif');
      expect(result.changed, isFalse);
      expect(result.ext, 'gif');
    });

    test('corrupt bytes raise FormatException (loader records a warning)',
        () {
      expect(
        () => ImageCodec.processDart(Uint8List.fromList([1, 2, 3, 4]), 'png'),
        throwsFormatException,
      );
    });

    test('EXIF orientation 6 in a PNG eXIf chunk rotates the pixels', () {
      final png = _pngWithExifRotation(1, 2, 6);
      final result = ImageCodec.processDart(png, 'png');
      // 1×2 rotated 90° → 2×1.
      expect(result.width, 2);
      expect(result.height, 1);
    });
  });

  group('ImageCodec engine selection', () {
    test('Dart backend used when Rust is not preferred', () {
      ImageEngineConfig.setPreferredRust(false);
      final jpg = _jpg(400, 300);
      final result = ImageCodec.process(jpg, 'jpg');
      expect(ImageCodec.lastBackend, 'dart');
      expect(result.changed, isFalse);
    });

    test('Dart backend used when Rust is preferred but not ready', () {
      ImageEngineConfig.setPreferredRust(true);
      ImageEngineConfig.rustReadyProbe = () async => false;
      final jpg = _jpg(400, 300);
      // ensureRustReadyOnce is not called by the sync path — rustReady stays
      // false → Dart.
      expect(ImageCodec.process(jpg, 'jpg').changed, isFalse);
      expect(ImageCodec.lastBackend, 'dart');
      ImageEngineConfig.setPreferredRust(false);
    });

    test('sha256 matches package:crypto on the Dart path', () {
      final bytes = Uint8List.fromList(List.generate(256, (i) => i));
      expect(ImageCodec.sha256(bytes), crypto.sha256.convert(bytes).toString());
    });
  });
}

Uint8List _png(int w, int h, {required bool alpha}) {
  final image = img.Image(
      width: w, height: h, numChannels: alpha ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = (x * 3 + y * 7) % 256;
      if (alpha) {
        image.setPixelRgba(x, y, v, v + 10, v + 40, 255);
      } else {
        image.setPixelRgb(x, y, v, v + 10, v + 40);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _jpg(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (x * 5) % 256, (y * 7) % 256, (x + y) % 256);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

Uint8List _gif(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (x * 9) % 256, (y * 11) % 256, (x * y) % 256);
    }
  }
  // GIF encoder compresses to palette; a clean decode round-trip is enough.
  return Uint8List.fromList(img.encodeGif(image));
}

/// PNG with a hand-crafted eXIf chunk carrying [orientation] (TIFF IFD0 tag
/// 0x0112), inserted right after IHDR.
Uint8List _pngWithExifRotation(int w, int h, int orientation) {
  final png = _png(w, h, alpha: false);

  final tiff = BytesBuilder()
    ..add([0x49, 0x49, 0x2A, 0x00]) // little-endian TIFF
    ..add([8, 0, 0, 0]) // IFD0 offset
    ..add([1, 0]) // one entry
    ..add([0x12, 0x01]) // tag 0x0112
    ..add([3, 0]) // SHORT
    ..add([1, 0, 0, 0]) // count
    ..add([orientation, 0, 0, 0]) // inline value
    ..add([0, 0, 0, 0]); // next IFD

  final chunk = BytesBuilder()
    ..add(_be32(tiff.length))
    ..add('eXIf'.codeUnits)
    ..add(tiff.takeBytes())
    ..add([0, 0, 0, 0]); // CRC ignored by our length-based parser

  // Preserve IHDR (offset 8, length 12+ihdr_len) and insert before IDAT.
  final ihdrLen = ByteData.sublistView(png).getUint32(8);
  final ihdrEnd = 8 + 12 + ihdrLen;
  final out = BytesBuilder()
    ..add(png.sublist(0, ihdrEnd))
    ..add(chunk.takeBytes())
    ..add(png.sublist(ihdrEnd));
  return out.takeBytes();
}

Uint8List _be32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v);
