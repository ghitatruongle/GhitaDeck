import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../src/rust/api/image.dart' as rust_api;
import 'engine_audit_log.dart';
import 'rust_bridge_init.dart';

/// Engine preference shared across isolates (T06).
///
/// [RustEngineService] keeps [preferredRust] in sync with the Settings choice
/// and calls [markRustReady] once the DLL is loaded in this isolate; the
/// export worker feeds the preference through the job message (providers do
/// not cross isolates).
class ImageEngineConfig {
  ImageEngineConfig._();

  /// T06 measurement-driven default: the N2 batch path (rayon, the shape the
  /// image optimizer uses) measured **8.74×** vs Dart on the same machine and
  /// the sequential loader is still 1.97× faster — see
  /// `tool/benchmark_results_image.md`. The zip module keeps ITS measured
  /// default (Dart) because FRB copy cost killed it on media decks (T02).
  /// The Settings engine switch overrides both components when the user picks
  /// explicitly.
  static bool preferredRust = true;

  static void setPreferredRust(bool value) => preferredRust = value;

  static bool _rustReady = false;

  /// Called by [RustEngineService] after its own successful init — the DLL is
  /// already loaded in this isolate, so [ensureRustReadyOnce] must not retry
  /// (FRB throws "Should not initialize flutter_rust_bridge twice").
  static void markRustReady() {
    _rustReady = true;
  }

  /// Whether the DLL is usable in THIS isolate. The sync [ImageCodec.process]
  /// cannot await an async init, so exports run the Dart path until
  /// [ensureRustReadyOnce] has completed here.
  static bool get rustReady => _rustReady;

  /// Test hook: replaces the real DLL load probe (unit tests have no exe dir).
  static Future<bool> Function()? rustReadyProbe;

  /// Backend tag of a [process] call right now — the image loader folds it
  /// into its processed-cache key (B20: Rust and Dart outputs are not
  /// interchangeable).
  static String get backendTag => (preferredRust && _rustReady) ? 'rust' : 'dart';

  /// Loads the real `ghita_core.dll` once per isolate. Never throws — a
  /// missing/broken DLL simply resolves to "not usable" → Dart backend.
  static Future<bool> ensureRustReadyOnce() async {
    if (_rustReady) return true;
    if (rustReadyProbe != null) return rustReadyProbe!();
    try {
      // B6c: the per-isolate single-flight hub — concurrent init attempts
      // from zip/htmlparse/worker must not initialise FRB twice.
      await RustBridgeInit.ensureReady();
      _rustReady = true;
    } catch (e) {
      // "Should not initialize flutter_rust_bridge twice" means another
      // component already loaded the DLL in this isolate — treat as ready,
      // anything else as unavailable.
      final msg = e.toString().toLowerCase();
      _rustReady = msg.contains('twice');
      if (!_rustReady) {
        debugPrint(
            'ImageEngineConfig: ghita_core.dll unavailable ($e); Dart image');
        await EngineAuditLog.append('engine fallback', 'image: $e');
      }
    }
    return _rustReady;
  }
}

/// Result of one processed image — mirrors the Rust `ImageOpResult`.
class ImageCodecResult {
  final Uint8List bytes;
  final String ext; // png | jpg | gif (output)
  final int width;
  final int height;
  /// Whether the output bytes differ from the input (passthrough == false).
  final bool changed;
  /// Whether the image was downscaled (drives the savings tally).
  final bool resized;

  const ImageCodecResult({
    required this.bytes,
    required this.ext,
    required this.width,
    required this.height,
    required this.changed,
    required this.resized,
  });
}

/// Image processing backend with automatic fallback (T06).
///
/// Uses the Rust `ghita_image` module when the user prefers it and the DLL is
/// ready in this isolate; any Rust failure falls back to the Dart `image`
/// implementation so the export pipeline never breaks. Both backends implement
/// the same deterministic pipeline: EXIF baked, wide images downscaled, large
/// opaque PNGs possibly re-encoded as JPEG, GIF/JPEG passthroughs unchanged.
class ImageCodec {
  ImageCodec._();

  /// Which backend last produced a result ('rust' | 'dart') — used by the
  /// integration probe to prove the DLL path was really exercised.
  static String lastBackend = '';

  static ImageCodecResult process(
    Uint8List bytes,
    String ext, {
    int? maxWidth,
    bool allowJpeg = false,
    int jpegQuality = 80,
  }) {
    if (ImageEngineConfig.preferredRust && ImageEngineConfig.rustReady) {
      try {
        final r = rust_api.imgProcess(
          job: rust_api.ImageJob(
            bytes: bytes,
            ext: ext,
            maxWidth: maxWidth ?? 0,
            allowJpeg: allowJpeg,
            jpegQuality: jpegQuality,
          ),
        );
        lastBackend = 'rust';
        return ImageCodecResult(
          bytes: r.bytes,
          ext: r.ext,
          width: r.width,
          height: r.height,
          changed: r.changed,
          resized: r.resized,
        );
      } catch (e) {
        // Decode/encode failures are per-image errors: fall back to Dart —
        // the Dart path records the warning the same way.
        debugPrint('ImageCodec: Rust backend failed ($e); using Dart');
      }
    }
    lastBackend = 'dart';
    return processDart(
      bytes,
      ext,
      maxWidth: maxWidth,
      allowJpeg: allowJpeg,
      jpegQuality: jpegQuality,
    );
  }

  /// The reference implementation (moved out of [HtmlImageLoader] so both
  /// engines share one Dart fallback). Mirrors `rust/src/api/image.rs`.
  static ImageCodecResult processDart(
    Uint8List bytes,
    String ext, {
    int? maxWidth,
    bool allowJpeg = false,
    int jpegQuality = 80,
  }) {
    img.Image decoded;
    try {
      final result = img.decodeImage(bytes);
      if (result == null) {
        throw const FormatException('undecodable image');
      }
      decoded = result;
    } catch (_) {
      // Some decoders throw on corrupted payloads instead of returning null;
      // the loader records the per-image warning.
      throw const FormatException('undecodable image');
    }

    // package:image's JPEG decoder bakes EXIF orientation during decode
    // (verified empirically: EXIF-6 4×8 decodes to 8×4 with orientation
    // already stripped), so JPEG must NOT be rotated again. PNG/GIF need the
    // manual read + bake; the Rust module does the same for every format
    // because the image crate does NOT bake on decode.
    final orientation = readExifOrientation(bytes);
    final needsRotation = ext != 'jpg' && orientation != 1;
    // A JPEG that carried an orientation must still be re-encoded: raw EXIF
    // bytes would be un-baked for the deck, and viewers render raw pixels
    // (B16 — the Rust backend re-encodes here too, so both agree).
    final mustBake = ext == 'jpg' && orientation != 1;

    final resized = maxWidth != null && maxWidth > 0 && decoded.width > maxWidth;
    var out = decoded;
    var outExt = ext;
    if (needsRotation) out = applyExifOrientation(out, orientation);
    if (resized) {
      out = img.copyResize(out, width: maxWidth);
      outExt = 'png';
    }
    if (ext == 'gif' && !resized && !needsRotation) {
      // Keep GIF animation intact (encodeGif would flatten it).
      return ImageCodecResult(
        bytes: bytes,
        ext: 'gif',
        width: decoded.width,
        height: decoded.height,
        changed: false,
        resized: false,
      );
    }

    const jpegThreshold = 512;
    final (w, h) = (out.width, out.height);
    if (outExt == 'png' &&
        allowJpeg &&
        !out.hasAlpha &&
        out.width >= jpegThreshold) {
      final outBytes = Uint8List.fromList(img.encodeJpg(out, quality: jpegQuality));
      return ImageCodecResult(
        bytes: outBytes,
        ext: 'jpg',
        width: w,
        height: h,
        changed: true,
        resized: resized,
      );
    }
    if (outExt == 'png') {
      final outBytes = Uint8List.fromList(img.encodePng(out));
      return ImageCodecResult(
        bytes: outBytes,
        ext: 'png',
        width: w,
        height: h,
        changed: true,
        resized: resized,
      );
    }
    if (resized || needsRotation || mustBake) {
      final outBytes = Uint8List.fromList(
          img.encodeJpg(out, quality: jpegQuality.clamp(60, 95)));
      return ImageCodecResult(
        bytes: outBytes,
        ext: 'jpg',
        width: w,
        height: h,
        changed: true,
        resized: resized,
      );
    }
    // JPEG passthrough (bytes unchanged).
    return ImageCodecResult(
      bytes: bytes,
      ext: 'jpg',
      width: decoded.width,
      height: decoded.height,
      changed: false,
      resized: false,
    );
  }

  /// SHA-256 of arbitrary bytes — media dedupe / cache keys (T06 phase 9).
  /// Uses the Rust module when ready; falls back to a Dart SHA-256.
  static String sha256(Uint8List bytes) {
    if (ImageEngineConfig.preferredRust && ImageEngineConfig.rustReady) {
      try {
        return rust_api.imgSha256(bytes: bytes);
      } catch (_) {
        // fall through to Dart
      }
    }
    return _sha256Hex(bytes);
  }

  static String _sha256Hex(Uint8List bytes) =>
      crypto.sha256.convert(bytes).toString();

  // ---- EXIF orientation (read + bake) — moved from HtmlImageLoader ---------

  /// EXIF orientation tag (0x0112) from a JPEG APP1 `Exif\0\0` segment or a
  /// PNG `eXIf` chunk; 1 (normal) when absent or unreadable.
  static int readExifOrientation(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return _orientationFromJpeg(bytes);
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return _orientationFromPng(bytes);
    }
    return 1;
  }

  static int _orientationFromJpeg(Uint8List bytes) {
    var i = 2;
    while (i + 4 <= bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2; // SOI / TEM / RSTn — no length field
        continue;
      }
      final length = (bytes[i + 2] << 8) | bytes[i + 3];
      if (length < 2 || i + 2 + length > bytes.length) break;
      if (marker == 0xE1) {
        final segment = bytes.sublist(i + 4, i + 2 + length);
        if (segment.length >= 6 &&
            String.fromCharCodes(segment.sublist(0, 6)) == 'Exif\x00\x00') {
          return _orientationFromTiff(segment.sublist(6));
        }
      }
      i += 2 + length;
    }
    return 1;
  }

  static int _orientationFromPng(Uint8List bytes) {
    var i = 8;
    while (i + 12 <= bytes.length) {
      final length = ByteData.sublistView(bytes).getUint32(i);
      if (String.fromCharCodes(bytes.sublist(i + 4, i + 8)) == 'eXIf') {
        if (i + 8 + length > bytes.length) return 1;
        return _orientationFromTiff(bytes.sublist(i + 8, i + 8 + length));
      }
      i += 12 + length;
    }
    return 1;
  }

  static int _orientationFromTiff(List<int> data) {
    if (data.length < 8) return 1;
    final little = data[0] == 0x49 && data[1] == 0x49;
    final magic = little
        ? (data[2] | (data[3] << 8))
        : ((data[2] << 8) | data[3]);
    if (magic != 42) return 1;
    int u16(int off) => little
        ? (data[off] | (data[off + 1] << 8))
        : ((data[off] << 8) | data[off + 1]);
    int u32(int off) => little
        ? (data[off] |
            (data[off + 1] << 8) |
            (data[off + 2] << 16) |
            (data[off + 3] << 24))
        : ((data[off] << 24) |
            (data[off + 1] << 16) |
            (data[off + 2] << 8) |
            data[off + 3]);
    final ifdOffset = u32(4);
    if (ifdOffset + 2 > data.length) return 1;
    final count = u16(ifdOffset);
    for (var e = 0; e < count; e++) {
      final entry = ifdOffset + 2 + e * 12;
      if (entry + 12 > data.length) break;
      if (u16(entry) == 0x0112) {
        return little
            ? (data[entry + 8] | (data[entry + 9] << 8))
            : ((data[entry + 8] << 8) | data[entry + 9]);
      }
    }
    return 1;
  }

  static img.Image applyExifOrientation(img.Image image, int orientation) {
    switch (orientation) {
      case 2:
        return img.flipHorizontal(image);
      case 3:
        return img.flip(image, direction: img.FlipDirection.both);
      case 4:
        return img.flipHorizontal(img.copyRotate(image, angle: 180));
      case 5:
        return img.flipHorizontal(img.copyRotate(image, angle: 90));
      case 6:
        return img.copyRotate(image, angle: 90);
      case 7:
        return img.flipHorizontal(img.copyRotate(image, angle: -90));
      case 8:
        return img.copyRotate(image, angle: -90);
      default:
        return image;
    }
  }
}
