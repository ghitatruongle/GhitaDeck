import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/models/layer.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/group_service.dart';
import 'package:ghita_ppt_converter/services/layer_service.dart';

void main() {
  group('Track 26 — LayerService', () {
    Slide makeSlide() {
      final shapes = <Map<String, dynamic>>[
        const DrawnShape(
          id: 's1',
          type: ShapeType.rect,
          x: 10,
          y: 10,
          w: 50,
          h: 30,
          zOrder: 0,
        ).toMap(),
        const DrawnShape(
          id: 's2',
          type: ShapeType.oval,
          x: 20,
          y: 20,
          w: 40,
          h: 40,
          zOrder: 1,
        ).toMap(),
      ];
      return Slide(
        title: 'Test',
        htmlContent: '<h1>Hi</h1>',
        visualElements: {'shapes': shapes},
      );
    }

    test('buildLayers derives back-to-front shape layers', () {
      final layers = LayerService.buildLayers(makeSlide());
      expect(layers.length, 2);
      expect(layers.first.type, 'shape');
      expect(layers.first.elementId, 's1');
      expect(layers.last.elementId, 's2');
      // Stable ids use the sh_ prefix so canvas ids never collide.
      expect(layers.first.id, 'sh_s1');
    });

    test('re-applies persisted visible/locked/name state by id', () {
      final slide = makeSlide().copyWith(
        visualElements: {
          'shapes': [
            const DrawnShape(
              id: 's1',
              type: ShapeType.rect,
              x: 10,
              y: 10,
              w: 50,
              h: 30,
              zOrder: 0,
            ).toMap(),
          ],
          'layers': [
            const SlideLayer(
              id: 'sh_s1',
              elementId: 's1',
              type: 'shape',
              name: 'Logo',
              zOrder: 0,
              visible: false,
              locked: true,
            ).toMap(),
          ],
        },
      );
      final layers = LayerService.buildLayers(slide);
      expect(layers.single.name, 'Logo');
      expect(layers.single.visible, isFalse);
      expect(layers.single.locked, isTrue);
    });

    test('reorder moves a layer and re-stamps z-order', () {
      final layers = LayerService.buildLayers(makeSlide());
      final reordered = LayerService.reorder(layers, 1, 0);
      expect(reordered.first.elementId, 's2');
      expect(reordered.map((l) => l.zOrder), [0, 1]);
    });

    test('stateToMap round-trips', () {
      final layers = LayerService.buildLayers(makeSlide());
      final maps = LayerService.stateToMap(layers);
      final back = [
        for (final m in maps) SlideLayer.fromMap(Map<String, dynamic>.from(m)),
      ];
      expect(back.map((l) => l.id), layers.map((l) => l.id));
    });
  });

  group('Track 26 — GroupService', () {
    List<DrawnShape> threeShapes() => [
          const DrawnShape(
            id: 'a',
            type: ShapeType.rect,
            x: 0,
            y: 0,
            w: 100,
            h: 100,
            zOrder: 0,
          ),
          const DrawnShape(
            id: 'b',
            type: ShapeType.oval,
            x: 100,
            y: 0,
            w: 100,
            h: 100,
            zOrder: 1,
          ),
          const DrawnShape(
            id: 'c',
            type: ShapeType.arrow,
            x: 0,
            y: 100,
            w: 100,
            h: 100,
            zOrder: 2,
          ),
        ];

    test('createGroup computes union bbox + keeps member order', () {
      final group = GroupService.createGroup(threeShapes(), ['a', 'b', 'c']);
      expect(group.memberIds, ['a', 'b', 'c']);
      expect(group.x, closeTo(0, 1e-6));
      expect(group.y, closeTo(0, 1e-6));
      expect(group.w, closeTo(200, 1e-6));
      expect(group.h, closeTo(200, 1e-6));
    });

    test('moveGroup shifts every member together', () {
      final group = GroupService.createGroup(threeShapes(), ['a', 'b']);
      final moved = GroupService.moveGroup(threeShapes(), group, 5, -3);
      final a = moved.firstWhere((s) => s.id == 'a');
      final b = moved.firstWhere((s) => s.id == 'b');
      final c = moved.firstWhere((s) => s.id == 'c');
      expect(a.x, closeTo(5, 1e-6));
      expect(b.x, closeTo(105, 1e-6));
      expect(c.x, closeTo(0, 1e-6)); // non-member untouched
      expect(a.y, closeTo(-3, 1e-6));
    });

    test('renderPptxGroupXml emits p:grpSp with grpSpPr + children', () {
      final shapes = threeShapes();
      final group = GroupService.createGroup(shapes, ['a', 'b']);
      final members = shapes.where((s) => group.memberIds.contains(s.id)).toList();
      final xml = GroupService.renderPptxGroupXml(
        groupShapeId: 7,
        group: group,
        members: members,
      );
      expect(xml, contains('<p:grpSp>'));
      expect(xml, contains('<p:grpSpPr>'));
      expect(xml, contains('<a:xfrm>'));
      expect(xml, contains('<a:chOff x="0" y="0"/>'));
      expect(xml, contains('</p:grpSp>'));
      // Two member <p:sp> elements with child-relative offsets.
      expect('<p:sp>'.allMatches(xml).length, 2);
      expect(xml, contains('<a:off x="0" y="0"/>'));
      expect(xml, contains('<a:off x="'));
    });

    test('fromMap/toMap round-trip keeps members', () {
      final group = GroupService.createGroup(threeShapes(), ['a', 'b', 'c']);
      final back = ShapeGroup.fromMap(group.toMap());
      expect(back.id, group.id);
      expect(back.memberIds, group.memberIds);
      expect(back.w, group.w);
      expect(back.h, group.h);
    });
  });
}
