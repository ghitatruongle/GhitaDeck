/// Drawn shape model (Track 21, FEAT 25, 26).
///
/// Represents a preset shape (rect, oval, line, arrow, freeform) or a merged
/// shape. Stored in `Slide.visualElements['shapes']` and rendered by the
/// PPTX/HTML/PDF exporters.
library;

import 'dart:convert';
import 'shape_effect.dart';

enum ShapeType { rect, oval, line, arrow, freeform, merged }

class DrawnShape {
  const DrawnShape({
    this.id = '',
    this.type = ShapeType.rect,
    this.x = 0.0,
    this.y = 0.0,
    this.w = 20.0,
    this.h = 15.0,
    this.rotation = 0.0,
    this.zOrder = 0,
    this.fillColor = '#4472C4',
    this.fillTransparency = 0.0, // 0.0 – 1.0
    this.strokeColor = '#000000',
    this.strokeWidth = 1.0,
    this.freeformPath = '', // SVG path d for freeform/merged shapes
    this.mergeOp = '', // union | combine | intersect | subtract
    this.mergedIds = const [], // source shape IDs
    this.gradientStart = '', // e.g. '#FF8A00' — empty = solid fill
    this.gradientEnd = '', // e.g. '#E52E71'
    this.gradientAngle = 0.0, // degrees, 0 = left→right
    this.effect = ShapeEffect.none, // Track 25: shadow/glow/reflection/bevel
  });

  final String id;
  final ShapeType type;
  final double x, y, w, h; // % of slide
  final double rotation;
  final int zOrder;
  final String fillColor;
  final double fillTransparency;
  final String strokeColor;
  final double strokeWidth;
  final String freeformPath;
  final String mergeOp;
  final List<String> mergedIds;

  /// Linear gradient fill (Track 21, P7). Empty start = no gradient.
  final String gradientStart;
  final String gradientEnd;
  final double gradientAngle;

  /// Shape & text effects (Track 25): shadow, glow, reflection, soft edge,
  /// bevel, 3D rotation.
  final ShapeEffect effect;

  /// OOXML preset geometry name for the shape type.
  String get pptxPresetGeom {
    switch (type) {
      case ShapeType.rect: return 'rect';
      case ShapeType.oval: return 'ellipse';
      case ShapeType.line: return 'line';
      case ShapeType.arrow: return 'rightArrow';
      case ShapeType.freeform: return 'freeform';
      case ShapeType.merged: return 'rect';
    }
  }

  DrawnShape copyWith({
    String? id,
    ShapeType? type,
    double? x, double? y, double? w, double? h,
    double? rotation, int? zOrder,
    String? fillColor, double? fillTransparency,
    String? strokeColor, double? strokeWidth,
    String? freeformPath, String? mergeOp,
    List<String>? mergedIds,
    String? gradientStart, String? gradientEnd, double? gradientAngle,
    ShapeEffect? effect,
  }) => DrawnShape(
    id: id ?? this.id,
    type: type ?? this.type,
    x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h,
    rotation: rotation ?? this.rotation,
    zOrder: zOrder ?? this.zOrder,
    fillColor: fillColor ?? this.fillColor,
    fillTransparency: fillTransparency ?? this.fillTransparency,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    freeformPath: freeformPath ?? this.freeformPath,
    mergeOp: mergeOp ?? this.mergeOp,
    mergedIds: mergedIds ?? this.mergedIds,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    gradientAngle: gradientAngle ?? this.gradientAngle,
    effect: effect ?? this.effect,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'x': x, 'y': y, 'w': w, 'h': h,
    if (rotation != 0.0) 'rotation': rotation,
    if (zOrder != 0) 'zOrder': zOrder,
    if (fillColor != '#4472C4') 'fillColor': fillColor,
    if (fillTransparency != 0.0) 'fillTransparency': fillTransparency,
    if (strokeColor != '#000000') 'strokeColor': strokeColor,
    if (strokeWidth != 1.0) 'strokeWidth': strokeWidth,
    if (freeformPath.isNotEmpty) 'freeformPath': freeformPath,
    if (mergeOp.isNotEmpty) 'mergeOp': mergeOp,
    if (mergedIds.isNotEmpty) 'mergedIds': mergedIds,
    if (gradientStart.isNotEmpty) 'gradientStart': gradientStart,
    if (gradientEnd.isNotEmpty) 'gradientEnd': gradientEnd,
    if (gradientAngle != 0.0) 'gradientAngle': gradientAngle,
    if (!effect.isEmpty) 'effect': effect.toMap(),
  };

  static DrawnShape fromMap(Map<String, dynamic> map) => DrawnShape(
    id: map['id']?.toString() ?? '',
    type: ShapeType.values.asNameMap()[map['type']] ?? ShapeType.rect,
    x: (map['x'] as num?)?.toDouble() ?? 0.0,
    y: (map['y'] as num?)?.toDouble() ?? 0.0,
    w: (map['w'] as num?)?.toDouble() ?? 20.0,
    h: (map['h'] as num?)?.toDouble() ?? 15.0,
    rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
    zOrder: (map['zOrder'] as num?)?.toInt() ?? 0,
    fillColor: map['fillColor']?.toString() ?? '#4472C4',
    fillTransparency: (map['fillTransparency'] as num?)?.toDouble() ?? 0.0,
    strokeColor: map['strokeColor']?.toString() ?? '#000000',
    strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 1.0,
    freeformPath: map['freeformPath']?.toString() ?? '',
    mergeOp: map['mergeOp']?.toString() ?? '',
    mergedIds: map['mergedIds'] is List
        ? List<String>.from(map['mergedIds'] as List)
        : [],
    gradientStart: map['gradientStart']?.toString() ?? '',
    gradientEnd: map['gradientEnd']?.toString() ?? '',
    gradientAngle: (map['gradientAngle'] as num?)?.toDouble() ?? 0.0,
    effect: ShapeEffect.fromMap(map['effect']),
  );

  String toJson() => jsonEncode(toMap());

  static DrawnShape fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const DrawnShape();
      return fromMap(map);
    } catch (_) {
      return const DrawnShape();
    }
  }

  /// SVG markup for HTML/PDF rendering.
  String get svgMarkup {
    final hasGrad = gradientStart.isNotEmpty && gradientEnd.isNotEmpty;
    final fill = hasGrad ? 'url(#grad${id.hashCode.abs()})' : fillColor;
    final fillOpacity = 1.0 - fillTransparency;
    final stroke = strokeColor;
    final sw = strokeWidth;
    final wSvg = w, hSvg = h;
    final gradDef = hasGrad
        ? '<defs><linearGradient id="grad${id.hashCode.abs()}" '
            'x1="0" y1="0" x2="1" y2="0" '
            'gradientTransform="rotate($gradientAngle 0.5 0.5)">'
            '<stop offset="0%" stop-color="$gradientStart"/>'
            '<stop offset="100%" stop-color="$gradientEnd"/>'
            '</linearGradient></defs>'
        : '';
    String svgEl;
    switch (type) {
      case ShapeType.rect:
        svgEl = '<rect x="0" y="0" width="$wSvg" height="$hSvg" rx="1" ry="1" '
            'fill="$fill" fill-opacity="$fillOpacity" '
            'stroke="$stroke" stroke-width="$sw"/>';
        break;
      case ShapeType.oval:
        final cx = wSvg / 2, cy = hSvg / 2, rx = wSvg / 2, ry = hSvg / 2;
        svgEl = '<ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" '
            'fill="$fill" fill-opacity="$fillOpacity" '
            'stroke="$stroke" stroke-width="$sw"/>';
        break;
      case ShapeType.line:
        svgEl = '<line x1="0" y1="$hSvg" x2="$wSvg" y2="0" '
            'stroke="$stroke" stroke-width="$sw"/>';
        break;
      case ShapeType.arrow:
        svgEl = '<polygon points="0,0 $wSvg,${hSvg / 2} 0,$hSvg" '
            'fill="$fill" fill-opacity="$fillOpacity" '
            'stroke="$stroke" stroke-width="$sw"/>';
        break;
      case ShapeType.freeform:
      case ShapeType.merged:
        if (freeformPath.isNotEmpty) {
          svgEl = '<path d="$freeformPath" '
              'fill="$fill" fill-opacity="$fillOpacity" '
              'stroke="$stroke" stroke-width="$sw"/>';
        } else {
          svgEl = '<rect x="0" y="0" width="$wSvg" height="$hSvg" '
              'fill="$fill" fill-opacity="$fillOpacity" '
              'stroke="$stroke" stroke-width="$sw"/>';
        }
        break;
    }
    // Track 25: effects (drop-shadow / glow / soft edge) as an SVG filter.
    final fxId = 'fx${id.hashCode.abs()}';
    final hasShadowFx = effect.shadow;
    final hasGlowFx = effect.glow;
    final hasSoftFx = effect.softEdge > 0;
    var filterAttr = '';
    var filterDef = '';
    if (hasShadowFx || hasGlowFx || hasSoftFx) {
      final fxs = <String>[];
      if (hasShadowFx) {
        fxs.add('<feDropShadow dx="${(effect.shadowOffsetX * wSvg / 100).toStringAsFixed(1)}" '
            'dy="${(effect.shadowOffsetY * hSvg / 100).toStringAsFixed(1)}" '
            'stdDeviation="${(effect.shadowBlur * wSvg / 200).toStringAsFixed(1)}" '
            'flood-color="${effect.shadowColor}" '
            'flood-opacity="${effect.shadowAlpha.toStringAsFixed(2)}"/>');
      }
      if (hasGlowFx) {
        fxs.add('<feDropShadow dx="0" dy="0" '
            'stdDeviation="${(effect.glowSize * wSvg / 200).toStringAsFixed(1)}" '
            'flood-color="${effect.glowColor}" flood-opacity="0.8"/>');
      }
      if (hasSoftFx) {
        fxs.add('<feGaussianBlur stdDeviation="${(effect.softEdge * wSvg / 200).toStringAsFixed(1)}"/>');
      }
      filterDef = '<filter id="$fxId" x="-50%" y="-50%" width="200%" height="200%">${fxs.join()}</filter>';
      filterAttr = ' filter="url(#$fxId)"';
    }
    // The filter is attached to the *element* (feDropShadow must run after
    // the geometry); add the reference to the SVG root when effects exist.
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $wSvg $hSvg" '
        'width="$wSvg" height="$hSvg"$filterAttr>$gradDef$filterDef$svgEl</svg>';
  }

  /// HTML markup for the app preview / HTML deck.
  String get htmlMarkup {
    final rot = rotation != 0 ? 'transform: rotate(${rotation}deg);' : '';
    final fxCss = effect.toCss(wPercent: w, hPercent: h);
    return '<div data-shape-html data-ghita-id="sh_$id" style="position:absolute; '
        'left:$x%; top:$y%; width:$w%; height:$h%; $rot $fxCss; overflow:hidden;">'
        '$svgMarkup</div>';
  }

  // ---- Edit Points support (Track 21, P5) --------------------------------

  /// Parse the freeform path into anchor points (relative 0..1 within the
  /// shape box — the same space the Edit Points dialog and
  /// [pathFromPoints] use, so editing keeps geometry). Supports M/L/H/V
  /// *and bézier* C/S/Q/T (absolute + lowercase): each curve contributes
  /// its end point as an anchor. Empty path returns the four corners.
  List<Offset2D> get anchorPoints {
    final pts = <Offset2D>[];
    if (freeformPath.isEmpty) {
      return [
        const Offset2D(0, 0), const Offset2D(1, 0),
        const Offset2D(1, 1), const Offset2D(0, 1),
      ];
    }
    final numRe = RegExp(r'[-+]?[0-9]*\.?[0-9]+');
    final cmdRe = RegExp(r'[MmLlHhVvCcSsQqTtZz]');
    final matches = cmdRe.allMatches(freeformPath).toList();
    double cx = 0, cy = 0;
    for (var k = 0; k < matches.length; k++) {
      final cmd = matches[k].group(0)!;
      final startIdx = matches[k].end;
      final endIdx = k + 1 < matches.length ? matches[k + 1].start : freeformPath.length;
      final nums = numRe.allMatches(freeformPath.substring(startIdx, endIdx))
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
            cx = x3;
            cy = y3;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'S':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x3 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y3 = rel ? cy + nums[n + 3] : nums[n + 3];
            cx = x3;
            cy = y3;
            pts.add(Offset2D(cx, cy));
          }
          break;
        case 'Q':
          for (var n = 0; n + 3 < nums.length; n += 4) {
            final x2 = rel ? cx + nums[n + 2] : nums[n + 2];
            final y2 = rel ? cy + nums[n + 3] : nums[n + 3];
            cx = x2;
            cy = y2;
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
    // Normalise to 0..1 relative (path coords are local box units 0..w/h).
    final wNorm = w == 0 ? 1.0 : w;
    final hNorm = h == 0 ? 1.0 : h;
    return [
      for (final p in pts) Offset2D(p.dx / wNorm, p.dy / hNorm),
    ];
  }

  /// Serialize anchor points (relative 0..1) back into an SVG path `d`
  /// (absolute M/L commands scaled to [w]x[h]).
  static String pathFromPoints(List<Offset2D> points, {double w = 100, double h = 100}) {
    if (points.isEmpty) return '';
    final b = StringBuffer();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.dx * w).toStringAsFixed(1);
      final y = (p.dy * h).toStringAsFixed(1);
      b.write(i == 0 ? 'M$x,$y ' : 'L$x,$y ');
    }
    b.write('Z');
    return b.toString();
  }

  /// Create a copy with updated anchor points (absolute values are
  /// normalized to the shape's w/h).
  DrawnShape withAnchors(List<Offset2D> points) {
    if (type != ShapeType.freeform && type != ShapeType.merged) {
      // Convert preset shapes to a freeform with the same outline.
      return copyWith(
        type: ShapeType.freeform,
        freeformPath: DrawnShape.pathFromPoints(points, w: w, h: h),
      );
    }
    return copyWith(
      freeformPath: DrawnShape.pathFromPoints(points, w: w, h: h),
    );
  }
}

/// A 2D point (relative 0..1 within a shape's box).
class Offset2D {
  const Offset2D(this.dx, this.dy);
  final double dx;
  final double dy;

  Offset2D copyWith({double? dx, double? dy}) =>
      Offset2D(dx ?? this.dx, dy ?? this.dy);
}