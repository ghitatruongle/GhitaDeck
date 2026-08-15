import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/morph_service.dart';

void main() {
  DrawnShape shape(String id, ShapeType type, double x, double y, double w, double h,
          {int z = 0}) =>
      DrawnShape(id: id, type: type, x: x, y: y, w: w, h: h, zOrder: z);

  group('Track 34 — shape matching', () {
    test('matches shapes with the same id', () {
      final prev = [shape('a', ShapeType.rect, 0, 0, 50, 50)];
      final next = [shape('a', ShapeType.rect, 30, 30, 60, 60)];
      final pairs = MorphService.match(prev, next);
      expect(pairs.length, 1);
      expect(pairs.single.prev.id, 'a');
    });

    test('matches same type + similar size when id differs', () {
      final prev = [shape('a', ShapeType.rect, 0, 0, 50, 50)];
      final next = [shape('b', ShapeType.rect, 20, 20, 55, 55)];
      final pairs = MorphService.match(prev, next);
      expect(pairs.length, 1);
      expect(pairs.single.next.id, 'b');
    });

    test('does not match different types', () {
      final prev = [shape('a', ShapeType.rect, 0, 0, 50, 50)];
      final next = [shape('b', ShapeType.oval, 20, 20, 55, 55)];
      expect(MorphService.match(prev, next), isEmpty);
    });

    test('caps at 20 pairs', () {
      final prev = [for (var i = 0; i < 30; i++) shape('s$i', ShapeType.rect, i.toDouble(), 0, 10, 10, z: i)];
      final next = [for (var i = 0; i < 30; i++) shape('s$i', ShapeType.rect, (i + 1).toDouble(), 5, 12, 12, z: i)];
      expect(MorphService.match(prev, next).length, MorphService.maxMorphShapes);
    });
  });

  group('Track 34 — FLIP CSS', () {
    test('flipKeyframes translates between positions', () {
      final css = MorphService.flipKeyframes(
        name: 'm1',
        prev: shape('a', ShapeType.rect, 10, 10, 20, 20),
        next: shape('a', ShapeType.rect, 50, 50, 40, 40),
        scaleW: 10,
        scaleH: 10,
      );
      expect(css, contains('@keyframes m1'));
      // prev pos (100,100) vs next (500,500) → translate(-400, -400)
      expect(css, contains('translate(-400px, -400px)'));
      // prev 200x200 → next 400x400 → scale(2, 2)
      expect(css, contains('scale(2, 2)'));
    });

    test('cssFor emits keyframes + selector with data-ghita-id', () {
      final pairs = MorphService.match(
        [shape('a', ShapeType.rect, 0, 0, 50, 50)],
        [shape('a', ShapeType.rect, 40, 40, 50, 50)],
      );
      final css = MorphService.cssFor(pairs, slideWidthPx: 1000, slideHeightPx: 600);
      expect(css, contains('@keyframes ghita-morph-0'));
      expect(css, contains('[data-ghita-id="sh_a"]'));
      expect(css, contains('animation: ghita-morph-0 0.6s ease forwards'));
    });
  });

  group('Track 34 — PPTX p14:morph + HTML export', () {
    test('pptxTransition disabled returns empty', () {
      expect(MorphService.pptxTransition(enabled: false), isEmpty);
    });

    test('pptxTransition enabled emits p14:morph with namespace', () {
      final xml = MorphService.pptxTransition(enabled: true, durationMs: 800);
      expect(xml, contains('<p:transition spd="med"'));
      expect(xml, contains('xmlns:p14='));
      expect(xml, contains('<p14:morph/>'));
    });

    test('HTML deck with morph slide emits FLIP keyframes', () {
      final service = HtmlExportService();
      final deck = service.buildPresentationHtml([
        {
          'title': 'S1',
          'htmlContent': '<h1>One</h1>',
          'visualElements': {
            'shapes': [
              shape('a', ShapeType.rect, 0, 0, 50, 50).toMap(),
            ],
          },
        },
        {
          'title': 'S2',
          'htmlContent': '<h1>Two</h1>',
          'morphFromPrevious': true,
          'visualElements': {
            'shapes': [
              shape('a', ShapeType.rect, 45, 45, 55, 55).toMap(),
            ],
          },
        },
      ]);
      expect(deck, contains('@keyframes ghita-morph-0'));
      expect(deck, contains('[data-ghita-id="sh_a"]'));
      expect(deck, contains('transform: translate('));
    });

    test('HTML deck without morph has no morph keyframes', () {
      final service = HtmlExportService();
      final deck = service.buildPresentationHtml([
        {'title': 'S1', 'htmlContent': '<h1>One</h1>', 'effect': 'fade'},
        {'title': 'S2', 'htmlContent': '<h1>Two</h1>', 'effect': 'fade'},
      ]);
      expect(deck, isNot(contains('ghita-morph')));
    });
  });
}
