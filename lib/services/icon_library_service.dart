/// Icon library service (Track 15, FEAT 11).
///
/// Bundles ~1,100 SVG path icons (98 curated + ~1,000 Material Design Icons)
/// across 20+ categories. Icons are stored as SVG path `d` strings and
/// rendered inline in HTML, as PNG in PPTX, and as raster in PDF.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/icon_item.dart';
import 'mdi_icons_data.dart';

class IconLibraryService {
  IconLibraryService._();

  /// Compiled once — `_samplePath` walks the token list of every icon that
  /// gets rasterized (PPTX/PDF export, thumbnail grid); the letter test
  /// below previously allocated a fresh `RegExp` per token per while
  /// iteration.
  static final RegExp _svgTokenRe = RegExp(
      r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
  static final RegExp _letterRe = RegExp(r'[A-Za-z]');

  /// All bundled icons grouped by category.
  static Map<String, List<IconItem>> get iconsByCategory {
    if (_iconsByCategoryCache != null) return _iconsByCategoryCache!;
    _iconsByCategoryCache = _buildIndex(_allIcons);
    return _iconsByCategoryCache!;
  }

  static Map<String, List<IconItem>>? _iconsByCategoryCache;

  /// Search icons by name keyword (case-insensitive).
  static List<IconItem> search(String query) {
    if (query.trim().isEmpty) return _allIcons;
    final q = query.toLowerCase();
    return _allIcons.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  // ---- Slide HTML integration ------------------------------------------

  static final RegExp _dataIconRegExp = RegExp(
    r"""data-icon=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  /// Find every icon block in [html] (document order).
  static List<IconItem> iconsIn(String html) {
    final icons = <IconItem>[];
    for (final match in _dataIconRegExp.allMatches(html)) {
      final icon = IconItem.fromJson(match.group(2)!);
      if (icon.svgPath.isNotEmpty) icons.add(icon);
    }
    return icons;
  }

  /// Serialize an [icon] for a single-quoted HTML attribute.
  static String escapeAttribute(IconItem icon) =>
      icon.toJson().replaceAll("'", '&#39;');

  /// Build the `<span data-icon>` block inserted into slide HTML.
  static String iconMarkup(IconItem icon) =>
      '<span data-icon=\'${escapeAttribute(icon)}\'></span>';

  /// Replace the [index]-th icon block in [html] with new markup.
  static String replaceIconAt(String html, int index, IconItem icon) {
    final tagPattern = RegExp(
      r"""<span\b[^>]*data-icon=(['"])(.*?)\1[^>]*>.*?</span>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = tagPattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, iconMarkup(icon));
  }

  /// Number of icon blocks in [html].
  static int iconCount(String html) => _dataIconRegExp.allMatches(html).length;

  // ---- Rendering helpers ------------------------------------------------

  /// Render an [IconItem] to a PNG byte array at the given [size].
  ///
  /// The SVG path is parsed (M/L/H/V/C/Q/A/Z) and rasterized with the
  /// `package:image` primitives — no external renderer, works in the export
  /// isolate. Curves are sampled into line segments; the closed outline is
  /// filled and stroked so the glyph reads clearly even at small sizes.
  static Uint8List renderPng(IconItem icon, {int size = 48}) {
    final image = img.Image(width: size, height: size);
    final color = _parseHexColor(icon.color);
    if (icon.svgPath.isEmpty) {
      return Uint8List.fromList(img.encodePng(image));
    }
    final scale = size / 24.0;
    final points = _samplePath(icon.svgPath, scale: scale);
    if (points.length < 3) {
      return Uint8List.fromList(img.encodePng(image));
    }
    // Fill the closed outline (single subpath fill — adequate for the
    // bundled Material-style icons, which are mostly convex closed shapes).
    img.fillPolygon(image, vertices: points, color: color);
    // Stroke the outline so thin glyph parts (e.g. "Search" ring) survive
    // downscaling and anti-aliasing.
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      img.drawLine(
          image,
          x1: a.x.round(),
          y1: a.y.round(),
          x2: b.x.round(),
          y2: b.y.round(),
          color: color);
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Parse an SVG path `d` string and sample it into screen-space points
  /// (scaled by [scale]). Supports M/L/H/V/C/S/Q/T/A/Z with both relative
  /// and absolute forms — the subset used by Material-style icons.
  static List<img.Point> _samplePath(String d, {double scale = 1.0}) {
    final tokens = _svgTokenRe
        .allMatches(d)
        .map((m) => m.group(0)!)
        .toList();

    final points = <img.Point>[];
    double cx = 0, cy = 0; // current point
    double? sx, sy; // subpath start
    double? lastCx, lastCy; // previous control point (for S/T)

    int i = 0;
    while (i < tokens.length) {
      final tok = tokens[i];
      if (_letterRe.hasMatch(tok)) {
        i++;
        if (tok == 'Z' || tok == 'z') {
          if (sx != null) {
            cx = sx;
            cy = sy!;
            sx = null;
            sy = null;
          }
          continue;
        }
        // Command letter — fall through to argument parsing below.
        var cmd = tok;
        var rel = cmd == cmd.toLowerCase();
        cmd = cmd.toUpperCase();
        switch (cmd) {
          case 'M':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final x = double.parse(tokens[i]) * scale;
              final y = double.parse(tokens[i + 1]) * scale;
              i += 2;
              cx = rel ? cx + x : x;
              cy = rel ? cy + y : y;
              sx = cx;
              sy = cy;
              points.add(img.Point(cx.round(), cy.round()));
              // Subsequent pairs after M are implicit L.
              cmd = 'L';
              rel = false;
            }
            break;
          case 'L':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final x = double.parse(tokens[i]) * scale;
              final y = double.parse(tokens[i + 1]) * scale;
              i += 2;
              cx = rel ? cx + x : x;
              cy = rel ? cy + y : y;
              points.add(img.Point(cx.round(), cy.round()));
            }
            break;
          case 'H':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final x = double.parse(tokens[i]) * scale;
              i += 1;
              cx = rel ? cx + x : x;
              points.add(img.Point(cx.round(), cy.round()));
            }
            break;
          case 'V':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final y = double.parse(tokens[i]) * scale;
              i += 1;
              cy = rel ? cy + y : y;
              points.add(img.Point(cx.round(), cy.round()));
            }
            break;
          case 'C':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final c1x = double.parse(tokens[i]) * scale;
              final c1y = double.parse(tokens[i + 1]) * scale;
              final c2x = double.parse(tokens[i + 2]) * scale;
              final c2y = double.parse(tokens[i + 3]) * scale;
              final ex = double.parse(tokens[i + 4]) * scale;
              final ey = double.parse(tokens[i + 5]) * scale;
              i += 6;
              final sx0 = cx, sy0 = cy;
              final x1 = rel ? cx + c1x : c1x;
              final y1 = rel ? cy + c1y : c1y;
              final x2 = rel ? cx + c2x : c2x;
              final y2 = rel ? cy + c2y : c2y;
              final x3 = rel ? cx + ex : ex;
              final y3 = rel ? cy + ey : ey;
              _sampleCubic(points, sx0, sy0, x1, y1, x2, y2, x3, y3);
              cx = x3;
              cy = y3;
              lastCx = x2;
              lastCy = y2;
            }
            break;
          case 'S':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final c2x = double.parse(tokens[i]) * scale;
              final c2y = double.parse(tokens[i + 1]) * scale;
              final ex = double.parse(tokens[i + 2]) * scale;
              final ey = double.parse(tokens[i + 3]) * scale;
              i += 4;
              final sx0 = cx, sy0 = cy;
              final x1 = lastCx != null ? cx + (cx - lastCx) : cx;
              final y1 = lastCy != null ? cy + (cy - lastCy) : cy;
              final x2 = rel ? cx + c2x : c2x;
              final y2 = rel ? cy + c2y : c2y;
              final x3 = rel ? cx + ex : ex;
              final y3 = rel ? cy + ey : ey;
              _sampleCubic(points, sx0, sy0, x1, y1, x2, y2, x3, y3);
              cx = x3;
              cy = y3;
              lastCx = x2;
              lastCy = y2;
            }
            break;
          case 'Q':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final cx1 = double.parse(tokens[i]) * scale;
              final cy1 = double.parse(tokens[i + 1]) * scale;
              final ex = double.parse(tokens[i + 2]) * scale;
              final ey = double.parse(tokens[i + 3]) * scale;
              i += 4;
              final sx0 = cx, sy0 = cy;
              final x1 = rel ? cx + cx1 : cx1;
              final y1 = rel ? cy + cy1 : cy1;
              final x2 = rel ? cx + ex : ex;
              final y2 = rel ? cy + ey : ey;
              // Convert quadratic to cubic (identical curve).
              _sampleCubic(points, sx0, sy0,
                  sx0 + 2 / 3 * (x1 - sx0), sy0 + 2 / 3 * (y1 - sy0),
                  x2 + 2 / 3 * (x1 - x2), y2 + 2 / 3 * (y1 - y2), x2, y2);
              cx = x2;
              cy = y2;
              lastCx = x1;
              lastCy = y1;
            }
            break;
          case 'T':
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final ex = double.parse(tokens[i]) * scale;
              final ey = double.parse(tokens[i + 1]) * scale;
              i += 2;
              final sx0 = cx, sy0 = cy;
              final x1 = lastCx != null ? cx + (cx - lastCx) : cx;
              final y1 = lastCy != null ? cy + (cy - lastCy) : cy;
              final x2 = rel ? cx + ex : ex;
              final y2 = rel ? cy + ey : ey;
              _sampleCubic(points, sx0, sy0,
                  sx0 + 2 / 3 * (x1 - sx0), sy0 + 2 / 3 * (y1 - sy0),
                  x2 + 2 / 3 * (x1 - x2), y2 + 2 / 3 * (y1 - y2), x2, y2);
              cx = x2;
              cy = y2;
              lastCx = x1;
              lastCy = y1;
            }
            break;
          case 'A':
            // Elliptical arc — approximate with a cubic for the common
            // circular-arc cases used by icons.
            while (i < tokens.length && !_letterRe.hasMatch(tokens[i])) {
              final rx = double.parse(tokens[i]) * scale;
              final ry = double.parse(tokens[i + 1]) * scale;
              // tokens[i+2]: x-axis rotation (ignored), tokens[i+3]: large-arc,
              // tokens[i+4]: sweep — icons use simple half/full circles.
              final ex = double.parse(tokens[i + 5]) * scale;
              final ey = double.parse(tokens[i + 6]) * scale;
              i += 7;
              final x2 = rel ? cx + ex : ex;
              final y2 = rel ? cy + ey : ey;
              _sampleArc(points, cx, cy, x2, y2, rx, ry);
              cx = x2;
              cy = y2;
            }
            break;
        }
        // Reset relative flag per command (already handled by re-reading tok).
      }
    }
    return points;
  }

  /// Sample a cubic Bézier into ~16 line segments (added to [points]).
  static void _sampleCubic(List<img.Point> points,
      double x0, double y0, double x1, double y1,
      double x2, double y2, double x3, double y3) {
    const steps = 16;
    var px = x0, py = y0;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final mt = 1 - t;
      final x = mt * mt * mt * x0 +
          3 * mt * mt * t * x1 +
          3 * mt * t * t * x2 +
          t * t * t * x3;
      final y = mt * mt * mt * y0 +
          3 * mt * mt * t * y1 +
          3 * mt * t * t * y2 +
          t * t * t * y3;
      if ((x - px).abs() > 0.3 || (y - py).abs() > 0.3) {
        points.add(img.Point(x.round(), y.round()));
        px = x;
        py = y;
      }
    }
  }

  /// Approximate an elliptical arc between (x0,y0)→(x1,y1) with a quadratic
  /// midpoint bulge (adequate for the 90°/180° arcs found in icons).
  static void _sampleArc(List<img.Point> points,
      double x0, double y0, double x1, double y1,
      double rx, double ry) {
    if (rx <= 0 || ry <= 0) {
      points.add(img.Point(x1.round(), y1.round()));
      return;
    }
    // Midpoint of the chord, then the control point pushed out perpendicular
    // by the bulge radius (a circle arc through the chord endpoints).
    final mx = (x0 + x1) / 2, my = (y0 + y1) / 2;
    final dx = x1 - x0, dy = y1 - y0;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.01) {
      points.add(img.Point(x1.round(), y1.round()));
      return;
    }
    final nx = -dy / len, ny = dx / len;
    final h = math.sqrt((rx * rx - (len / 2) * (len / 2)).clamp(0.0, double.infinity));
    final cxp = mx + nx * h;
    final cyp = my + ny * h;
    // Sample a quadratic Bézier through the control point.
    const steps = 12;
    var px = x0, py = y0;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final mt = 1 - t;
      final x = mt * mt * x0 + 2 * mt * t * cxp + t * t * x1;
      final y = mt * mt * y0 + 2 * mt * t * cyp + t * t * y1;
      if ((x - px).abs() > 0.3 || (y - py).abs() > 0.3) {
        points.add(img.Point(x.round(), y.round()));
        px = x;
        py = y;
      }
    }
  }

  /// Parse a hex colour string like `#FF0000` or `#ff0000` into an RGB colour.
  static img.ColorRgb8 _parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length < 6) return img.ColorRgb8(0, 0, 0);
    final r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 0;
    final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
    final b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
    return img.ColorRgb8(r, g, b);
  }

  // ---- Icon data --------------------------------------------------------

  static Map<String, List<IconItem>> _buildIndex(List<IconItem> icons) {
    final map = <String, List<IconItem>>{};
    for (final icon in icons) {
      map.putIfAbsent(icon.category, () => []).add(icon);
    }
    return map;
  }

  /// Curated hand-picked icons (kept first so search/preview order stays
  /// stable); the Material Design set is appended below (Track 15, P1).
  static final List<IconItem> _curatedIcons = [
    // ---- UI / Actions ----------------------------------------------------
    const IconItem(name: 'Add', category: 'UI', svgPath: 'M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z'),
    const IconItem(name: 'Remove', category: 'UI', svgPath: 'M19 13H5v-2h14v2z'),
    const IconItem(name: 'Close', category: 'UI', svgPath: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z'),
    const IconItem(name: 'Menu', category: 'UI', svgPath: 'M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z'),
    const IconItem(name: 'Search', category: 'UI', svgPath: 'M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z'),
    const IconItem(name: 'Edit', category: 'UI', svgPath: 'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z'),
    const IconItem(name: 'Delete', category: 'UI', svgPath: 'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'),
    const IconItem(name: 'Save', category: 'UI', svgPath: 'M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z'),
    const IconItem(name: 'Settings', category: 'UI', svgPath: 'M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z'),
    const IconItem(name: 'Info', category: 'UI', svgPath: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z'),
    const IconItem(name: 'Help', category: 'UI', svgPath: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z'),
    const IconItem(name: 'Home', category: 'UI', svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z'),
    const IconItem(name: 'Refresh', category: 'UI', svgPath: 'M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z'),

    // ---- Navigation --------------------------------------------------------
    const IconItem(name: 'ArrowBack', category: 'Navigation', svgPath: 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z'),
    const IconItem(name: 'ArrowForward', category: 'Navigation', svgPath: 'M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8z'),
    const IconItem(name: 'ArrowUpward', category: 'Navigation', svgPath: 'M4 12l1.41 1.41L11 7.83V20h2V7.83l5.58 5.59L20 12l-8-8-8 8z'),
    const IconItem(name: 'ArrowDownward', category: 'Navigation', svgPath: 'M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z'),
    const IconItem(name: 'ChevronLeft', category: 'Navigation', svgPath: 'M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z'),
    const IconItem(name: 'ChevronRight', category: 'Navigation', svgPath: 'M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z'),
    const IconItem(name: 'ExpandMore', category: 'Navigation', svgPath: 'M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z'),
    const IconItem(name: 'ExpandLess', category: 'Navigation', svgPath: 'M12 8l-6 6 1.41 1.41L12 10.83l4.59 4.58L18 14z'),
    const IconItem(name: 'FirstPage', category: 'Navigation', svgPath: 'M18.41 16.59L13.82 12l4.59-4.59L17 6l-6 6 6 6zM6 6h2v12H6z'),
    const IconItem(name: 'LastPage', category: 'Navigation', svgPath: 'M5.59 7.41L10.18 12l-4.59 4.59L7 18l6-6-6-6zM16 6h2v12h-2z'),

    // ---- Media / Document -------------------------------------------------
    const IconItem(name: 'Image', category: 'Media', svgPath: 'M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z'),
    const IconItem(name: 'Video', category: 'Media', svgPath: 'M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z'),
    const IconItem(name: 'Music', category: 'Media', svgPath: 'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z'),
    const IconItem(name: 'Camera', category: 'Media', svgPath: 'M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z'),
    const IconItem(name: 'File', category: 'Media', svgPath: 'M6 2c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6H6zm0 18V4h7v5h5v11H6z'),
    const IconItem(name: 'Folder', category: 'Media', svgPath: 'M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z'),
    const IconItem(name: 'Print', category: 'Media', svgPath: 'M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z'),
    const IconItem(name: 'Upload', category: 'Media', svgPath: 'M9 16h6v-6h4l-7-7-7 7h4zm-4 2h14v2H5z'),
    const IconItem(name: 'Download', category: 'Media', svgPath: 'M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z'),

    // ---- Communication ----------------------------------------------------
    const IconItem(name: 'Email', category: 'Communication', svgPath: 'M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z'),
    const IconItem(name: 'Chat', category: 'Communication', svgPath: 'M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H5.17L4 17.17V4h16v12z'),
    const IconItem(name: 'Phone', category: 'Communication', svgPath: 'M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z'),
    const IconItem(name: 'Share', category: 'Communication', svgPath: 'M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92 1.61 0 2.92-1.31 2.92-2.92s-1.31-2.92-2.92-2.92z'),
    const IconItem(name: 'Notifications', category: 'Communication', svgPath: 'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z'),
    const IconItem(name: 'Person', category: 'Communication', svgPath: 'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z'),
    const IconItem(name: 'Group', category: 'Communication', svgPath: 'M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z'),

    // ---- Business & Finance ------------------------------------------------
    const IconItem(name: 'Chart', category: 'Business', svgPath: 'M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z'),
    const IconItem(name: 'Analytics', category: 'Business', svgPath: 'M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z'),
    const IconItem(name: 'Business', category: 'Business', svgPath: 'M12 7V3H2v18h20V7H12zM6 19H4v-2h2v2zm0-4H4v-2h2v2zm0-4H4V9h2v2zm0-4H4V5h2v2zm4 12H8v-2h2v2zm0-4H8v-2h2v2zm0-4H8V9h2v2zm0-4H8V5h2v2zm10 12h-8v-2h2v-2h-2v-2h2v-2h-2V9h8v10zm-2-8h-2v2h2v-2zm0 4h-2v2h2v-2z'),
    const IconItem(name: 'Receipt', category: 'Business', svgPath: 'M18 17H6v-2h12v2zm0-4H6v-2h12v2zm0-4H6V7h12v2zm3-6H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H3V5h18v14z'),
    const IconItem(name: 'Payment', category: 'Business', svgPath: 'M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z'),
    const IconItem(name: 'ShoppingCart', category: 'Business', svgPath: 'M7 18c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm10 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zM7.17 14.75l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.86-7.01L19.42 4h-.01l-1.1 2-2.76 5H8.53l-.13-.27L6.16 6l-.95-2-.94-2H1v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25z'),
    const IconItem(name: 'AccountBalance', category: 'Business', svgPath: 'M4 10h3v7H4v-7zm6.5 0h3v7h-3v-7zM2 19h20v3H2v-3zM21 10h-3v7h3v-7zM11.5 3.26L17 6.09V8H7V6.09l4.5-2.83zM21 9H3V7l9-5 9 5v2z'),

    // ---- Education / Science -----------------------------------------------
    const IconItem(name: 'School', category: 'Education', svgPath: 'M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3z'),
    const IconItem(name: 'Book', category: 'Education', svgPath: 'M18 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 18H6V4h2v8l2.5-1.5L13 12V4h5v16z'),
    const IconItem(name: 'Lightbulb', category: 'Education', svgPath: 'M9 21c0 .55.45 1 1 1h4c.55 0 1-.45 1-1v-1H9v1zm3-19C8.14 2 5 5.14 5 9c0 2.38 1.19 4.47 3 5.74V17c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.26c1.81-1.27 3-3.36 3-5.74 0-3.86-3.14-7-7-7z'),
    const IconItem(name: 'Science', category: 'Education', svgPath: 'M19.8 18.4L14 10.67V6.5l1.35-1.69c.26-.33.03-.81-.39-.81H9.04c-.42 0-.65.48-.39.81L10 6.5v4.17L4.2 18.4c-.49.66-.02 1.6.8 1.6h14c.82 0 1.29-.94.8-1.6z'),
    const IconItem(name: 'Award', category: 'Education', svgPath: 'M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94.63 1.5 1.98 2.63 3.61 2.96V19H7v2h10v-2h-4v-3.1c1.63-.33 2.98-1.46 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z'),
    const IconItem(name: 'Graduation', category: 'Education', svgPath: 'M4 11.5L1 13l11 6 11-6-3-1.5L12 19 4 11.5zm0-4L1 9l11 6 11-6-3-1.5L12 11 4 7.5zm0-4L1 5l11 6 11-6-3-1.5L12 7 4 3.5z'),

    // ---- Arrows (basic) ----------------------------------------------------
    const IconItem(name: 'ArrowUp', category: 'Arrows', svgPath: 'M4 12l1.41 1.41L11 7.83V20h2V7.83l5.58 5.59L20 12l-8-8-8 8z'),
    const IconItem(name: 'ArrowDown', category: 'Arrows', svgPath: 'M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z'),
    const IconItem(name: 'ArrowLeft', category: 'Arrows', svgPath: 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z'),
    const IconItem(name: 'ArrowRight', category: 'Arrows', svgPath: 'M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8z'),
    const IconItem(name: 'ArrowUpRight', category: 'Arrows', svgPath: 'M5 17.59L15.59 7H9V5h10v10h-2V8.41L6.41 19 5 17.59z'),
    const IconItem(name: 'ArrowDownLeft', category: 'Arrows', svgPath: 'M19 6.41L17.59 5 5 17.59V9H3v10h10v-2H8.41L19 6.41z'),
    const IconItem(name: 'SwapHoriz', category: 'Arrows', svgPath: 'M6.99 11L3 15l3.99 4v-3H14v-2H6.99v-3zM21 9l-3.99-4v3H10v2h7.01v3L21 9z'),
    const IconItem(name: 'SwapVert', category: 'Arrows', svgPath: 'M16 17.01V10h-2v7.01h-3L15 21l4-3.99h-3zM9 3L5 6.99h3V14h2V6.99h3L9 3z'),
    const IconItem(name: 'UnfoldMore', category: 'Arrows', svgPath: 'M12 5.83L15.17 9l1.41-1.41L12 3 7.41 7.59 8.83 9 12 5.83zm0 12.34L8.83 15l-1.41 1.41L12 21l4.59-4.59L15.17 15 12 18.17z'),
    const IconItem(name: 'SubdirectoryArrowRight', category: 'Arrows', svgPath: 'M19 15l-6 6-1.42-1.42L15.17 16H4V4h2v10h9.17l-3.59-3.58L13 9l6 6z'),

    // ---- Devices / Hardware ------------------------------------------------
    const IconItem(name: 'Computer', category: 'Devices', svgPath: 'M20 18c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2H0v2h24v-2h-4zM4 6h16v10H4V6z'),
    const IconItem(name: 'PhoneAndroid', category: 'Devices', svgPath: 'M16 1H8C6.34 1 5 2.34 5 4v16c0 1.66 1.34 3 3 3h8c1.66 0 3-1.34 3-3V4c0-1.66-1.34-3-3-3zm-2 20h-4v-1h4v1zm3.25-3H6.75V4h10.5v14z'),
    const IconItem(name: 'Tablet', category: 'Devices', svgPath: 'M21 4H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H3V6h18v12z'),
    const IconItem(name: 'Watch', category: 'Devices', svgPath: 'M20 12c0-2.54-1.19-4.81-3.04-6.27L16 0H8l-.95 5.73C5.19 7.19 4 9.45 4 12s1.19 4.81 3.04 6.27L8 24h8l.96-5.73C18.81 16.81 20 14.54 20 12zM6 12c0-3.31 2.69-6 6-6s6 2.69 6 6-2.69 6-6 6-6-2.69-6-6z'),
    const IconItem(name: 'Headphones', category: 'Devices', svgPath: 'M12 1c-4.97 0-9 4.03-9 9v7c0 1.66 1.34 3 3 3h3v-8H5v-2c0-3.87 3.13-7 7-7s7 3.13 7 7v2h-4v8h3c1.66 0 3-1.34 3-3v-7c0-4.97-4.03-9-9-9z'),
    const IconItem(name: 'Speaker', category: 'Devices', svgPath: 'M17 2H7c-1.1 0-2 .9-2 2v16c0 1.1.9 1.99 2 1.99L17 22c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 2c1.1 0 2 .9 2 2s-.9 2-2 2-2-.9-2-2 .9-2 2-2zm0 13c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z'),
    const IconItem(name: 'Battery', category: 'Devices', svgPath: 'M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4z'),

    // ---- Time / Scheduling --------------------------------------------------
    const IconItem(name: 'Calendar', category: 'Time', svgPath: 'M19 4h-1V2h-2v2H8V2H6v2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10zm0-12H5V6h14v2z'),
    const IconItem(name: 'Clock', category: 'Time', svgPath: 'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z'),
    const IconItem(name: 'Schedule', category: 'Time', svgPath: 'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z'),
    const IconItem(name: 'Alarm', category: 'Time', svgPath: 'M22 5.72l-4.6-3.86-1.29 1.53 4.6 3.86L22 5.72zM7.88 3.39L6.6 1.86 2 5.71l1.29 1.53 4.59-3.85zM12.5 8H11v6l4.75 2.85.75-1.23-4-2.37V8zM12 4c-4.97 0-9 4.03-9 9s4.02 9 9 9c4.97 0 9-4.03 9-9s-4.03-9-9-9zm0 16c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z'),
    const IconItem(name: 'Timer', category: 'Time', svgPath: 'M15 1H9v2h6V1zm-4 13h2V8h-2v6zm8.03-6.61l1.42-1.42c-.43-.51-.9-.99-1.41-1.41l-1.42 1.42C16.07 4.74 14.12 4 12 4c-4.97 0-9 4.03-9 9s4.02 9 9 9 9-4.03 9-9c0-2.12-.74-4.07-1.97-5.61zM12 20c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z'),

    // ---- Maps / Travel ----------------------------------------------------
    const IconItem(name: 'Location', category: 'Travel', svgPath: 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z'),
    const IconItem(name: 'Map', category: 'Travel', svgPath: 'M20.5 3l-.16.03L15 5.1 9 3 3.36 4.9c-.21.07-.36.25-.36.48V20.5c0 .28.22.5.5.5l.16-.03L9 18.9l6 2.1 5.64-1.9c.21-.07.36-.25.36-.48V3.5c0-.28-.22-.5-.5-.5zM15 19l-6-2.11V5l6 2.11V19z'),
    const IconItem(name: 'Flight', category: 'Travel', svgPath: 'M10 18h4v-2l-2-1-2 1v2zM21 6v2l-8 3.5V18l2 1v2l-3-.8-3 .8v-2l2-1v-6.5L3 8V6l8 2.5V4.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v4L21 6z'),
    const IconItem(name: 'Hotel', category: 'Travel', svgPath: 'M7 13c1.66 0 3-1.34 3-3S8.66 7 7 7s-3 1.34-3 3 1.34 3 3 3zm12-6h-8v7H3V5H1v15h2v-3h18v3h2v-9c0-2.21-1.79-4-4-4z'),
    const IconItem(name: 'Restaurant', category: 'Travel', svgPath: 'M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4z'),
    const IconItem(name: 'Directions', category: 'Travel', svgPath: 'M21.71 11.29l-9-9c-.39-.39-1.02-.39-1.41 0l-9 9c-.39.39-.39 1.02 0 1.41l9 9c.39.39 1.02.39 1.41 0l9-9c.39-.38.39-1.01 0-1.41zM14 14.5V12h-4v3H8v-4c0-.55.45-1 1-1h5V7.5l3.5 3.5-3.5 3.5z'),
    const IconItem(name: 'LocalOffer', category: 'Travel', svgPath: 'M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z'),

    // ---- Status / Rating ----------------------------------------------------
    const IconItem(name: 'Star', category: 'Status', svgPath: 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z'),
    const IconItem(name: 'StarOutline', category: 'Status', svgPath: 'M22 9.24l-7.19-.62L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21 12 17.27 18.18 21l-1.63-7.03L22 9.24zM12 15.4l-3.76 2.27 1-4.28-3.32-2.88 4.38-.38L12 6.1l1.71 4.04 4.38.38-3.32 2.88 1 4.28L12 15.4z'),
    const IconItem(name: 'Favorite', category: 'Status', svgPath: 'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z'),
    const IconItem(name: 'CheckCircle', category: 'Status', svgPath: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z'),
    const IconItem(name: 'Warning', category: 'Status', svgPath: 'M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z'),
    const IconItem(name: 'Error', category: 'Status', svgPath: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z'),
    const IconItem(name: 'Verified', category: 'Status', svgPath: 'M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z'),
    const IconItem(name: 'Flag', category: 'Status', svgPath: 'M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6z'),

    // ---- Text Formatting ----------------------------------------------------
    const IconItem(name: 'Bold', category: 'Text', svgPath: 'M15.6 10.79c.97-.67 1.65-1.77 1.65-2.79 0-2.26-1.75-4-4-4H7v14h7.04c2.09 0 3.71-1.7 3.71-3.79 0-1.52-.86-2.82-2.15-3.42zM10 6.5h3c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-3v-3zm3.5 9H10v-3h3.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5z'),
    const IconItem(name: 'Italic', category: 'Text', svgPath: 'M10 4v3h2.21l-3.42 8H6v3h8v-3h-2.21l3.42-8H18V4z'),
    const IconItem(name: 'Underline', category: 'Text', svgPath: 'M12 17c3.31 0 6-2.69 6-6V3h-2.5v8c0 1.93-1.57 3.5-3.5 3.5S8.5 12.93 8.5 11V3H6v8c0 3.31 2.69 6 6 6zm-7 2v2h14v-2H5z'),
    const IconItem(name: 'Strikethrough', category: 'Text', svgPath: 'M10 19h4v-3h-4v3zM5 4v3h5v3h4V7h5V4H5zM3 14h18v-2H3v2z'),
    const IconItem(name: 'FormatList', category: 'Text', svgPath: 'M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z'),
    const IconItem(name: 'FormatQuote', category: 'Text', svgPath: 'M6 17h3l2-4V7H5v6h3zm8 0h3l2-4V7h-6v6h3z'),
    const IconItem(name: 'Code', category: 'Text', svgPath: 'M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z'),
    const IconItem(name: 'Link', category: 'Text', svgPath: 'M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z'),
    const IconItem(name: 'TableIcon', category: 'Text', svgPath: 'M20 3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H4V5h16v14zM8 11h4v2H8v-2zm0 4h4v2H8v-2zm0-8h4v2H8V7zm8 4h-4v2h4v-2zm-4 4h4v2h-4v-2zm0-8h4v2h-4V7z'),
  ];

  /// The full bundled library: curated icons first, then the Material Design
  /// set with any duplicate names dropped (curated names win). Track 15, P1.
  static final List<IconItem> _allIcons = () {
    final curatedNames = _curatedIcons
        .map((i) => i.name.toLowerCase())
        .toSet();
    final merged = List<IconItem>.of(_curatedIcons);
    for (final icon in mdiIcons) {
      if (curatedNames.contains(icon.name.toLowerCase())) continue;
      merged.add(icon);
    }
    return merged;
  }();
}