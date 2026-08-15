import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/models/shape_effect.dart';
import 'package:ghita_ppt_converter/services/shape_engine.dart';

void main() {
  group('ShapeEffect — OOXML', () {
    test('empty effect produces no effectLst', () {
      expect(ShapeEffect.none.toEffectLstXml(), '');
      expect(ShapeEffect.none.toSp3dXml(), '');
    });

    test('shadow maps to a:outerShdw with clamped sizes', () {
      const fx = ShapeEffect(shadow: true, shadowAlpha: 0.5, shadowColor: '#123456');
      final xml = fx.toEffectLstXml();
      expect(xml, startsWith('<a:effectLst>'));
      expect(xml, contains('<a:outerShdw'));
      expect(xml, contains('val="123456"'));
      expect(xml, contains('<a:alpha val="50000"/>'));
      expect(xml, endsWith('</a:effectLst>'));
    });

    test('glow + softEdge combine in one effectLst', () {
      const fx = ShapeEffect(glow: true, softEdge: 5, glowColor: '#00FF00');
      final xml = fx.toEffectLstXml();
      expect(xml, contains('<a:glow'));
      expect(xml, contains('<a:softEdge'));
      expect(xml, contains('val="00FF00"'));
    });

    test('bevel emits a:sp3d with bevelT', () {
      const fx = ShapeEffect(bevel: 'round');
      final xml = fx.toSp3dXml();
      expect(xml, startsWith('<a:sp3d'));
      expect(xml, contains('<a:bevelT'));
      expect(xml, contains('prstMaterial="warmMatte"'));
    });
  });

  group('ShapeEffect — CSS', () {
    test('shadow renders box-shadow with alpha hex', () {
      const fx = ShapeEffect(shadow: true, shadowAlpha: 1, shadowColor: '#000000');
      final css = fx.toCss(wPercent: 20, hPercent: 10);
      expect(css, contains('box-shadow:'));
      expect(css, contains('#000000ff'));
    });

    test('3D rotation adds a transform', () {
      const fx = ShapeEffect(rot3dY: 30);
      final css = fx.toCss(wPercent: 20, hPercent: 10);
      expect(css, contains('transform: perspective(800px)'));
      expect(css, contains('rotateY(30.0deg)'));
    });

    test('text shadow renders for free text', () {
      const fx = ShapeEffect(shadow: true);
      expect(fx.toTextCss(), contains('text-shadow:'));
    });
  });

  group('ShapeEffect — presets & serialization', () {
    test('quick presets toggle the right flags', () {
      expect(const ShapeEffect().withPreset(EffectPreset.soft).shadow, isTrue);
      expect(const ShapeEffect().withPreset(EffectPreset.glow).glow, isTrue);
      expect(const ShapeEffect().withPreset(EffectPreset.none).isEmpty, isTrue);
      expect(
          const ShapeEffect(shadow: true).withPreset(EffectPreset.none).isEmpty,
          isTrue);
    });

    test('map round-trip keeps every field', () {
      const fx = ShapeEffect(
        shadow: true,
        shadowOffsetX: 4,
        shadowOffsetY: 5,
        shadowBlur: 9,
        shadowColor: '#ABCDEF',
        shadowAlpha: 0.7,
        glow: true,
        glowColor: '#123456',
        glowSize: 11,
        reflection: true,
        softEdge: 3,
        bevel: 'convex',
        rot3dX: 10,
        rot3dY: 20,
        rot3dZ: 30,
      );
      final restored = ShapeEffect.fromMap(fx.toMap());
      expect(restored.shadow, isTrue);
      expect(restored.shadowOffsetX, 4);
      expect(restored.shadowColor, '#ABCDEF');
      expect(restored.shadowAlpha, 0.7);
      expect(restored.glowColor, '#123456');
      expect(restored.softEdge, 3);
      expect(restored.bevel, 'convex');
      expect(restored.rot3dY, 20);
      expect(restored.reflection, isTrue);
    });

    test('DrawnShape stores and restores its effect', () {
      const fx = ShapeEffect(shadow: true, glow: true);
      const shape = DrawnShape(id: 's', effect: fx);
      final restored = DrawnShape.fromMap(shape.toMap());
      expect(restored.effect.shadow, isTrue);
      expect(restored.effect.glow, isTrue);
    });

    test('PPTX shape XML includes effectLst when present', () {
      const fx = ShapeEffect(shadow: true);
      const shape = DrawnShape(id: 's1', w: 20, h: 10, effect: fx);
      final xml = ShapeEngine.renderPptxShape(
        shapeId: 1,
        shape: shape,
        offX: 100,
        offY: 100,
        extCx: 1828800,
        extCy: 685800,
      );
      expect(xml, contains('<a:effectLst>'));
      expect(xml, contains('<a:outerShdw'));
    });

    test('PPTX shape XML has no effectLst when effect empty', () {
      const shape = DrawnShape(id: 's1', w: 20, h: 10);
      final xml = ShapeEngine.renderPptxShape(
        shapeId: 1,
        shape: shape,
        offX: 100,
        offY: 100,
        extCx: 1828800,
        extCy: 685800,
      );
      expect(xml, isNot(contains('<a:effectLst>')));
    });
  });
}
