import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/services/shape_engine.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 21 tests — Shape engine, Merge, Freeform (FEAT 25, 26).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> slideWithShapes(List<Map<String, dynamic>> shapes) => {
        'title': 'Shapes',
        'htmlContent': '<h1>Shapes</h1>',
        'visualElements': {'shapes': shapes},
      };

  Future<Archive> exportPptx(Map<String, dynamic> slide) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t21_');
    try {
      await PPTGenerator.generatePPT([slide], '${dir.path}/out.pptx');
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  group('DrawnShape model (P1)', () {
    test('round-trips through toMap/fromMap', () {
      const shape = DrawnShape(
        id: 's1',
        type: ShapeType.rect,
        x: 10, y: 20, w: 30, h: 40,
        fillColor: '#FF0000',
        strokeColor: '#00FF00',
        strokeWidth: 2.0,
        rotation: 45,
        zOrder: 3,
      );
      final restored = DrawnShape.fromMap(shape.toMap());
      expect(restored.id, 's1');
      expect(restored.type, ShapeType.rect);
      expect(restored.x, 10);
      expect(restored.y, 20);
      expect(restored.fillColor, '#FF0000');
      expect(restored.rotation, 45);
    });

    test('round-trips through JSON', () {
      const shape = DrawnShape(type: ShapeType.oval, x: 5, y: 5, w: 50, h: 30);
      final restored = DrawnShape.fromJson(shape.toJson());
      expect(restored.type, ShapeType.oval);
      expect(restored.x, 5);
    });

    test('svgMarkup produces correct SVG for rect', () {
      const shape = DrawnShape(
        type: ShapeType.rect, w: 100, h: 60,
        fillColor: '#4472C4', strokeColor: '#000000', strokeWidth: 2,
      );
      final svg = shape.svgMarkup;
      expect(svg, contains('<svg'));
      expect(svg, contains('width="100.0"'));
      expect(svg, contains('height="60.0"'));
      expect(svg, contains('fill="#4472C4"'));
      expect(svg, contains('stroke="#000000"'));
      expect(svg, contains('stroke-width="2.0"'));
    });

    test('svgMarkup produces correct SVG for oval', () {
      const shape = DrawnShape(type: ShapeType.oval, w: 100, h: 60);
      final svg = shape.svgMarkup;
      expect(svg, contains('<ellipse'));
      expect(svg, contains('cx="50.0"'));
    });

    test('pptxPresetGeom returns correct OOXML geometry names', () {
      expect(const DrawnShape(type: ShapeType.rect).pptxPresetGeom, 'rect');
      expect(const DrawnShape(type: ShapeType.oval).pptxPresetGeom, 'ellipse');
      expect(const DrawnShape(type: ShapeType.arrow).pptxPresetGeom, 'rightArrow');
      expect(const DrawnShape(type: ShapeType.line).pptxPresetGeom, 'line');
    });
  });

  group('ShapeEngine merge (P3)', () {
    test('mergeUnion returns bounding box covering both shapes', () {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 40, h: 30);
      final merged = ShapeEngine.mergeUnion(a, b);
      expect(merged.x, 10);
      expect(merged.y, 10);
      expect(merged.w, 60); // maxX=70 - minX=10
      expect(merged.h, 40); // maxY=50 - minY=10
      expect(merged.mergeOp, 'union');
      expect(merged.mergedIds, ['a', 'b']);
    });

    test('mergeIntersect returns overlap when shapes intersect', () {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 40, h: 30);
      final merged = ShapeEngine.mergeIntersect(a, b);
      expect(merged.x, 30);
      expect(merged.y, 20);
      expect(merged.w, 20); // 50-30
      expect(merged.h, 20); // 50-30
    });

    test('mergeIntersect returns noop when shapes do not overlap', () {
      const a = DrawnShape(id: 'a', x: 0, y: 0, w: 10, h: 10);
      const b = DrawnShape(id: 'b', x: 20, y: 20, w: 10, h: 10);
      final merged = ShapeEngine.mergeIntersect(a, b);
      expect(merged.mergeOp, 'intersect_noop');
    });
  });

  group('PPTX export (P2, P10)', () {
    test('rect shape becomes a p:sp with prstGeom="rect"', () async {
      final slide = slideWithShapes([
        {'id': 's1', 'type': 'rect', 'x': 10.0, 'y': 20.0, 'w': 30.0, 'h': 40.0, 'fillColor': '#FF0000'},
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('name="Shape rect s1"'));
      expect(slideXml, contains('prst="rect"'));
      expect(slideXml, contains('val="FF0000"'));
    });

    test('oval shape becomes a p:sp with prstGeom="ellipse"', () async {
      final slide = slideWithShapes([
        {'id': 's2', 'type': 'oval', 'x': 10.0, 'y': 10.0, 'w': 40.0, 'h': 30.0},
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('prst="ellipse"'));
    });

    test('deck without shapes exports unchanged', () async {
      final archive = await exportPptx({'title': 'Plain', 'htmlContent': '<h1>Hello</h1>'});
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, isNot(contains('Shape ')));
    });
  });

  group('HTML export (P6, P10)', () {
    test('shape renders as SVG inside an absolute div', () {
      final html = HtmlExportService().buildPresentationHtml([
        slideWithShapes([
          {'id': 's1', 'type': 'rect', 'x': 10.0, 'y': 20.0, 'w': 30.0, 'h': 40.0, 'fillColor': '#FF0000'},
        ]),
      ]);
      expect(html, contains('data-shape-html'));
      expect(html, contains('left:10.0%'));
      expect(html, contains('top:20.0%'));
      expect(html, contains('fill="#FF0000"'));
    });

    test('deck without shapes has no shape divs', () {
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'Plain', 'htmlContent': '<h1>Hello</h1>'},
      ]);
      expect(html, isNot(contains('data-shape-html')));
    });
  });

  group('PDF export (P6, P10)', () {
    test('shape renders without crashing', () async {
      final slide = slideWithShapes([
        {'id': 's1', 'type': 'rect', 'x': 10.0, 'y': 20.0, 'w': 30.0, 'h': 40.0, 'fillColor': '#FF0000'},
      ]);
      final dir = await Directory.systemTemp.createTemp('ghita_t21pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf([slide], path);
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

group('Edit Points (P5)', () {
    test('anchorPoints returns four corners for empty path', () {
      const shape = DrawnShape(type: ShapeType.rect, w: 100, h: 100);
      final pts = shape.anchorPoints;
      expect(pts.length, 4);
      expect(pts[0].dx, 0);
      expect(pts[0].dy, 0);
      expect(pts[2].dx, 1);
      expect(pts[2].dy, 1);
    });

    test('anchorPoints parses M L path into 0..1 relative points', () {
      const shape = DrawnShape(
        type: ShapeType.freeform,
        freeformPath: 'M10,20 L30,40 L50,60 Z',
        w: 100, h: 100,
      );
      final pts = shape.anchorPoints;
      expect(pts.length, 3);
      expect(pts[0].dx, closeTo(0.1, 0.0001));
      expect(pts[0].dy, closeTo(0.2, 0.0001));
      expect(pts[1].dx, closeTo(0.3, 0.0001));
      expect(pts[1].dy, closeTo(0.4, 0.0001));
    });

    test('anchorPoints parses bézier C/S/Q/T curves (end point per curve)', () {
      const shape = DrawnShape(
        type: ShapeType.freeform,
        // Cubic + smooth + quadratic + smooth-quadratic.
        freeformPath:
            'M0,0 C20,0 30,10 40,20 S70,40 80,50 Q90,60 100,50 T120,50 Z',
        w: 100, h: 100,
      );
      final pts = shape.anchorPoints;
      expect(pts.length, 5); // M + 4 curve end points
      expect(pts[0].dx, closeTo(0.0, 0.0001));
      expect(pts[1].dx, closeTo(0.4, 0.0001)); // C end
      expect(pts[1].dy, closeTo(0.2, 0.0001));
      expect(pts[2].dx, closeTo(0.8, 0.0001)); // S end
      expect(pts[3].dx, closeTo(1.0, 0.0001)); // Q end
      expect(pts[4].dx, closeTo(1.2, 0.0001)); // T end (abs)
      // Round-trip through pathFromPoints keeps the polygon outline.
      final back = DrawnShape.pathFromPoints(pts, w: 100, h: 100);
      expect(back, contains('M0.0,0.0'));
      expect(back, contains('L40.0,20.0'));
    });

    test('pathFromPoints serializes back correctly', () {
      final pts = [
        const Offset2D(0, 0), const Offset2D(0.5, 0.3), const Offset2D(1, 1),
      ];
      final path = DrawnShape.pathFromPoints(pts, w: 200, h: 100);
      expect(path, contains('M0.0,0.0'));
      expect(path, contains('L100.0,30.0'));
      expect(path, contains('L200.0,100.0'));
      expect(path, endsWith('Z'));
    });

    test('withAnchors converts rect to freeform with updated path', () {
      const shape = DrawnShape(type: ShapeType.rect, w: 100, h: 100);
      final pts = [const Offset2D(0.1, 0.1), const Offset2D(0.9, 0.1), const Offset2D(0.5, 0.9)];
      final updated = shape.withAnchors(pts);
      expect(updated.type, ShapeType.freeform);
      expect(updated.freeformPath, contains('M10.0,10.0'));
      expect(updated.freeformPath, contains('Z'));
    });
  });

group('Shape Properties (P7)', () {
    test('copyWith updates fillColor', () {
      const shape = DrawnShape(type: ShapeType.rect, fillColor: '#FF0000');
      final updated = shape.copyWith(fillColor: '#00FF00');
      expect(updated.fillColor, '#00FF00');
    });

    test('copyWith updates fillTransparency', () {
      const shape = DrawnShape(type: ShapeType.rect, fillTransparency: 0.0);
      final updated = shape.copyWith(fillTransparency: 0.5);
      expect(updated.fillTransparency, 0.5);
    });

    test('copyWith updates strokeColor and strokeWidth', () {
      const shape = DrawnShape(type: ShapeType.rect, strokeColor: '#000', strokeWidth: 1.0);
      final updated = shape.copyWith(strokeColor: '#FFF', strokeWidth: 3.0);
      expect(updated.strokeColor, '#FFF');
      expect(updated.strokeWidth, 3.0);
    });
  });

  group('ShapeEngine boolean merge (P3 real geometry)', () {
    test('mergeUnion of two overlapping rects is L-shaped, not bounding box', () {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 40, h: 30);
      final m = ShapeEngine.mergeUnion(a, b);
      expect(m.type, ShapeType.merged);
      expect(m.mergeOp, 'union');
      // The union outline is a real L-shape: 6 vertices.
      final pts = ShapeEngine.debugPathPoints(m.freeformPath);
      expect(pts.length, greaterThanOrEqualTo(6));
      // Area check: union of the two rects (overlap 20x20) =
      // 40*30 + 40*30 - 20*20 = 2000 sq-units.
      final area = ShapeEngine.debugPolygonArea(m.freeformPath, m.w, m.h);
      expect(area, closeTo(2000, 1.0));
      expect(m.w, closeTo(60, 0.001));
      expect(m.h, closeTo(40, 0.001));
    });

    test('mergeUnion of disjoint rects keeps both loops', () {
      const a = DrawnShape(id: 'a', x: 0, y: 0, w: 10, h: 10);
      const b = DrawnShape(id: 'b', x: 20, y: 0, w: 10, h: 10);
      final m = ShapeEngine.mergeUnion(a, b);
      expect(m.mergeOp, 'union');
      final area = ShapeEngine.debugPolygonArea(m.freeformPath, m.w, m.h);
      expect(area, closeTo(200, 1.0)); // two 10x10 rects
    });

    test('mergeCombine (XOR) of overlapping rects removes the overlap', () {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 40, h: 30);
      final m = ShapeEngine.mergeCombine(a, b);
      expect(m.mergeOp, 'combine');
      // XOR area = union (2000) - intersection (20x20=400) = 1600.
      final area = ShapeEngine.debugPolygonArea(m.freeformPath, m.w, m.h);
      expect(area, closeTo(1600, 1.0));
    });

    test('mergeSubtract cuts b out of a (area 1200 - 200 = 1000)', () {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 20, h: 10);
      final m = ShapeEngine.mergeSubtract(a, b);
      expect(m.mergeOp, 'subtract');
      final area = ShapeEngine.debugPolygonArea(m.freeformPath, m.w, m.h);
      expect(area, closeTo(1000, 1.0));
    });

    test('mergeIntersect of overlapping rects returns overlap rect', () {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 40, h: 30);
      final m = ShapeEngine.mergeIntersect(a, b);
      expect(m.mergeOp, 'intersect');
      expect(m.x, closeTo(30, 0.001));
      expect(m.y, closeTo(20, 0.001));
      expect(m.w, closeTo(20, 0.001));
      expect(m.h, closeTo(20, 0.001));
    });

    test('mergeIntersect of disjoint rects is a noop', () {
      const a = DrawnShape(id: 'a', x: 0, y: 0, w: 10, h: 10);
      const b = DrawnShape(id: 'b', x: 20, y: 20, w: 10, h: 10);
      final m = ShapeEngine.mergeIntersect(a, b);
      expect(m.mergeOp, 'intersect_noop');
    });

    test('merge with oval uses a real ellipse union (area > bbox hint)', () {
      const a = DrawnShape(id: 'a', type: ShapeType.oval, x: 0, y: 0, w: 40, h: 40);
      const b = DrawnShape(id: 'b', type: ShapeType.oval, x: 40, y: 0, w: 40, h: 40);
      final m = ShapeEngine.mergeUnion(a, b);
      expect(m.mergeOp, 'union');
      final area = ShapeEngine.debugPolygonArea(m.freeformPath, m.w, m.h);
      // Two circles radius 20 side by side: 2*pi*400 ≈ 2513 (48-gon
      // approximation of each circle is a touch smaller).
      expect(area, closeTo(2 * 3.14159265 * 400, 10));
    });

    test('custGeom output has a pathLst with the boolean outline', () async {
      const a = DrawnShape(id: 'a', x: 10, y: 10, w: 40, h: 30);
      const b = DrawnShape(id: 'b', x: 30, y: 20, w: 40, h: 30);
      final m = ShapeEngine.mergeUnion(a, b);
      final slide = slideWithShapes([
        {
          'id': m.id, 'type': 'merged',
          'x': m.x, 'y': m.y, 'w': m.w, 'h': m.h,
          'fillColor': m.fillColor,
          'freeformPath': m.freeformPath,
          'mergeOp': 'union',
          'mergedIds': ['a', 'b'],
        },
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('a:custGeom'));
      expect(slideXml, contains('a:pathLst'));
    });
  });
}
