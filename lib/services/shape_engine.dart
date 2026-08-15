/// Shape engine (Track 21, FEAT 25, 26).
///
/// Renders DrawnShape to PPTX OOXML (p:sp + prstGeom/custGeom), SVG
/// (delegated to DrawnShape.svgMarkup), and PDF (delegated to ShapeEngine).
/// Handles merge shapes (union/combine/intersect/subtract) with *real*
/// boolean geometry via [PolygonBoolean] (Greiner–Hormann) — rects and
/// ovals are converted to polygons, freeform paths are parsed as-is, and
/// the boolean result becomes a freeform custGeom path.
library;

import 'dart:math' as math;

import '../models/drawn_shape.dart';
import 'polygon_boolean.dart';

class ShapeEngine {
  ShapeEngine._();

  /// Compiled once — path parsing runs per freeform/merged shape per export.
  static final RegExp _cmdRe = RegExp(r'[MmLlHhVvCcSsQqTtZz]');
  static final RegExp _numRe =
      RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');

  /// OOXML `<p:sp>` for a drawn shape.
  static String renderPptxShape({
    required int shapeId,
    required DrawnShape shape,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
  }) {
    final geom = shape.pptxPresetGeom;
    final fillHex = shape.fillColor.replaceAll('#', '');
    final strokeHex = shape.strokeColor.replaceAll('#', '');
    final sw = (shape.strokeWidth * 12700).round();
    final rot = shape.rotation != 0
        ? ' rot="${(shape.rotation * 60000).round()}"'
        : '';
    final hasGrad = shape.gradientStart.isNotEmpty &&
        shape.gradientEnd.isNotEmpty;
    final alphaXml = shape.fillTransparency > 0
        ? '<a:alpha val="${((1 - shape.fillTransparency) * 100000).round()}"/>'
        : '';
    final fillXml = hasGrad
        ? _gradFillXml(shape)
        : '<a:solidFill><a:srgbClr val="$fillHex">$alphaXml'
            '</a:srgbClr></a:solidFill>';
    final lnXml = '<a:ln w="$sw"><a:solidFill><a:srgbClr val="$strokeHex"/>'
        '</a:solidFill></a:ln>';
    // Track 25: effects (shadow/glow/soft edge/reflection) + bevel.
    final effectXml = shape.effect.toEffectLstXml();
    final sp3dXml = shape.effect.toSp3dXml();

    // For freeform/merged shapes with a path, use custGeom.
    String geomXml;
    if ((shape.type == ShapeType.freeform || shape.type == ShapeType.merged) &&
        shape.freeformPath.isNotEmpty) {
      geomXml = _custGeomXml(
          shape.freeformPath, extCx, extCy, shape.w, shape.h);
    } else {
      geomXml = '<a:prstGeom prst="$geom"><a:avLst/></a:prstGeom>';
    }

    return '<p:sp>\n'
        '  <p:nvSpPr><p:cNvPr id="$shapeId" name="Shape ${shape.type.name} ${shape.id}"/>'
        '<p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n'
        '  <p:spPr><a:xfrm$rot><a:off x="$offX" y="$offY"/>'
        '<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
        '$geomXml$fillXml$lnXml$effectXml$sp3dXml</p:spPr>\n'
        '  <p:txBody><a:bodyPr/><a:lstStyle/>'
        '<a:p><a:endParaRPr lang="en-US"/></a:p></p:txBody>\n'
        '</p:sp>\n';
  }

  /// Build `<a:custGeom>` XML from an SVG path `d` string.
  /// The path coordinates live in the shape's local box (0..shapeW/0..shapeH
  /// — the same units [DrawnShape.pathFromPoints] emits); they are scaled to
  /// the EMU bounding box. Multiple subpaths (e.g. a union of two disjoint
  /// shapes, or a subtract frame) become separate `<a:path>` elements.
  /// Supports M/L/H/V/C/S/Q/T commands (absolute + relative).
  static String _custGeomXml(
      String pathD, int boxW, int boxH, double shapeW, double shapeH) {
    final scaleX = shapeW == 0 ? 1.0 : boxW / shapeW;
    final scaleY = shapeH == 0 ? 1.0 : boxH / shapeH;
    final b = StringBuffer()
      ..write('<a:custGeom>')
      ..write('<a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/>')
      ..write('<a:rect l="0" t="0" r="$boxW" b="$boxH"/>')
      ..write('<a:pathLst>');

    final matches = _cmdRe.allMatches(pathD).toList();

    // Split into subpaths at each M/m command.
    final subStarts = <int>[];
    for (var k = 0; k < matches.length; k++) {
      final c = matches[k].group(0)!;
      if (c == 'M' || c == 'm') subStarts.add(k);
    }
    if (subStarts.isEmpty) subStarts.add(0);

    for (var s = 0; s < subStarts.length; s++) {
      final startK = subStarts[s];
      final endK = s + 1 < subStarts.length ? subStarts[s + 1] : matches.length;
      b.write('<a:path w="$boxW" h="$boxH">');
      double cx = 0, cy = 0;
      double? lastCx, lastCy;
      for (var k = startK; k < endK; k++) {
        final cmd = matches[k].group(0)!;
        final startIdx = matches[k].end;
        final endIdx =
            k + 1 < matches.length ? matches[k + 1].start : pathD.length;
        final nums = _numRe
            .allMatches(pathD.substring(startIdx, endIdx))
            .map((m) => double.parse(m.group(0)!))
            .toList();
        final rel = cmd == cmd.toLowerCase();
        final upper = cmd.toUpperCase();
        double sx(num v) => v * scaleX;
        double sy(num v) => v * scaleY;
      switch (upper) {
        case 'M':
          if (nums.length >= 2) {
            final nx = rel ? cx + sx(nums[0]) : sx(nums[0]);
            final ny = rel ? cy + sy(nums[1]) : sy(nums[1]);
            cx = nx; cy = ny;
            b.write('<a:moveTo><a:pt x="${nx.round()}" y="${ny.round()}"/></a:moveTo>');
          }
          break;
        case 'L':
          for (var n = 0; n + 1 < nums.length; n += 2) {
            final nx = rel ? cx + sx(nums[n]) : sx(nums[n]);
            final ny = rel ? cy + sy(nums[n + 1]) : sy(nums[n + 1]);
            cx = nx; cy = ny;
            b.write('<a:lnTo><a:pt x="${nx.round()}" y="${ny.round()}"/></a:lnTo>');
          }
          break;
        case 'H':
          for (final v in nums) {
            final nx = rel ? cx + sx(v) : sx(v);
            cx = nx;
            b.write('<a:lnTo><a:pt x="${nx.round()}" y="${cy.round()}"/></a:lnTo>');
          }
          break;
        case 'V':
          for (final v in nums) {
            final ny = rel ? cy + sy(v) : sy(v);
            cy = ny;
            b.write('<a:lnTo><a:pt x="${cx.round()}" y="${ny.round()}"/></a:lnTo>');
          }
          break;
        case 'C':
          for (var n = 0; n + 5 < nums.length; n += 6) {
            final x1 = rel ? cx + sx(nums[n]) : sx(nums[n]);
            final y1 = rel ? cy + sy(nums[n + 1]) : sy(nums[n + 1]);
            final x2 = rel ? cx + sx(nums[n + 2]) : sx(nums[n + 2]);
            final y2 = rel ? cy + sy(nums[n + 3]) : sy(nums[n + 3]);
            final x3 = rel ? cx + sx(nums[n + 4]) : sx(nums[n + 4]);
            final y3 = rel ? cy + sy(nums[n + 5]) : sy(nums[n + 5]);
            b.write('<a:cubicBezTo><a:pt x="${x1.round()}" y="${y1.round()}"/>'
                '<a:pt x="${x2.round()}" y="${y2.round()}"/>'
                '<a:pt x="${x3.round()}" y="${y3.round()}"/></a:cubicBezTo>');
            cx = x3; cy = y3;
            lastCx = x2; lastCy = y2;
          }
          break;
        case 'S':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x1 = lastCx != null ? cx + (cx - lastCx) : cx;
            final y1 = lastCy != null ? cy + (cy - lastCy) : cy;
            final x2 = rel ? cx + sx(nums[n]) : sx(nums[n]);
            final y2 = rel ? cy + sy(nums[n + 1]) : sy(nums[n + 1]);
            final x3 = rel ? cx + sx(nums[n + 2]) : sx(nums[n + 2]);
            final y3 = rel ? cy + sy(nums[n + 3]) : sy(nums[n + 3]);
            b.write('<a:cubicBezTo><a:pt x="${x1.round()}" y="${y1.round()}"/>'
                '<a:pt x="${x2.round()}" y="${y2.round()}"/>'
                '<a:pt x="${x3.round()}" y="${y3.round()}"/></a:cubicBezTo>');
            cx = x3; cy = y3;
            lastCx = x2; lastCy = y2;
          }
          break;
        case 'Q':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x1 = rel ? cx + sx(nums[n]) : sx(nums[n]);
            final y1 = rel ? cy + sy(nums[n + 1]) : sy(nums[n + 1]);
            final x2 = rel ? cx + sx(nums[n + 2]) : sx(nums[n + 2]);
            final y2 = rel ? cy + sy(nums[n + 3]) : sy(nums[n + 3]);
            // Approximate quadratic with a cubic (identical curve).
            final c1x = cx + 2 / 3 * (x1 - cx);
            final c1y = cy + 2 / 3 * (y1 - cy);
            final c2x = x2 + 2 / 3 * (x1 - x2);
            final c2y = y2 + 2 / 3 * (y1 - y2);
            b.write('<a:cubicBezTo><a:pt x="${c1x.round()}" y="${c1y.round()}"/>'
                '<a:pt x="${c2x.round()}" y="${c2y.round()}"/>'
                '<a:pt x="${x2.round()}" y="${y2.round()}"/></a:cubicBezTo>');
            cx = x2; cy = y2;
            lastCx = x1; lastCy = y1;
          }
          break;
        case 'T':
          for (var n = 0; n + 1 < nums.length; n += 2) {
            final x1 = lastCx != null ? cx + (cx - lastCx) : cx;
            final y1 = lastCy != null ? cy + (cy - lastCy) : cy;
            final x2 = rel ? cx + sx(nums[n]) : sx(nums[n]);
            final y2 = rel ? cy + sy(nums[n + 1]) : sy(nums[n + 1]);
            final c1x = cx + 2 / 3 * (x1 - cx);
            final c1y = cy + 2 / 3 * (y1 - cy);
            final c2x = x2 + 2 / 3 * (x1 - x2);
            final c2y = y2 + 2 / 3 * (y1 - y2);
            b.write('<a:cubicBezTo><a:pt x="${c1x.round()}" y="${c1y.round()}"/>'
                '<a:pt x="${c2x.round()}" y="${c2y.round()}"/>'
                '<a:pt x="${x2.round()}" y="${y2.round()}"/></a:cubicBezTo>');
            cx = x2; cy = y2;
            lastCx = x1; lastCy = y1;
          }
          break;
        case 'Z':
          b.write('<a:close/>');
          break;
      }
    }

      b.write('</a:path>');
    }
    b.write('</a:pathLst></a:custGeom>');
    return b.toString();
  }

  /// OOXML `<a:gradFill>` (linear, angle-based) for a gradient shape.
  static String _gradFillXml(DrawnShape shape) {
    final startHex = shape.gradientStart.replaceAll('#', '');
    final endHex = shape.gradientEnd.replaceAll('#', '');
    final alphaXml = shape.fillTransparency > 0
        ? '<a:alpha val="${((1 - shape.fillTransparency) * 100000).round()}"/>'
        : '';
    // OOXML angles: 0 = left→right, measured counter-clockwise in 1/60000
    // degree units; SVG rotate() is clockwise — negate for parity.
    final ooxmlAngle = ((-shape.gradientAngle * 60000).round() % 21600000);
    return '<a:gradFill rotWithShape="1">'
        '<a:gsLst>'
        '<a:gs pos="0"><a:srgbClr val="${startHex.toUpperCase()}">$alphaXml</a:srgbClr></a:gs>'
        '<a:gs pos="100000"><a:srgbClr val="${endHex.toUpperCase()}">$alphaXml</a:srgbClr></a:gs>'
        '</a:gsLst>'
        '<a:lin ang="$ooxmlAngle" scaled="1"/>'
        '</a:gradFill>';
  }

  // ---- Boolean merge (Track 21, P3) -------------------------------------

  /// A ∪ B — real boolean union (not a bounding box).
  static DrawnShape mergeUnion(DrawnShape a, DrawnShape b) =>
      _mergeBoolean(a, b, 'union');

  /// A ⊕ B — "combine" (XOR): union minus intersection.
  static DrawnShape mergeCombine(DrawnShape a, DrawnShape b) =>
      _mergeBoolean(a, b, 'combine');

  /// A ∩ B — real boolean intersection.
  static DrawnShape mergeIntersect(DrawnShape a, DrawnShape b) {
    final result = _mergeBoolean(a, b, 'intersect');
    if (result.mergeOp == 'intersect_noop') return result;
    return result;
  }

  /// A − B — real boolean difference.
  static DrawnShape mergeSubtract(DrawnShape a, DrawnShape b) =>
      _mergeBoolean(a, b, 'subtract');

  /// Run the boolean operation and package the result as a merged shape.
  /// The result keeps the union bounding box of both inputs; its
  /// [DrawnShape.freeformPath] carries the real boolean outline (in the
  /// shape's local box units, ready for SVG / custGeom rendering).
  static DrawnShape _mergeBoolean(DrawnShape a, DrawnShape b, String op) {
    final mergedId = '${op}_${a.id}_${b.id}';
    final loops = _booleanLoops(a, b, op);
    if (loops == null || loops.isEmpty) {
      // Empty result.
      if (op == 'intersect') return a.copyWith(mergeOp: 'intersect_noop');
      return a.copyWith(mergeOp: '${op}_noop');
    }

    // The shape box = bounding box of the actual boolean result (so the
    // intersect box is the overlap region, not the union of the inputs).
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final loop in loops) {
      for (final p in loop) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    final boxW = maxX - minX;
    final boxH = maxY - minY;
    if (boxW <= 0 || boxH <= 0) {
      return a.copyWith(mergeOp: '${op}_noop');
    }

    // Convert absolute loops to local box units (0..boxW / 0..boxH).
    final localLoops = loops
        .map((loop) => loop
            .map((p) => Offset2D(p.dx - minX, p.dy - minY))
            .toList())
        .toList();

    // Normalise winding so holes render correctly with non-zero fill:
    // Greiner–Hormann already orients holes opposite the outer loops for
    // intersecting inputs, but the no-intersection containment fallback
    // (b fully inside a for subtract) returns both loops with the same
    // winding — reverse a loop when it nests inside a *larger* loop
    // (largest loop is the outer shell; comparing only against larger
    // loops avoids mutual-reversal when centroids sit on boundaries).
    final areas = localLoops
        .map((l) => l.length < 3 ? 0.0 : _loopArea(l).abs())
        .toList();
    for (var i = 0; i < localLoops.length; i++) {
      if (localLoops[i].length < 3) continue;
      final c = _centroid(localLoops[i]);
      var insideLarger = false;
      for (var j = 0; j < localLoops.length; j++) {
        if (i == j || localLoops[j].length < 3) continue;
        if (areas[j] > areas[i] && _pointStrictlyInside(c, localLoops[j])) {
          insideLarger = true;
          break;
        }
      }
      if (insideLarger) {
        localLoops[i] = localLoops[i].reversed.toList();
      }
    }

    // Build one SVG path with one subpath per loop (holes carry opposite
    // winding → non-zero fill and even-odd fill both render them correctly).
    final path = StringBuffer();
    for (final loop in localLoops) {
      if (loop.length < 3) continue;
      path.write('M${_fmt(loop.first.dx)},${_fmt(loop.first.dy)} ');
      for (var i = 1; i < loop.length; i++) {
        path.write('L${_fmt(loop[i].dx)},${_fmt(loop[i].dy)} ');
      }
      path.write('Z');
    }

    return DrawnShape(
      id: mergedId,
      type: ShapeType.merged,
      x: minX, y: minY,
      w: boxW, h: boxH,
      fillColor: a.fillColor,
      strokeColor: a.strokeColor,
      strokeWidth: a.strokeWidth,
      fillTransparency: a.fillTransparency,
      freeformPath: path.toString(),
      mergeOp: op,
      mergedIds: [a.id, b.id],
      zOrder: math.min(a.zOrder, b.zOrder),
    );
  }

  /// Absolute-coordinate polygon loops for the boolean op of two shapes.
  static List<List<Offset2D>>? _booleanLoops(
      DrawnShape a, DrawnShape b, String op) {
    final pa = _polygonOf(a);
    final pb = _polygonOf(b);
    if (pa.length < 3 || pb.length < 3) return null;
    switch (op) {
      case 'union':
        return PolygonBoolean.union(pa, pb);
      case 'combine':
        return PolygonBoolean.combine(pa, pb);
      case 'intersect':
        return PolygonBoolean.intersection(pa, pb);
      case 'subtract':
        return PolygonBoolean.difference(pa, pb);
    }
    return null;
  }

  /// Convert a shape to an absolute-coordinate polygon (slide % space).
  /// Rect → 4 corners; oval → 48-gon approximation; freeform/merged → the
  /// parsed path (local box units mapped back to slide %); line/arrow →
  /// its bounding box (lines have no area).
  static List<Offset2D> _polygonOf(DrawnShape s) {
    switch (s.type) {
      case ShapeType.rect:
        return [
          Offset2D(s.x, s.y),
          Offset2D(s.x + s.w, s.y),
          Offset2D(s.x + s.w, s.y + s.h),
          Offset2D(s.x, s.y + s.h),
        ];
      case ShapeType.oval:
        final cx = s.x + s.w / 2, cy = s.y + s.h / 2;
        final rx = s.w / 2, ry = s.h / 2;
        return [
          for (var i = 0; i < 48; i++)
            Offset2D(
              cx + rx * math.cos(2 * math.pi * i / 48),
              cy + ry * math.sin(2 * math.pi * i / 48),
            ),
        ];
      case ShapeType.freeform:
      case ShapeType.merged:
        if (s.freeformPath.isNotEmpty) {
          final pts = _parsePathPoints(s.freeformPath);
          if (pts.length >= 3) {
            // Path points are already in slide-% units (the local box maps
            // 1:1 to slide space), so absolute = shape origin + point.
            return pts
                .map((p) => Offset2D(s.x + p.dx, s.y + p.dy))
                .toList();
          }
        }
        return [
          Offset2D(s.x, s.y),
          Offset2D(s.x + s.w, s.y),
          Offset2D(s.x + s.w, s.y + s.h),
          Offset2D(s.x, s.y + s.h),
        ];
      case ShapeType.line:
      case ShapeType.arrow:
        return [
          Offset2D(s.x, s.y),
          Offset2D(s.x + s.w, s.y),
          Offset2D(s.x + s.w, s.y + s.h),
          Offset2D(s.x, s.y + s.h),
        ];
    }
  }

  /// Parse an SVG path into local-box points (M/L/H/V/C/S/Q/T/Z, abs+rel).
  static List<Offset2D> _parsePathPoints(String pathD) {
    final pts = <Offset2D>[];
    final matches = _cmdRe.allMatches(pathD).toList();
    double cx = 0, cy = 0;
    for (var k = 0; k < matches.length; k++) {
      final cmd = matches[k].group(0)!;
      final startIdx = matches[k].end;
      final endIdx =
          k + 1 < matches.length ? matches[k + 1].start : pathD.length;
      final nums = _numRe
          .allMatches(pathD.substring(startIdx, endIdx))
          .map((m) => double.parse(m.group(0)!))
          .toList();
      final rel = cmd == cmd.toLowerCase();
      switch (cmd.toUpperCase()) {
        case 'M':
          if (nums.length >= 2) {
            cx = rel ? cx + nums[0] : nums[0];
            cy = rel ? cy + nums[1] : nums[1];
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'L':
          for (var n = 0; n + 1 < nums.length; n += 2) {
            cx = rel ? cx + nums[n] : nums[n];
            cy = rel ? cy + nums[n + 1] : nums[n + 1];
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'H':
          for (final v in nums) {
            cx = rel ? cx + v : v;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'V':
          for (final v in nums) {
            cy = rel ? cy + v : v;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'C':
          for (var n = 0; n + 5 < nums.length; n += 6) {
            final x3 = rel ? cx + nums[n + 4] : nums[n + 4];
            final y3 = rel ? cy + nums[n + 5] : nums[n + 5];
            cx = x3; cy = y3;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'S':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x3 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y3 = rel ? cy + nums[n + 3] : nums[n + 3];
            cx = x3; cy = y3;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'Q':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x2 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y2 = rel ? cy + nums[n + 3] : nums[n + 3];
            cx = x2; cy = y2;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'T':
          for (var n = 0; n + 1 < nums.length; n += 2) {
            cx = rel ? cx + nums[n] : nums[n];
            cy = rel ? cy + nums[n + 1] : nums[n + 1];
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'Z':
          break;
      }
    }
    return pts;
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  // ---- Test/debug helpers -------------------------------------------------

  /// Points of a path in local box units (for assertions).
  static List<Offset2D> debugPathPoints(String pathD) =>
      _parsePathPoints(pathD);

  /// Total filled area of all loops of a path in slide-% square units.
  /// Local box units map 1:1 to slide-% because the merged box IS in
  /// slide-% space. Holes carry opposite winding (enforced in
  /// [_mergeBoolean]) so summing signed areas gives the net filled area;
  /// for multi-region results (disjoint union, combine) the winding of the
  /// regions may differ, so sum absolute areas unless a loop nests another.
  static double debugPolygonArea(String pathD, double w, double h) {
    final loops = _splitSubpaths(pathD);
    final areas = loops.map((l) => l.length < 3 ? 0.0 : _loopArea(l).abs()).toList();
    double total = 0;
    for (var i = 0; i < loops.length; i++) {
      final pts = loops[i];
      if (pts.length < 3) continue;
      // Hole (nested inside a larger loop) → subtract, else add.
      final c = _centroid(pts);
      var insideLarger = false;
      for (var j = 0; j < loops.length; j++) {
        if (i == j || loops[j].length < 3) continue;
        if (areas[j] > areas[i] && _pointStrictlyInside(c, loops[j])) {
          insideLarger = true;
          break;
        }
      }
      total += insideLarger ? -areas[i] : areas[i];
    }
    return total.abs();
  }

  static double _loopArea(List<Offset2D> pts) {
    double a = 0;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = pts[(i + 1) % pts.length];
      a += p.dx * q.dy - q.dx * p.dy;
    }
    return a / 2;
  }

  static Offset2D _centroid(List<Offset2D> pts) {
    var sx = 0.0, sy = 0.0;
    for (final p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset2D(sx / pts.length, sy / pts.length);
  }

  static bool _pointStrictlyInside(Offset2D p, List<Offset2D> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final pi = poly[i], pj = poly[j];
      final intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx <
              (pj.dx - pi.dx) * (p.dy - pi.dy) /
                      (pj.dy - pi.dy) +
                  pi.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Split a path into its subpath point lists (each starts at M/m).
  static List<List<Offset2D>> _splitSubpaths(String pathD) {
    final matches = _cmdRe.allMatches(pathD).toList();
    final starts = <int>[];
    for (var k = 0; k < matches.length; k++) {
      if (matches[k].group(0) == 'M' || matches[k].group(0) == 'm') {
        starts.add(k);
      }
    }
    if (starts.isEmpty) return const [];
    final out = <List<Offset2D>>[];
    for (var s = 0; s < starts.length; s++) {
      final startK = starts[s];
      final endK = s + 1 < starts.length ? starts[s + 1] : matches.length;
      final sub = pathD.substring(
          matches[startK].start,
          endK < matches.length ? matches[endK].start : pathD.length);
      out.add(_parsePathPoints(sub));
    }
    return out;
  }
}