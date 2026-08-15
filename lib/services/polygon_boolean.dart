/// Boolean operations on simple polygons (Track 21, P3).
///
/// Port of the Greiner–Hormann clipping algorithm from the reference
/// implementation (w8r/GreinerHormann, MIT licence) so merge shapes get a
/// *real* boolean result (union / intersection / difference / combine =
/// XOR) instead of a bounding box. Polygons are lists of [Offset2D] points
/// in any consistent coordinate space (slide-%, EMU, px …). Each result is
/// a list of closed loops (a loop is a list of points; holes are separate
/// loops with reversed winding, use even-odd fill when rendering).
library;

import '../models/drawn_shape.dart';

class _Vertex {
  _Vertex(this.x, this.y);

  final double x;
  final double y;
  _Vertex? next;
  _Vertex? prev;
  _Vertex? corresponding;
  double distance = 0;
  bool isEntry = true;
  bool isIntersection = false;
  bool visited = false;

  _Vertex.createIntersection(this.x, this.y, this.distance) {
    isIntersection = true;
    isEntry = false;
  }

  /// Mark this vertex (and its counterpart) as visited.
  void visit() {
    visited = true;
    final corr = corresponding;
    if (corr != null && !corr.visited) corr.visit();
  }

  bool equals(_Vertex v) => x == v.x && y == v.y;

  /// Odd-even ray casting test against another polygon.
  bool isInside(_Polygon poly) {
    var oddNodes = false;
    var vertex = poly.first;
    var next = vertex?.next;
    final px = x;
    final py = y;
    do {
      if (vertex == null || next == null) break;
      if (((vertex.y < py && next.y >= py) || (next.y < py && vertex.y >= py)) &&
          (vertex.x <= px || next.x <= px)) {
        if (vertex.x +
                ((py - vertex.y) / (next.y - vertex.y)) * (next.x - vertex.x) <
            px) {
          oddNodes = !oddNodes;
        }
      }
      vertex = vertex.next;
      next = vertex?.next ?? poly.first;
    } while (vertex != null && !vertex.equals(poly.first!));
    return oddNodes;
  }
}

class _Polygon {
  _Vertex? first;
  int vertices = 0;
  _Vertex? _lastUnprocessed;
  _Vertex? _firstIntersect;

  _Polygon(List<Offset2D> pts) {
    for (final p in pts) {
      addVertex(_Vertex(p.dx, p.dy));
    }
  }

  _Polygon._empty();

  void addVertex(_Vertex vertex) {
    if (first == null) {
      first = vertex;
      first!.next = vertex;
      first!.prev = vertex;
    } else {
      final next = first!;
      final prev = next.prev!;
      next.prev = vertex;
      vertex.next = next;
      vertex.prev = prev;
      prev.next = vertex;
    }
    vertices++;
  }

  /// Insert [vertex] between [start] and [end], sorted by distance.
  void insertVertex(_Vertex vertex, _Vertex start, _Vertex end) {
    var curr = start;
    while (!curr.equals(end) && curr.distance < vertex.distance) {
      curr = curr.next!;
    }
    vertex.next = curr;
    final prev = curr.prev!;
    vertex.prev = prev;
    prev.next = vertex;
    curr.prev = vertex;
    vertices++;
  }

  /// Next non-intersection point after [v].
  _Vertex getNext(_Vertex v) {
    var c = v;
    while (c.isIntersection) {
      c = c.next!;
    }
    return c;
  }

  _Vertex getFirstIntersect() {
    var v = _firstIntersect ?? first!;
    do {
      if (v.isIntersection && !v.visited) break;
      v = v.next!;
    } while (!v.equals(first!));
    _firstIntersect = v;
    return v;
  }

  bool hasUnprocessed() {
    var v = _lastUnprocessed ?? first!;
    do {
      if (v.isIntersection && !v.visited) {
        _lastUnprocessed = v;
        return true;
      }
      v = v.next!;
    } while (!v.equals(first!));
    _lastUnprocessed = null;
    return false;
  }

  List<Offset2D> getPoints() {
    final pts = <Offset2D>[];
    var v = first!;
    do {
      pts.add(Offset2D(v.x, v.y));
      v = v.next!;
    } while (v != first);
    return pts;
  }

  /// Core clip driver (Greiner–Hormann phase 1–3).
  ///
  /// [sourceForwards]/[clipForwards]: intersection = (true, true),
  /// union = (false, false), difference = (false, true).
  List<List<Offset2D>>? clip(_Polygon clip, bool sourceForwards, bool clipForwards) {
    final isUnion = !sourceForwards && !clipForwards;
    final isIntersection = sourceForwards && clipForwards;
    var sourceVertex = first!;
    var clipVertex = clip.first!;
    // ---- Phase 1: find & insert intersection points --------------------
    do {
      if (!sourceVertex.isIntersection) {
        do {
          if (!clipVertex.isIntersection) {
            final i = _intersection(
              sourceVertex,
              getNext(sourceVertex.next!),
              clipVertex,
              clip.getNext(clipVertex.next!),
            );
            if (i != null) {
              final src = _Vertex.createIntersection(i.$1, i.$2, i.$3);
              final clp = _Vertex.createIntersection(i.$1, i.$2, i.$4);
              src.corresponding = clp;
              clp.corresponding = src;
              insertVertex(src, sourceVertex, getNext(sourceVertex.next!));
              clip.insertVertex(clp, clipVertex, clip.getNext(clipVertex.next!));
            }
          }
          clipVertex = clipVertex.next!;
        } while (!clipVertex.equals(clip.first!));
      }
      sourceVertex = sourceVertex.next!;
    } while (!sourceVertex.equals(first!));

    // ---- Phase 2: entry/exit classification ----------------------------
    sourceVertex = first!;
    clipVertex = clip.first!;
    var sourceInClip = sourceVertex.isInside(clip);
    var clipInSource = clipVertex.isInside(this);
    sourceForwards = sourceForwards != sourceInClip;
    clipForwards = clipForwards != clipInSource;
    do {
      if (sourceVertex.isIntersection) {
        sourceVertex.isEntry = sourceForwards;
        sourceForwards = !sourceForwards;
      }
      sourceVertex = sourceVertex.next!;
    } while (!sourceVertex.equals(first!));
    do {
      if (clipVertex.isIntersection) {
        clipVertex.isEntry = clipForwards;
        clipForwards = !clipForwards;
      }
      clipVertex = clipVertex.next!;
    } while (!clipVertex.equals(clip.first!));

    // ---- Phase 3: walk the clipped boundaries ---------------------------
    final list = <List<Offset2D>>[];
    while (hasUnprocessed()) {
      var current = getFirstIntersect();
      final clipped = _Polygon._empty();
      clipped.addVertex(_Vertex(current.x, current.y));
      do {
        current.visit();
        if (current.isEntry) {
          do {
            current = current.next!;
            clipped.addVertex(_Vertex(current.x, current.y));
          } while (!current.isIntersection);
        } else {
          do {
            current = current.prev!;
            clipped.addVertex(_Vertex(current.x, current.y));
          } while (!current.isIntersection);
        }
        current = current.corresponding!;
      } while (!current.visited);
      list.add(clipped.getPoints());
    }

    if (list.isEmpty) {
      if (isUnion) {
        if (sourceInClip) {
          list.add(clip.getPoints());
        } else if (clipInSource) {
          list.add(getPoints());
        } else {
          list
            ..add(getPoints())
            ..add(clip.getPoints());
        }
      } else if (isIntersection) {
        if (sourceInClip) {
          list.add(getPoints());
        } else if (clipInSource) {
          list.add(clip.getPoints());
        }
      } else {
        // difference
        if (sourceInClip) {
          list
            ..add(clip.getPoints())
            ..add(getPoints());
        } else if (clipInSource) {
          list
            ..add(getPoints())
            ..add(clip.getPoints());
        } else {
          list.add(getPoints());
        }
      }
    }
    return list.isEmpty ? null : list;
  }
}

/// Line-segment intersection (returns (x, y, toSource, toClip) or null).
(double, double, double, double)? _intersection(
    _Vertex s1, _Vertex s2, _Vertex c1, _Vertex c2) {
  final d = (c2.y - c1.y) * (s2.x - s1.x) - (c2.x - c1.x) * (s2.y - s1.y);
  if (d == 0) return null;
  final toSource =
      ((c2.x - c1.x) * (s1.y - c1.y) - (c2.y - c1.y) * (s1.x - c1.x)) / d;
  final toClip =
      ((s2.x - s1.x) * (s1.y - c1.y) - (s2.y - s1.y) * (s1.x - c1.x)) / d;
  if (toSource <= 0 || toSource >= 1 || toClip <= 0 || toClip >= 1) return null;
  return (
    s1.x + toSource * (s2.x - s1.x),
    s1.y + toSource * (s2.y - s1.y),
    toSource,
    toClip,
  );
}

/// Public boolean API. Each operation returns loops (or null when empty).
class PolygonBoolean {
  PolygonBoolean._();

  /// A ∪ B
  static List<List<Offset2D>>? union(List<Offset2D> a, List<Offset2D> b) =>
      _run(a, b, false, false);

  /// A ∩ B
  static List<List<Offset2D>>? intersection(
          List<Offset2D> a, List<Offset2D> b) =>
      _run(a, b, true, true);

  /// A − B
  static List<List<Offset2D>>? difference(
          List<Offset2D> a, List<Offset2D> b) =>
      _run(a, b, false, true);

  /// A ⊕ B (combine = XOR): (A − B) ∪ (B − A).
  static List<List<Offset2D>>? combine(List<Offset2D> a, List<Offset2D> b) {
    final ab = _run(a, b, false, true);
    final ba = _run(b, a, false, true);
    final out = <List<Offset2D>>[];
    if (ab != null) out.addAll(ab);
    if (ba != null) out.addAll(ba);
    return out.isEmpty ? null : out;
  }

  static List<List<Offset2D>>? _run(
      List<Offset2D> a, List<Offset2D> b, bool sf, bool cf) {
    if (a.length < 3 || b.length < 3) return null;
    final pA = _Polygon(a);
    final pB = _Polygon(b);
    return pA.clip(pB, sf, cf);
  }
}
