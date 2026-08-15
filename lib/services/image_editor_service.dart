import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

/// Image Editor Service — v1.2.0
/// Handles image picking, editing (crop, resize, rotate, flip, filters), and base64 encoding.
class ImageEditorService {
  /// Pick an image file and return base64 data URI.
  static Future<String?> pickImageAsBase64() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        var ext = result.files.single.extension ?? 'png';
        // 'jpg' is not a registered MIME type — downstream renderers can
        // reject 'data:image/jpg;base64,...'. Map to 'jpeg'.
        if (ext.toLowerCase() == 'jpg') ext = 'jpeg';
        return 'data:image/$ext;base64,$base64Str';
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  /// Resize an image to the given width/height (maintains aspect ratio if one is 0).
  static Future<Uint8List?> resizeImage(Uint8List bytes, {int width = 0, int height = 0}) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(
        image,
        width: width > 0 ? width : (height > 0 ? (image.width * height / image.height).round() : image.width),
        height: height > 0 ? height : (width > 0 ? (image.height * width / image.width).round() : image.height),
        interpolation: img.Interpolation.linear,
      );
      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }

  /// Rotate image by 90/180/270 degrees.
  static Future<Uint8List?> rotateImage(Uint8List bytes, {int degrees = 90}) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final rotated = switch (degrees) {
        90 => img.copyRotate(image, angle: 90),
        180 => img.copyRotate(image, angle: 180),
        270 => img.copyRotate(image, angle: 270),
        _ => image,
      };
      return Uint8List.fromList(img.encodePng(rotated));
    } catch (e) {
      debugPrint('Error rotating image: $e');
      return null;
    }
  }

  /// Flip image horizontally or vertically.
  static Future<Uint8List?> flipImage(Uint8List bytes, {bool horizontal = true}) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final flipped = horizontal ? img.copyFlip(image, direction: img.FlipDirection.horizontal) : img.copyFlip(image, direction: img.FlipDirection.vertical);
      return Uint8List.fromList(img.encodePng(flipped));
    } catch (e) {
      debugPrint('Error flipping image: $e');
      return null;
    }
  }

  /// Apply brightness/contrast adjustment.
  static Future<Uint8List?> adjustImage(Uint8List bytes, {double brightness = 0, double contrast = 0}) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      var adjusted = image;
      if (brightness != 0) {
        // image v4: brightness is a multiplier (1.0 = unchanged), not a delta
        adjusted = img.adjustColor(adjusted, brightness: 1.0 + brightness / 100);
      }
      if (contrast != 0) {
        adjusted = img.adjustColor(adjusted, contrast: 1.0 + contrast / 100);
      }
      return Uint8List.fromList(img.encodePng(adjusted));
    } catch (e) {
      debugPrint('Error adjusting image: $e');
      return null;
    }
  }

  // ---- Track 22: Crop & background removal ------------------------------

  /// Crop an image to the given rectangle (fractional 0..1 of the source).
  /// Original quality is preserved (PNG re-encode, no downscale).
  static Future<Uint8List?> cropImage(
    Uint8List bytes, {
    required double x,
    required double y,
    required double w,
    required double h,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final px = (x * image.width).round().clamp(0, image.width);
      final py = (y * image.height).round().clamp(0, image.height);
      // Clamp so `lower <= upper` always holds: a crop rect flush against
      // the right/bottom edge makes `image.width - px` zero, and Dart's
      // `num.clamp` throws ArgumentError when lowerLimit > upperLimit.
      final pw = (w * image.width)
          .round()
          .clamp(1, math.max(1, image.width - px).toInt());
      final ph = (h * image.height)
          .round()
          .clamp(1, math.max(1, image.height - py).toInt());
      final cropped = img.copyCrop(image, x: px, y: py, width: pw, height: ph);
      return Uint8List.fromList(img.encodePng(cropped));
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  /// Crop to a shape: applies a soft mask (rect/oval/rounded rect/triangle/
  /// diamond/heart) by making the outside fully transparent (PNG alpha).
  static Future<Uint8List?> cropToShape(
    Uint8List bytes, {
    String shape = 'rect',
    double radiusRatio = 0.1,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final out = img.Image(width: image.width, height: image.height, numChannels: 4);
      img.compositeImage(out, image);
      final w = image.width, h = image.height;
      bool inside(int px, int py) {
        switch (shape) {
          case 'oval':
            final nx = (px + 0.5 - w / 2) / (w / 2);
            final ny = (py + 0.5 - h / 2) / (h / 2);
            return nx * nx + ny * ny <= 1.0;
          case 'triangle':
            // Isosceles triangle pointing up.
            final nx = px / w, ny = py / h;
            return ny <= nx && ny <= (1 - nx) && ny >= 0;
          case 'diamond':
            final nx = (px + 0.5) / w * 2 - 1;
            final ny = (py + 0.5) / h * 2 - 1;
            return nx.abs() + ny.abs() <= 1.0;
          case 'heart':
            final nx = (px + 0.5) / w * 2 - 1;
            final ny = (py + 0.5) / h * 2 - 1;
            final x = nx * 1.2, y = ny * 1.4;
            final f = (x * x + y * y - 1);
            return f * f * f - x * x * y * y * y <= 0;
          case 'rounded':
            final r = (radiusRatio * w).round().clamp(1, w ~/ 2);
            if (px < r && py < r) {
              return (px - r) * (px - r) + (py - r) * (py - r) <= r * r;
            }
            if (px > w - r && py < r) {
              return (px - (w - r)) * (px - (w - r)) + (py - r) * (py - r) <=
                  r * r;
            }
            if (px < r && py > h - r) {
              return (px - r) * (px - r) + (py - (h - r)) * (py - (h - r)) <=
                  r * r;
            }
            if (px > w - r && py > h - r) {
              return (px - (w - r)) * (px - (w - r)) +
                      (py - (h - r)) * (py - (h - r)) <=
                  r * r;
            }
            return true;
          default:
            return true; // rect
        }
      }

      for (var py = 0; py < h; py++) {
        for (var px = 0; px < w; px++) {
          if (!inside(px, py)) {
            out.setPixelRgba(px, py, 0, 0, 0, 0);
          }
        }
      }
      return Uint8List.fromList(img.encodePng(out));
    } catch (e) {
      debugPrint('Error crop to shape: $e');
      return null;
    }
  }

  /// Remove the background around a seed point with a flood-fill that
  /// tolerates small colour differences (local algorithm, no network).
  /// [tolerance] 0..1 (fraction of the colour distance). Returns a PNG with
  /// the removed region fully transparent.
  static Future<Uint8List?> removeBackground(
    Uint8List bytes, {
    required double seedX,
    required double seedY,
    double tolerance = 0.25,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final w = image.width, h = image.height;
      final sx = (seedX * w).round().clamp(0, w - 1);
      final sy = (seedY * h).round().clamp(0, h - 1);
      final out = img.Image(width: w, height: h, numChannels: 4);
      img.compositeImage(out, image);

      final seed = image.getPixel(sx, sy);
      final sr = seed.r.toDouble(), sg = seed.g.toDouble(), sb = seed.b.toDouble();
      // Colour-distance threshold: tolerance fraction of the max possible
      // distance (sqrt(3) in 0..255 space → ~441).
      final maxDist = math.sqrt(3 * 255 * 255);
      final threshold = (tolerance * maxDist).clamp(0.0, maxDist);
      final visited = Uint8List(w * h);
      final queue = <int>[];
      void push(int x, int y) {
        if (x < 0 || y < 0 || x >= w || y >= h) return;
        final idx = y * w + x;
        if (visited[idx] == 1) return;
        visited[idx] = 1;
        queue.add(idx);
      }

      push(sx, sy);
      while (queue.isNotEmpty) {
        final idx = queue.removeLast();
        final x = idx % w, y = idx ~/ w;
        final p = image.getPixel(x, y);
        final d = math.sqrt(
            (p.r - sr) * (p.r - sr) +
            (p.g - sg) * (p.g - sg) +
            (p.b - sb) * (p.b - sb));
        if (d > threshold) continue;
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        push(x + 1, y);
        push(x - 1, y);
        push(x, y + 1);
        push(x, y - 1);
      }
      return Uint8List.fromList(img.encodePng(out));
    } catch (e) {
      debugPrint('Error removing background: $e');
      return null;
    }
  }

  /// Brush eraser/restore: set a disc around (cx, cy) to transparent (eraser)
  /// or restore the original pixel (add). Returns the edited bytes.
  static Future<Uint8List?> brushEdit(
    Uint8List bytes, {
    required Uint8List original,
    required double cx,
    required double cy,
    double radius = 0.05,
    bool erase = true,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      final src = img.decodeImage(original);
      if (image == null || src == null) return null;
      final w = image.width, h = image.height;
      final px = (cx * w).round().clamp(0, w - 1);
      final py = (cy * h).round().clamp(0, h - 1);
      final minDim = math.min(w, h);
      final r = ((radius * minDim).round().clamp(1, minDim)).toInt();
      final r2 = r * r;
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx * dx + dy * dy > r2) continue;
          final x = px + dx, y = py + dy;
          if (x < 0 || y < 0 || x >= w || y >= h) continue;
          if (erase) {
            image.setPixelRgba(x, y, 0, 0, 0, 0);
          } else {
            final p = src.getPixel(x, y);
            image.setPixelRgba(x, y, p.r, p.g, p.b, p.a);
          }
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      debugPrint('Error brush editing: $e');
      return null;
    }
  }

  // ---- Track 23: Corrections & artistic effects -------------------------

  /// Corrections: saturation (-1..1), tone/temperature (-1..1), recolor
  /// (duotone between two colours), sharpness (0..2 kernel strength).
  static Future<Uint8List?> correctImage(
    Uint8List bytes, {
    double saturation = 0,
    double tone = 0,
    double sharpness = 0,
    String? duotoneA,
    String? duotoneB,
  }) async {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) return null;
      if (saturation != 0) {
        image = img.adjustColor(image, saturation: 1.0 + saturation);
      }
      if (tone != 0) {
        image = _applyTone(image, tone);
      }
      if (sharpness > 0) {
        image = img.convolution(image,
            filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
            div: 1,
            offset: 0,
            amount: sharpness);
      }
      if (duotoneA != null) {
        image = _applyDuotone(image, duotoneA, duotoneB ?? '#000000');
      }
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      debugPrint('Error correcting image: $e');
      return null;
    }
  }

  /// Artistic effects: blur / mosaic / pencil / oil / film.
  static Future<Uint8List?> artisticEffect(
    Uint8List bytes, {
    required String effect,
    double intensity = 1.0,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final img.Image out;
      switch (effect) {
        case 'blur':
          out = img.gaussianBlur(image, radius: (2 + 6 * intensity).round());
          break;
        case 'mosaic':
          out = _mosaic(image, (8 + 40 * intensity).round());
          break;
        case 'pencil':
          out = _pencilSketch(image);
          break;
        case 'oil':
          out = _oilPaint(image, (2 + 6 * intensity).round());
          break;
        case 'film':
          out = _film(image);
          break;
        default:
          return bytes;
      }
      return Uint8List.fromList(img.encodePng(out));
    } catch (e) {
      debugPrint('Error artistic effect: $e');
      return null;
    }
  }

  /// Six quick presets (Track 23, P7): B&W, Vintage, Cool, Warm, Soft, Vivid.
  static Future<Uint8List?> presetImage(Uint8List bytes, String preset) async {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) return null;
      switch (preset) {
        case 'bw':
          image = img.grayscale(image);
          break;
        case 'vintage':
          image = img.adjustColor(image,
              saturation: 0.6, brightness: 1.04, contrast: 0.95);
          image = _applyTone(image, -0.12);
          break;
        case 'cool':
          image = _applyTone(image, 0.18);
          break;
        case 'warm':
          image = _applyTone(image, -0.18);
          break;
        case 'soft':
          image = img.adjustColor(image,
              brightness: 1.02, contrast: 0.9, saturation: 0.85);
          image = img.gaussianBlur(image, radius: 1);
          break;
        case 'vivid':
          image = img.adjustColor(image,
              saturation: 1.35, contrast: 1.12);
          break;
        default:
          return bytes;
      }
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      debugPrint('Error applying preset: $e');
      return null;
    }
  }

  // ---- Track 23 internals -----------------------------------------------

  static img.Image _applyTone(img.Image src, double tone) {
    // Simple temperature: shift R/B by `tone` (negative = warmer).
    final out = img.Image.from(src);
    for (final p in out) {
      final r = (p.r + (tone < 0 ? -tone * 60 : 0)).round().clamp(0, 255);
      final g = p.g;
      final b = (p.b + (tone > 0 ? tone * 60 : 0)).round().clamp(0, 255);
      out.setPixelRgba(p.x, p.y, r, g, b, p.a);
    }
    return out;
  }

  static img.Image _applyDuotone(img.Image src, String aHex, String bHex) {
    final a = _hexToRgb(aHex);
    final b = _hexToRgb(bHex);
    final out = img.Image.from(src);
    for (final p in out) {
      final g = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114) / 255;
      final r = (a.$1 + (b.$1 - a.$1) * g).round();
      final gg = (a.$2 + (b.$2 - a.$2) * g).round();
      final bb = (a.$3 + (b.$3 - a.$3) * g).round();
      out.setPixelRgba(p.x, p.y, r, gg, bb, p.a);
    }
    return out;
  }

  static img.Image _mosaic(img.Image src, int block) {
    final out = img.Image.from(src);
    block = block.clamp(2, 256);
    for (var by = 0; by < src.height; by += block) {
      for (var bx = 0; bx < src.width; bx += block) {
        var rs = 0, gs = 0, bs = 0, n = 0;
        final yMax = math.min(by + block, src.height).toInt();
        final xMax = math.min(bx + block, src.width).toInt();
        for (var y = by; y < yMax; y++) {
          for (var x = bx; x < xMax; x++) {
            final p = src.getPixel(x, y);
            rs += p.r.toInt(); gs += p.g.toInt(); bs += p.b.toInt(); n++;
          }
        }
        if (n == 0) continue;
        final r = rs ~/ n, g = gs ~/ n, b = bs ~/ n;
        for (var y = by; y < yMax; y++) {
          for (var x = bx; x < xMax; x++) {
            out.setPixelRgba(x, y, r, g, b, src.getPixel(x, y).a);
          }
        }
      }
    }
    return out;
  }

  static img.Image _pencilSketch(img.Image src) {
    final gray = img.grayscale(src);
    final inverted = img.invert(gray);
    final blurred = img.gaussianBlur(inverted, radius: 4);
    final out = img.Image.from(gray);
    for (final p in out) {
      final a = p.r / 255;
      final b = blurred.getPixel(p.x, p.y).r / 255;
      // Dodge: out = a / (1 - b), clamped.
      final denom = (1 - b).clamp(0.05, 1.0);
      final v = (a / denom * 255).round().clamp(0, 255);
      out.setPixelRgba(p.x, p.y, v, v, v, p.a);
    }
    return out;
  }

  static img.Image _oilPaint(img.Image src, int radius) {
    final out = img.Image.from(src);
    final buckets = List<int>.filled(256, 0);
    final rs = List<int>.filled(256, 0);
    final gs = List<int>.filled(256, 0);
    final bs = List<int>.filled(256, 0);
    // Only reset the luminance buckets a window actually touched, instead
    // of `fillRange`-ing all 256 × 4 arrays for every pixel — on a 1MP
    // image with radius 8 that is ~10^9 wasted stores.
    final touched = <int>[];
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        touched.clear();
        for (var dy = -radius; dy <= radius; dy++) {
          for (var dx = -radius; dx <= radius; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= src.width || ny >= src.height) {
              continue;
            }
            final p = src.getPixel(nx, ny);
            final lum = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114).round();
            if (buckets[lum] == 0) touched.add(lum);
            buckets[lum]++;
            rs[lum] += p.r.toInt(); gs[lum] += p.g.toInt(); bs[lum] += p.b.toInt();
          }
        }
        var best = 0;
        for (final t in touched) {
          if (buckets[t] > buckets[best]) best = t;
        }
        if (buckets[best] > 0) {
          out.setPixelRgba(x, y,
              rs[best] ~/ buckets[best],
              gs[best] ~/ buckets[best],
              bs[best] ~/ buckets[best],
              src.getPixel(x, y).a);
        }
        for (final t in touched) {
          buckets[t] = 0;
          rs[t] = 0;
          gs[t] = 0;
          bs[t] = 0;
        }
      }
    }
    return out;
  }

  static img.Image _film(img.Image src) {
    final out = img.Image.from(src);
    for (final p in out) {
      // Strong contrast + slight green tint + vignette-ish darkening.
      final f = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114);
      final c = ((f - 128) * 1.18 + 128).round().clamp(0, 255);
      final r = (c * 0.95).round().clamp(0, 255);
      final g = (c * 1.06).round().clamp(0, 255);
      final b = (c * 0.88).round().clamp(0, 255);
      out.setPixelRgba(p.x, p.y, r, g, b, p.a);
    }
    return out;
  }

  static (int, int, int) _hexToRgb(String hex) {
    final clean = hex.replaceFirst('#', '');
    final v = int.tryParse(clean.length >= 6 ? clean.substring(0, 6) : '000000',
        radix: 16);
    if (v == null) return (0, 0, 0);
    return ((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff);
  }

  /// Convert edited bytes to base64 data URI.
  static String toDataUri(Uint8List bytes, {String format = 'png'}) {
    final base64Str = base64Encode(bytes);
    return 'data:image/$format;base64,$base64Str';
  }

  /// Generate HTML <img> tag from a data URI.
  static String toImgTag(String dataUri, {String alt = 'Image', String maxWidth = '100%'}) {
    return '<img src="$dataUri" style="max-width: $maxWidth; height: auto; border-radius: 8px;" alt="$alt" />';
  }
}
