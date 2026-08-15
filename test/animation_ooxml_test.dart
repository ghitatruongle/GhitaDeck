import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/object_animation.dart';
import 'package:ghita_ppt_converter/services/animation_ooxml.dart';

void main() {
  group('Track 32 — p:timing OOXML tree', () {
    test('empty list returns empty xml with no warnings', () {
      final r = AnimationOoxml.buildTimingXml(const [], spidMap: const {});
      expect(r.xml, isEmpty);
      expect(r.warnings, isEmpty);
    });

    test('entrance animation emits seq + animEffect + visibility set', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_1',
            effect: AnimationEffect.fadeIn,
            group: AnimationGroup.entrance,
            duration: 0.5,
          ),
        ],
        spidMap: {'sh_1': 12},
      );
      final xml = r.xml;
      expect(xml, contains('<p:timing>'));
      expect(xml, contains('<p:seq concurrent="1" nextAc="seek">'));
      expect(xml, contains('nodeType="clickEffect"'));
      expect(xml, contains('presetClass="entr"'));
      expect(xml, contains('<p:animEffect transition="in" filter="fade">'));
      expect(xml, contains('<p:spTgt spid="12"/>'));
      expect(xml, contains('style.visibility'));
      expect(xml, contains('val="visible"'));
      expect(xml, contains('<p:prevCondLst>'));
      expect(xml, contains('<p:nextCondLst>'));
    });

    test('flyIn with direction maps to fly filter + dir', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'ft_2',
            effect: AnimationEffect.flyIn,
            group: AnimationGroup.entrance,
            direction: 'right',
          ),
        ],
        spidMap: {'ft_2': 20},
      );
      expect(r.xml, contains('filter="fly"'));
      expect(r.xml, contains('dir="rtl"'));
    });

    test('emphasis spin emits animRot by 360000', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_3',
            effect: AnimationEffect.spin,
            group: AnimationGroup.emphasis,
          ),
        ],
        spidMap: {'sh_3': 5},
      );
      expect(r.xml, contains('presetClass="emph"'));
      expect(r.xml, contains('<p:animRot by="360000">'));
    });

    test('exit animation toggles visibility hidden + animEffect out', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_4',
            effect: AnimationEffect.fadeOut,
            group: AnimationGroup.exit,
          ),
        ],
        spidMap: {'sh_4': 6},
      );
      expect(r.xml, contains('val="hidden"'));
      expect(r.xml, contains('transition="out"'));
    });

    test('motion emits animMotion with path points', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_5',
            effect: AnimationEffect.arc,
            group: AnimationGroup.motion,
            pathPoints: [(x: 0, y: 0), (x: 50, y: 100)],
          ),
        ],
        spidMap: {'sh_5': 7},
      );
      expect(r.xml, contains('presetClass="motion"'));
      expect(r.xml, contains('<p:animMotion origin="layout" path="m">'));
      expect(r.xml, contains('<a:ptLst>'));
      expect(r.xml, contains('<a:pt x="5000000" y="10000000"/>'));
    });

    test('afterPrevious + trigger writes cond with trigger target', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_6',
            effect: AnimationEffect.bounceIn,
            group: AnimationGroup.entrance,
            start: AnimationStart.afterPrevious,
            triggerShapeId: 'sh_1',
          ),
        ],
        spidMap: {'sh_6': 8, 'sh_1': 3},
      );
      expect(r.xml, contains('nodeType="afterEffect"'));
      expect(r.xml, contains('delay="indefinite"'));
      expect(r.xml, contains('<p:tgtEl><p:spTgt spid="3"/></p:tgtEl>'));
    });

    test('delay and repeat are baked into the behaviour cTn', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_7',
            effect: AnimationEffect.pulse,
            group: AnimationGroup.emphasis,
            delay: 0.4,
            duration: 1.2,
            repeat: 2,
          ),
        ],
        spidMap: {'sh_7': 9},
      );
      expect(r.xml, contains('delay="400"'));
      expect(r.xml, contains('dur="1200"'));
      expect(r.xml, contains('repeatCount="3"'));
    });

    test('unknown shape id is skipped with a warning', () {
      final r = AnimationOoxml.buildTimingXml(
        const [
          ObjectAnimation(
            shapeId: 'sh_missing',
            effect: AnimationEffect.fadeIn,
            group: AnimationGroup.entrance,
          ),
        ],
        spidMap: const {},
      );
      expect(r.xml, isNot(contains('<p:animEffect')));
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('sh_missing'));
    });
  });
}
