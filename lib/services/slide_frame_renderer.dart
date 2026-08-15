/// Slide frame renderer (Track 42, FEAT 68 + Track 41 pipeline).
///
/// Renders a slide — exactly as stored in the slide map (`bgColor`,
/// `htmlContent`, `visualElements`) — into a raster [img.Image] in pure
/// Dart, so slide→PNG/JPEG/WebP export and the video/GIF pipeline run in CI
/// and on machines without WebView2.
///
/// The renderer reuses the same block parser as the PPTX/PDF exporters
/// ([PPTGenerator.parseHtmlContentFull]) so text/list/table/image geometry
/// matches the other formats. Text glyphs use the bundled bitmap fonts
/// (ASCII range; non-ASCII glyphs render as a visible box). The Windows app
/// prefers the higher-fidelity PDF→raster path ([SlidePdfRasterizer]) when
/// available — this service is the deterministic fallback and the engine
/// behind the automated tests.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../models/drawn_shape.dart';
import '../models/free_shape.dart';
import '../models/icon_item.dart';
import 'html_image_loader.dart';
import 'ppt_generator.dart';

/// Result of rasterizing one slide.
class RenderedFrame {
  final img.Image image;
  final int slideIndex;

  const RenderedFrame({required this.image, required this.slideIndex});

  /// PNG bytes of the frame.
  Uint8List get pngBytes => Uint8List.fromList(img.encodePng(image));
}

/// Geometry constants mirroring the PDF/PPTX vertical flow layout.
class SlideFrameRenderer {
  SlideFrameRenderer._();

  /// Margin (fraction of the width) around the content flow — matches the
  /// PDF exporter's content inset so slides look alike across formats.
  static const double _marginFrac = 0.06;

  static final img.BitmapFont _fontTitle = img.arial48;
  static final img.BitmapFont _fontBody = img.arial24;
  static final img.BitmapFont _fontSmall = img.arial14;

  static final RegExp _bgColorRe = RegExp(
      r"""data-bg-color=["']([^"']+)["']""", caseSensitive: false);
  static final RegExp _wsRe = RegExp(r'\s+');

  /// Render [slide] at [width]×[height] px.
  ///
  /// [transparentBackground] skips the background fill (PNG alpha export).
  /// Returns null when the slide cannot be parsed at all.
  static RenderedFrame? renderSlide(
    Map<String, dynamic> slide, {
    required int width,
    required int height,
    bool transparentBackground = false,
  }) {
    if (width <= 0 || height <= 0) return null;
    final image = img.Image(width: width, height: height, numChannels: 4);

    final html = (slide['htmlContent'] ?? '').toString();
    final bgHex = _slideBgHex(slide, html);
    if (!transparentBackground && bgHex != null) {
      img.fill(image, color: _color(bgHex, 255));
    } else if (!transparentBackground) {
      img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
    }

    final blocks = PPTGenerator.parseHtmlContentFull(html);
    _drawBlocks(image, blocks, width, height);

    _drawVisualElements(image, slide, width, height);
    return RenderedFrame(image: image, slideIndex: 0);
  }

  // ---- Background --------------------------------------------------------

  /// Resolve the slide background hex: typed `bgColor` wins, then the HTML
  /// `data-bg-color` attribute (same precedence as the PPTX exporter).
  static String? _slideBgHex(Map<String, dynamic> slide, String html) {
    final typed = PPTGenerator.cssColorToHex((slide['bgColor'] ?? '').toString());
    if (typed != null) return typed;
    final match = _bgColorRe.firstMatch(html);
    if (match == null) return null;
    return PPTGenerator.cssColorToHex(match.group(1)!);
  }

  static img.ColorRgba8 _color(String hex, int alpha) {
    final clean = hex.replaceAll('#', '');
    final v = int.tryParse(
            clean.length >= 6 ? clean.substring(0, 6) : 'FFFFFF',
            radix: 16) ??
        0xFFFFFF;
    return img.ColorRgba8((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, alpha);
  }

  // ---- Blocks (text/list/table/image/…) ----------------------------------

  static void _drawBlocks(
      img.Image image, List<Map<String, dynamic>> blocks, int w, int h) {
    var y = (h * 0.06).round();
    final margin = (w * _marginFrac).round();
    final contentW = w - 2 * margin;
    for (final block in blocks) {
      final type = block['type'] as String? ?? 'text';
      switch (type) {
        case 'text':
          y += _drawParagraphs(
              image,
              (block['paragraphs'] as List? ?? const [])
                  .cast<Map<String, String>>(),
              margin,
              y,
              contentW,
              h,
              title: false);
          y += (h * 0.02).round();
        case 'list':
          final items = (block['items'] as List? ?? const [])
              .cast<Map<String, String>>();
          final ordered = block['ordered'] == true;
          for (var i = 0; i < items.length; i++) {
            final runs = _groupRuns(items, i);
            final hh = _drawParagraphs(image, runs, margin, y, contentW, h,
                title: false,
                bullet: ordered ? '${i + 1}. ' : '\u2022 ');
            y += hh + (h * 0.012).round();
          }
        case 'table':
          y += _drawTable(image, block, margin, y, contentW, h);
          y += (h * 0.02).round();
        case 'image':
          final src = (block['src'] ?? '').toString();
          final loaded = HtmlImageLoader.load(src, maxWidth: w);
          if (loaded != null) {
            final iw = loaded.width, ih = loaded.height;
            if (iw > 0 && ih > 0) {
              final targetW = math.min(contentW, w);
              final targetH = (targetW * ih / iw).round().clamp(1, h ~/ 3);
              final decoded = img.decodeImage(loaded.bytes);
              if (decoded != null) {
                final resized = img.copyResize(decoded,
                    width: targetW, height: targetH);
                img.compositeImage(
                    image, resized, dstX: margin, dstY: y);
                y += targetH;
              }
            }
          }
          y += (h * 0.02).round();
        case 'icon':
          y += _drawIcon(image, block, margin, y, contentW, h);
          y += (h * 0.02).round();
        default:
          // chart / smartart / video / model3d → labelled placeholder box
          // (the WebView2 path renders these with full fidelity).
          y += _drawPlaceholder(image, type, margin, y, contentW, h);
          y += (h * 0.02).round();
      }
    }
  }

  /// Group consecutive runs of an item (items carry `itemStart` markers in
  /// the same way paragraphs do).
  static List<Map<String, String>> _groupRuns(
      List<Map<String, String>> items, int itemIndex) {
    final result = <Map<String, String>>[];
    var current = 0;
    for (final run in items) {
      if (current == itemIndex) result.add(run);
      if (run['itemStart'] == 'true') current++;
    }
    return result.isEmpty ? [{'text': ''}] : result;
  }

  static int _textWidth(String text, img.BitmapFont font) {
    var total = 0;
    for (final c in text.codeUnits) {
      total += font.characters[c]?.xAdvance ?? 14;
    }
    return total;
  }

  static int _drawParagraphs(
    img.Image image,
    List<Map<String, String>> runs,
    int x,
    int y,
    int contentW,
    int h, {
    required bool title,
    String bullet = '',
  }) {
    final font = title ? _fontTitle : _fontBody;
    final lineH = title ? 48 : 26;
    var cursorY = y;
    // Greedy wrap across the concatenated run text (single style per
    // paragraph — the raster path is a geometry approximation).
    final text = runs.map((r) => r['text'] ?? '').join(' ');
    final words = text.split(_wsRe).where((w) => w.isNotEmpty).toList();
    var line = '';
    for (final word in words) {
      final candidate = line.isEmpty ? word : '$line $word';
      final candidateW = _textWidth(bullet + candidate, font);
      if (candidateW > contentW && line.isNotEmpty) {
        _drawTextLine(image, bullet + line, x, cursorY, font);
        cursorY += lineH;
        line = word;
      } else {
        line = candidate;
      }
    }
    if (line.isNotEmpty) {
      _drawTextLine(image, bullet + line, x, cursorY, font);
      cursorY += lineH;
    }
    if (text.trim().isEmpty && bullet.isEmpty) {
      // Empty paragraph still occupies a line (mirrors the exporters).
      cursorY += lineH;
    }
    return cursorY - y;
  }

  static void _drawTextLine(
      img.Image image, String text, int x, int y, img.BitmapFont font) {
    img.drawString(image, text, font: font, x: x, y: y);
  }

  static int _drawTable(img.Image image, Map<String, dynamic> block, int x,
      int y, int contentW, int h) {
    final rowsDynamic = block['rows'] as List? ?? [];
    if (rowsDynamic.isEmpty) return 0;
    final cols = rowsDynamic.fold<int>(
        0, (m, row) => (row as List).length > m ? row.length : m);
    if (cols == 0) return 0;
    final rowH = (h * 0.05).round().clamp(18, 40);
    final colW = contentW ~/ cols;
    for (var r = 0; r < rowsDynamic.length; r++) {
      final cells = (rowsDynamic[r] as List);
      for (var c = 0; c < cols; c++) {
        final cx = x + c * colW;
        final cy = y + r * rowH;
        img.fillRect(image,
            x1: cx, y1: cy, x2: cx + colW, y2: cy + rowH,
            color: r == 0
                ? img.ColorRgba8(0x2f, 0x54, 0x7a, 255)
                : img.ColorRgba8(0xee, 0xf1, 0xf5, 255));
        img.drawRect(image,
            x1: cx, y1: cy, x2: cx + colW, y2: cy + rowH,
            color: img.ColorRgba8(0xc8, 0xd0, 0xda, 255));
        if (c < cells.length) {
          final cell = cells[c] is Map
              ? Map<String, String>.from(cells[c] as Map)
              : <String, String>{};
          final text = (cell['text'] ?? '').toString();
          _drawTextLine(image, text, cx + 6, cy + 4, _fontSmall);
        }
      }
    }
    return rowsDynamic.length * rowH;
  }

  static int _drawIcon(img.Image image, Map<String, dynamic> block, int x,
      int y, int contentW, int h) {
    final icon = IconItem.fromJson((block['data-icon'] ?? '').toString());
    final box = (h * 0.12).round().clamp(24, 80);
    img.fillRect(image,
        x1: x, y1: y, x2: x + box, y2: y + box,
        color: img.ColorRgba8(0x1f, 0x4e, 0x78, 255));
    // The icon path itself is only drawn in the WebView2 path; the box
    // preserves geometry. Name label keeps the block identifiable.
    if (icon.name.isNotEmpty) {
      _drawTextLine(image, icon.name, x + box + 8, y + 4, _fontSmall);
    }
    return box;
  }

  static int _drawPlaceholder(img.Image image, String type, int x, int y,
      int contentW, int h) {
    final boxH = (h * 0.14).round().clamp(36, 120);
    img.fillRect(image,
        x1: x, y1: y, x2: x + contentW, y2: y + boxH,
        color: img.ColorRgba8(0x2a, 0x4a, 0x7a, 255));
    _drawTextLine(image, '[$type]', x + 12, y + boxH ~/ 2 - 12, _fontSmall);
    return boxH;
  }

  // ---- Visual elements (free texts + drawn shapes) -----------------------

  static void _drawVisualElements(
      img.Image image, Map<String, dynamic> slide, int w, int h) {
    final rawVisual = slide['visualElements'];
    if (rawVisual is! Map) return;

    // Drawn shapes first (lower z-order behind free texts).
    final rawShapes = rawVisual['shapes'];
    if (rawShapes is List) {
      final shapes = rawShapes
          .map((e) => e is Map<String, dynamic>
              ? DrawnShape.fromMap(e)
              : (e is Map
                  ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                  : null))
          .whereType<DrawnShape>()
          .toList()
        ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
      for (final s in shapes) {
        _drawShape(image, s, w, h);
      }
    }
    // Free texts on top.
    final rawTexts = rawVisual['freeTexts'];
    if (rawTexts is List) {
      final texts = rawTexts
          .map((e) => e is Map<String, dynamic>
              ? FreeTextShape.fromMap(e)
              : (e is Map
                  ? FreeTextShape.fromMap(Map<String, dynamic>.from(e))
                  : null))
          .whereType<FreeTextShape>()
          .toList();
      for (final ft in texts) {
        final x = (ft.x / 100 * w).round();
        final y = (ft.y / 100 * h).round();
        _drawTextLine(image, ft.text, x, y, _fontBody);
      }
    }
  }

  static void _drawShape(img.Image image, DrawnShape s, int w, int h) {
    final x = (s.x / 100 * w).round();
    final y = (s.y / 100 * h).round();
    final sw = math.max(1, (s.w / 100 * w).round());
    final sh = math.max(1, (s.h / 100 * h).round());
    final fill = _color(s.fillColor, ((1 - s.fillTransparency) * 255).round());
    final stroke = _color(s.strokeColor, 255);
    switch (s.type) {
      case ShapeType.oval:
        _fillOval(image, x, y, sw, sh, fill);
        if (s.strokeWidth > 0) {
          _fillOval(image, x, y, sw, sh, stroke, outline: true);
        }
        return;
      case ShapeType.freeform:
      case ShapeType.merged:
      case ShapeType.line:
      case ShapeType.arrow:
      case ShapeType.rect:
        img.fillRect(image,
            x1: x, y1: y, x2: x + sw, y2: y + sh, color: fill);
        if (s.strokeWidth > 0) {
          img.drawRect(image,
              x1: x, y1: y, x2: x + sw, y2: y + sh, color: stroke);
        }
    }
  }

  /// Fill (or outline, when [outline]) an ellipse inside [x]..[x+w]×
  /// [y]..[y+h]. The `image` package ships no ellipse primitive, so this
  /// rasterizes the implicit ellipse equation per pixel.
  static void _fillOval(img.Image image, int x, int y, int w, int h,
      img.ColorRgba8 color,
      {bool outline = false}) {
    if (w <= 0 || h <= 0) return;
    final rx = w / 2.0, ry = h / 2.0;
    final cx = x + rx, cy = y + ry;
    for (var py = y; py < y + h; py++) {
      for (var px = x; px < x + w; px++) {
        final nx = (px + 0.5 - cx) / rx;
        final ny = (py + 0.5 - cy) / ry;
        final d = nx * nx + ny * ny;
        if (outline) {
          // Ring: inside the outer ellipse, outside the inset one. The
          // inset radii are clamped so a 1–2 px ellipse never divides by 0.
          final irx = math.max(1.0, rx - 1);
          final iry = math.max(1.0, ry - 1);
          final inx = (px + 0.5 - cx) / irx;
          final iny = (py + 0.5 - cy) / iry;
          if (d <= 1.0 && inx * inx + iny * iny > 1.0) {
            image.setPixelRgba(px, py, color.r, color.g, color.b, color.a);
          }
        } else if (d <= 1.0) {
          image.setPixelRgba(px, py, color.r, color.g, color.b, color.a);
        }
      }
    }
  }
}
