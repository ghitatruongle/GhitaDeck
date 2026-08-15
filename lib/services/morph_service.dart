import '../models/drawn_shape.dart';
import '../models/free_shape.dart';

/// Morph engine (Track 34, FEAT 51): compares two consecutive slides,
/// matches shapes by id/name/z-order/type, and generates the FLIP CSS the
/// HTML player uses to transition, plus the `<p14:morph>` PPTX transition.
class MorphService {
  MorphService._();

  /// Hard cap on matched shapes per morph so the animation stays smooth.
  static const int maxMorphShapes = 20;

  /// A matched pair: same logical element on the previous and next slide.
  static ({DrawnShape prev, DrawnShape next})? matchShape(
    DrawnShape prev,
    DrawnShape next,
  ) {
    if (prev.id == next.id) return (prev: prev, next: next);
    if (prev.type == next.type) {
      // Same type + similar size → treat as the same element.
      final wRatio = prev.w == 0 ? 0 : (next.w / prev.w).clamp(0.5, 2.0);
      final hRatio = prev.h == 0 ? 0 : (next.h / prev.h).clamp(0.5, 2.0);
      if (wRatio > 0 && hRatio > 0) return (prev: prev, next: next);
    }
    return null;
  }

  /// Match the drawn shapes of [prev] and [next] (both as raw visual-element
  /// lists). Returns at most [maxMorphShapes] pairs, ordered by z-order.
  static List<({DrawnShape prev, DrawnShape next})> match(
    List<DrawnShape> prevShapes,
    List<DrawnShape> nextShapes,
  ) {
    final prevSorted = List<DrawnShape>.of(prevShapes)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    final nextSorted = List<DrawnShape>.of(nextShapes)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));

    final pairs = <({DrawnShape prev, DrawnShape next})>[];
    final used = <String>{};

    // 1. Exact id matches first.
    for (final next in nextSorted) {
      for (final prev in prevSorted) {
        if (used.contains(next.id)) break;
        if (prev.id == next.id) {
          pairs.add((prev: prev, next: next));
          used.add(next.id);
          break;
        }
      }
    }
    // 2. Type + size matches for the rest.
    for (final next in nextSorted) {
      if (used.contains(next.id)) continue;
      for (final prev in prevSorted) {
        if (pairs.any((p) => p.prev.id == prev.id)) continue;
        final m = matchShape(prev, next);
        if (m != null) {
          pairs.add(m);
          used.add(next.id);
          break;
        }
      }
    }
    return pairs.take(maxMorphShapes).toList();
  }

  /// FLIP keyframes for one morph pair. [scaleW]/[scaleH] convert the % coords
  /// into px for the CSS translate/scale (both slides share the same canvas).
  static String flipKeyframes({
    required String name,
    required DrawnShape prev,
    required DrawnShape next,
    required double scaleW,
    required double scaleH,
  }) {
    // First frame = where the element sits on the previous slide.
    final prevX = prev.x * scaleW;
    final prevY = prev.y * scaleH;
    final prevW = prev.w * scaleW;
    final prevH = prev.h * scaleH;
    final nextX = next.x * scaleW;
    final nextY = next.y * scaleH;
    final nextW = next.w * scaleW;
    final nextH = next.h * scaleH;

    final scaleX = prevW == 0 ? 1.0 : nextW / prevW;
    final scaleY = prevH == 0 ? 1.0 : nextH / prevH;

    return '''
@keyframes $name {
  0% {
    transform: translate(${_f(prevX - nextX)}px, ${_f(prevY - nextY)}px) scale(${_f(scaleX)}, ${_f(scaleY)});
    transform-origin: 0 0;
  }
  100% {
    transform: translate(0, 0) scale(1, 1);
    transform-origin: 0 0;
  }
}''';
  }

  static String _f(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  /// Full morph CSS block for [pairs]. [duration] in seconds.
  static String cssFor(
    List<({DrawnShape prev, DrawnShape next})> pairs, {
    double duration = 0.6,
    double slideWidthPx = 960,
    double slideHeightPx = 540,
  }) {
    final buf = StringBuffer();
    for (var i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      final name = 'ghita-morph-$i';
      buf.writeln(flipKeyframes(
        name: name,
        prev: p.prev,
        next: p.next,
        scaleW: slideWidthPx / 100,
        scaleH: slideHeightPx / 100,
      ));
      final dur = duration == duration.roundToDouble()
          ? duration.round().toString()
          : duration.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
      buf.writeln(
        '[data-ghita-id="sh_${p.next.id}"] { '
        'animation: $name ${dur}s ease forwards; }',
      );
    }
    return buf.toString();
  }

  /// PPTX morph transition XML (PowerPoint 2016+ p14:morph). Returns '' when
  /// [enabled] is false (fallback: no morph, PowerPoint uses default).
  static String pptxTransition({required bool enabled, int? durationMs}) {
    if (!enabled) return '';
    final spd = switch (durationMs) {
      null || < 300 => 'fast',
      > 2000 => 'slow',
      _ => 'med',
    };
    return '<p:transition spd="$spd" advClick="1" '
        'xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main">'
        '<p14:morph/>'
        '</p:transition>';
  }
}

/// Adapter so [MorphService.match] can be fed straight from slide maps.
extension MorphVisualElements on Map<String, dynamic> {
  List<DrawnShape> drawnShapes() {
    final raw = this['shapes'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map<String, dynamic>
            ? DrawnShape.fromMap(e)
            : (e is Map
                ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<DrawnShape>()
        .toList();
  }

  List<FreeTextShape> freeTexts() {
    final raw = this['freeTexts'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map<String, dynamic>
            ? FreeTextShape.fromMap(e)
            : (e is Map
                ? FreeTextShape.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<FreeTextShape>()
        .toList();
  }
}
