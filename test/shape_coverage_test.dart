import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/drawn_shape.dart';
import 'package:ghita_deck/services/shape_engine.dart';

DrawnShape _rect(double x, double y, double w, double h) =>
    DrawnShape(
      id: 's$x$y$w$h',
      type: ShapeType.rect,
      x: x,
      y: y,
      w: w,
      h: h,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShapeEngine path parsing', () {
    test('debugPathPoints parses every command kind', () {
      final points = ShapeEngine.debugPathPoints(
          'M 10 10 L 40 10 H 60 V 30 C 70 40 80 50 90 60 '
          'S 100 70 110 80 Q 120 90 130 100 T 140 110 Z');
      expect(points.length, greaterThanOrEqualTo(8));
      expect(points.first.dx, 10);
      expect(points.first.dy, 10);
    });

    test('debugPolygonArea computes a rectangle area', () {
      final area = ShapeEngine.debugPolygonArea(
          'M 0 0 L 100 0 L 100 50 L 0 50 Z', 100, 50);
      expect(area, closeTo(5000, 0.01));
    });

    test('debugPolygonArea of empty path is zero', () {
      expect(ShapeEngine.debugPolygonArea('', 10, 10), 0);
    });
  });

  group('ShapeEngine boolean merges', () {
    test('mergeCombine of disjoint rects keeps both loops', () {
      final a = _rect(0, 0, 50, 50);
      final b = _rect(100, 100, 50, 50);
      final merged = ShapeEngine.mergeCombine(a, b);
      final points = ShapeEngine.debugPathPoints(merged.freeformPath);
      expect(points.length, greaterThanOrEqualTo(7));
    });
  });
}
