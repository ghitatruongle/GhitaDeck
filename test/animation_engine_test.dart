import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/object_animation.dart';
import 'package:ghita_ppt_converter/services/animation_engine.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';

void main() {
  group('Track 29 — ObjectAnimation model', () {
    test('toMap/fromMap round-trip keeps timing', () {
      const a = ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.flyIn,
        group: AnimationGroup.entrance,
        delay: 0.3,
        duration: 0.8,
        repeat: 2,
        autoReverse: true,
        start: AnimationStart.afterPrevious,
        direction: 'right',
      );
      final back = ObjectAnimation.fromMap(a.toMap());
      expect(back.shapeId, 'sh_1');
      expect(back.effect, AnimationEffect.flyIn);
      expect(back.delay, 0.3);
      expect(back.duration, 0.8);
      expect(back.repeat, 2);
      expect(back.autoReverse, isTrue);
      expect(back.start, AnimationStart.afterPrevious);
      expect(back.direction, 'right');
    });

    test('path points round-trip', () {
      const a = ObjectAnimation(
        shapeId: 'sh_2',
        effect: AnimationEffect.arc,
        group: AnimationGroup.motion,
        pathPoints: [(x: 0, y: 0), (x: 50, y: 100)],
      );
      final back = ObjectAnimation.fromMap(a.toMap());
      expect(back.pathPoints!.length, 2);
      expect(back.pathPoints![1].x, 50);
    });

    test('unknown effect/group falls back safely', () {
      final a = ObjectAnimation.fromMap({
        'shapeId': 'x',
        'effect': 'notAnEffect',
        'group': 'bogus',
      });
      expect(a.effect, AnimationEffect.fadeIn);
      expect(a.group, AnimationGroup.entrance);
    });
  });

  group('Track 29 — AnimationEngine', () {
    test('groupOf maps every effect correctly', () {
      expect(AnimationEngine.groupOf(AnimationEffect.bounceIn), AnimationGroup.entrance);
      expect(AnimationEngine.groupOf(AnimationEffect.teeter), AnimationGroup.emphasis);
      expect(AnimationEngine.groupOf(AnimationEffect.flyOut), AnimationGroup.exit);
      expect(AnimationEngine.groupOf(AnimationEffect.star), AnimationGroup.motion);
    });

    test('motion presets include 12 named paths with >= 2 points', () {
      final presets = AnimationEngine.motionPresets();
      expect(presets.length, 12); // 12 named motion paths
      for (final entry in presets.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(2),
            reason: '${entry.key} needs a path');
      }
      expect(presets[AnimationEffect.zigzag]!.length, 6);
    });

    test('keyframesFor fadeIn is a valid animation block', () {
      final css = AnimationEngine.keyframesFor(AnimationEffect.fadeIn);
      expect(css, contains('@keyframes fadeIn'));
      expect(css, contains('opacity: 0'));
      expect(css, contains('opacity: 1'));
    });

    test('flyIn honours direction', () {
      final css = AnimationEngine.keyframesFor(AnimationEffect.flyIn, direction: 'top');
      expect(css, contains('translateY(-120%)'));
    });

    test('cssFor emits class with animation shorthand incl repeat', () {
      const a = ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.pulse,
        group: AnimationGroup.emphasis,
        duration: 1.0,
        repeat: -1,
        autoReverse: true,
      );
      final css = AnimationEngine.cssFor([a]);
      expect(css, contains('.ghita-anim-sh_1-pulse'));
      expect(css, contains('animation: pulse 1s ease 0s infinite alternate forwards'));
    });

    test('cssFor motion emits path keyframes', () {
      const a = ObjectAnimation(
        shapeId: 'sh_9',
        effect: AnimationEffect.arc,
        group: AnimationGroup.motion,
      );
      final css = AnimationEngine.cssFor([a]);
      expect(css, contains('@keyframes ghita-anim-sh_9-arc_path'));
      expect(css, contains('translate(100%, 0%)'));
    });

    test('orderIndex sorts after < with < click', () {
      expect(
        AnimationEngine.orderIndex(const ObjectAnimation(
            shapeId: 'a', effect: AnimationEffect.fadeIn, group: AnimationGroup.entrance, start: AnimationStart.afterPrevious)),
        lessThan(AnimationEngine.orderIndex(const ObjectAnimation(
            shapeId: 'a', effect: AnimationEffect.fadeIn, group: AnimationGroup.entrance, start: AnimationStart.onClick))),
      );
    });
  });

  group('Track 29 — HTML export injection', () {
    test('deck with animations includes CSS + player JS', () async {
      final service = HtmlExportService();
      const html = '<h1>Hello</h1>';
      final deck = service.buildPresentationHtml([
          {
            'title': 'S1',
            'htmlContent': html,
            'effect': 'fade',
            'visualElements': {
              'animations': [
                {
                  'shapeId': 'sh_1',
                  'effect': 'fadeIn',
                  'group': 'entrance',
                  'delay': 0,
                  'duration': 0.5,
                  'repeat': 0,
                  'autoReverse': false,
                  'start': 'onClick',
                },
              ],
            },
          },
        ],
      );
      expect(deck, contains('@keyframes fadeIn'));
      expect(deck, contains('.ghita-anim-sh_1-fadeIn'));
      expect(deck, contains('ghitaAnimations'));
      expect(deck, contains('playSlideAnimations'));
    });

    test('deck without animations has no animation JS', () async {
      final service = HtmlExportService();
      final deck = service.buildPresentationHtml([
        {'title': 'S1', 'htmlContent': '<h1>x</h1>', 'effect': 'fade'},
      ]);
      expect(deck, isNot(contains('ghitaAnimations')));
      // The wrapper stays but the player is never defined.
      expect(deck, isNot(contains('function playSlideAnimations')));
    });
  });
}
