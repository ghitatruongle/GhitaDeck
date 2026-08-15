/// A positioned editable element (shape or text box) in slide % coordinates.
/// Alignment operates on this minimal interface so both `DrawnShape` and
/// `FreeTextShape` (and any future element) can be aligned uniformly.
class Alignable {
  final String id;
  final double x, y, w, h;

  const Alignable({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Alignable copyWith({double? x, double? y}) => Alignable(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w,
        h: h,
      );
}

enum AlignKind { left, centerH, right, top, middle, bottom }

enum DistributeKind { horizontal, vertical }

/// Pure geometry for alignment, distribution, smart guides and snapping
/// (Track 27). All coordinates are in slide-relative % (0–100).
class AlignmentService {
  AlignmentService._();

  /// Align [items] against the slide box (0..100) or, when [relativeTo]
  /// is non-null, against that selection's bounding box.
  static List<Alignable> align(
    List<Alignable> items, {
    required AlignKind kind,
    Alignable? relativeTo,
  }) {
    if (items.isEmpty) return items;
    double targetX = 0, targetY = 0;
    if (relativeTo != null) {
      switch (kind) {
        case AlignKind.left:
          targetX = relativeTo.x;
        case AlignKind.centerH:
          targetX = relativeTo.x + relativeTo.w / 2;
        case AlignKind.right:
          targetX = relativeTo.x + relativeTo.w;
        case AlignKind.top:
          targetY = relativeTo.y;
        case AlignKind.middle:
          targetY = relativeTo.y + relativeTo.h / 2;
        case AlignKind.bottom:
          targetY = relativeTo.y + relativeTo.h;
      }
    } else {
      switch (kind) {
        case AlignKind.left:
          targetX = 0;
        case AlignKind.centerH:
          targetX = 50;
        case AlignKind.right:
          targetX = 100;
        case AlignKind.top:
          targetY = 0;
        case AlignKind.middle:
          targetY = 50;
        case AlignKind.bottom:
          targetY = 100;
      }
    }
    return [
      for (final it in items)
        it.copyWith(
          x: switch (kind) {
            AlignKind.left ||
            AlignKind.centerH ||
            AlignKind.right =>
              targetX - (kind == AlignKind.left
                  ? 0
                  : kind == AlignKind.centerH
                      ? it.w / 2
                      : it.w),
            _ => it.x,
          },
          y: switch (kind) {
            AlignKind.top ||
            AlignKind.middle ||
            AlignKind.bottom =>
              targetY - (kind == AlignKind.top
                  ? 0
                  : kind == AlignKind.middle
                      ? it.h / 2
                      : it.h),
            _ => it.y,
          },
        ),
    ];
  }

  /// Distribute [items] evenly along the horizontal or vertical axis,
  /// keeping the first and last item fixed. Items should already be sorted
  /// along the axis.
  static List<Alignable> distribute(
    List<Alignable> items, {
    required DistributeKind kind,
  }) {
    if (items.length < 3) return items;
    final sorted = List<Alignable>.of(items)
      ..sort((a, b) => kind == DistributeKind.horizontal
          ? a.x.compareTo(b.x)
          : a.y.compareTo(b.y));
    final first = sorted.first;
    final last = sorted.last;
    final span = kind == DistributeKind.horizontal
        ? last.x - first.x
        : last.y - first.y;
    final gap = span / (sorted.length - 1);
    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(
          x: kind == DistributeKind.horizontal ? first.x + gap * i : sorted[i].x,
          y: kind == DistributeKind.vertical ? first.y + gap * i : sorted[i].y,
        ),
    ];
  }

  /// Find the nearest snap position when dragging [item] by (dx, dy).
  /// Returns null when nothing is within the snap threshold.
  /// [others] are the other elements on the slide; the slide edges/centre
  /// and any user guides are always candidates. When [snapToShape] is false
  /// only slide guides participate.
  static ({double x, double y})? snapPosition(
    Alignable item,
    double dx,
    double dy, {
    required List<Alignable> others,
    List<double> userGuidesX = const [],
    List<double> userGuidesY = const [],
    bool snapGrid = false,
    double gridSize = 5,
    bool snapToShape = true,
  }) {
    final movedX = item.x + dx;
    final movedY = item.y + dy;

    // One candidate set per axis: every element's left/right/centre (or
    // top/bottom/middle), the slide edges + centre, and user guides.
    final xs = <double>{0, 50, 100, ...userGuidesX};
    final ys = <double>{0, 50, 100, ...userGuidesY};
    if (snapToShape) {
      for (final o in others) {
        xs.addAll([o.x, o.x + o.w, o.x + o.w / 2]);
        ys.addAll([o.y, o.y + o.h, o.y + o.h / 2]);
      }
    }

    // Snap the closest of the three anchors to its nearest candidate.
    double? snapAxis(double low, double mid, double high, double size, Set<double> cs) {
      var bestPos = 0.0;
      var bestDist = double.infinity;
      double? bestAnchor;
      for (final anchor in [low, mid, high]) {
        for (final c in cs) {
          final d = (anchor - c).abs();
          if (d < bestDist) {
            bestDist = d;
            bestPos = c;
            bestAnchor = anchor;
          }
        }
      }
      const threshold = 3.0; // % — within 3% of a guide, snap
      if (bestAnchor == null || bestDist > threshold) return null;
      return bestPos - (bestAnchor - low);
    }

    final outX = snapAxis(movedX, movedX + item.w / 2, movedX + item.w, item.w, xs);
    final outY = snapAxis(movedY, movedY + item.h / 2, movedY + item.h, item.h, ys);
    var snapped = outX != null || outY != null;

    if (snapGrid && !snapped) {
      // Snap the top-left corner to the grid when no guide is closer.
      final gx = (movedX / gridSize).roundToDouble() * gridSize;
      final gy = (movedY / gridSize).roundToDouble() * gridSize;
      if ((movedX - gx).abs() <= 2.0 || (movedY - gy).abs() <= 2.0) {
        return (x: gx, y: gy);
      }
    }
    if (!snapped) return null;
    return (x: outX ?? movedX, y: outY ?? movedY);
  }

  /// Ruler tick marks: returns major tick positions (every [major] units)
  /// for a ruler of length [lengthPx] scaled by [scale] (px per % unit).
  static List<int> rulerTicks({required double lengthPx, required double scale, double major = 50}) {
    final ticks = <int>[];
    final step = (major * scale).round();
    if (step <= 0) return ticks;
    for (var px = 0; px <= lengthPx; px += step) {
      ticks.add(px);
    }
    return ticks;
  }

  /// Compute the union bounding box of [items] (for "align to selection").
  static Alignable bboxOf(List<Alignable> items) {
    var minX = 100.0, minY = 100.0, maxX = 0.0, maxY = 0.0;
    for (final it in items) {
      if (it.x < minX) minX = it.x;
      if (it.y < minY) minY = it.y;
      if (it.x + it.w > maxX) maxX = it.x + it.w;
      if (it.y + it.h > maxY) maxY = it.y + it.h;
    }
    return Alignable(id: '_bbox', x: minX, y: minY, w: maxX - minX, h: maxY - minY);
  }
}
