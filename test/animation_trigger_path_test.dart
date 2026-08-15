import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/object_animation.dart';
import 'package:ghita_ppt_converter/services/animation_engine.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';

void main() {
  group('Track 31 — Motion path presets', () {
    test('engine exposes 12 named presets', () {
      final presets = AnimationEngine.motionPresets();
      expect(presets.length, 12);
      expect(presets.containsKey(AnimationEffect.turn), isTrue);
      expect(presets.containsKey(AnimationEffect.wave), isTrue);
      expect(presets.containsKey(AnimationEffect.spiral), isTrue);
      expect(presets.containsKey(AnimationEffect.swish), isTrue);
      expect(presets.containsKey(AnimationEffect.boomerang), isTrue);
    });

    test('every preset has a closed/complete path', () {
      for (final entry in AnimationEngine.motionPresets().entries) {
        expect(entry.value.length, greaterThanOrEqualTo(2));
        // Waypoints stay within a sane box except boomerang's overshoot.
        for (final p in entry.value) {
          expect(p.x, inInclusiveRange(-80, 120));
          expect(p.y, inInclusiveRange(-80, 120));
        }
      }
    });

    test('motionKeyframes emits percentage steps', () {
      final css = AnimationEngine.motionKeyframes('mypath', [
        (x: 0, y: 0),
        (x: 50, y: 100),
      ]);
      expect(css, contains('@keyframes mypath'));
      expect(css, contains('0.0%'));
      expect(css, contains('100.0%'));
      expect(css, contains('translate(50%, 100%)'));
    });
  });

  group('Track 31 — Custom path & trigger model', () {
    test('customPath keeps its own waypoints', () {
      const a = ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.customPath,
        group: AnimationGroup.motion,
        pathPoints: [(x: 0, y: 0), (x: 10, y: 20), (x: 40, y: 60), (x: 100, y: 100)],
      );
      final css = AnimationEngine.cssFor([a]);
      expect(css, contains('@keyframes ghita-anim-sh_1-customPath_path'));
      expect(css, contains('translate(10%, 20%)'));
      // Default preset fallback is not used when points exist.
      expect(css, contains('translate(40%, 60%)'));
    });

    test('trigger survives map round-trip', () {
      final a = ObjectAnimation.fromMap(const ObjectAnimation(
        shapeId: 'sh_2',
        effect: AnimationEffect.flyIn,
        group: AnimationGroup.entrance,
        triggerShapeId: 'sh_1',
      ).toMap());
      expect(a.triggerShapeId, 'sh_1');
    });

    test('clearTrigger removes it', () {
      const a = ObjectAnimation(
        shapeId: 'sh_2',
        effect: AnimationEffect.fadeIn,
        group: AnimationGroup.entrance,
        triggerShapeId: 'sh_1',
      );
      expect(a.copyWith(clearTrigger: true).triggerShapeId, isNull);
    });
  });

  group('Track 31 — HTML player trigger wiring', () {
    test('trigger animation emits click listener JS', () {
      final service = HtmlExportService();
      final deck = service.buildPresentationHtml([
        {
          'title': 'S1',
          'htmlContent': '<h1>Hi</h1>',
          'effect': 'fade',
          'visualElements': {
            'animations': [
              {
                'shapeId': 'sh_2',
                'effect': 'flyIn',
                'group': 'entrance',
                'delay': 0,
                'duration': 0.5,
                'repeat': 0,
                'autoReverse': false,
                'start': 'onClick',
                'triggerShapeId': 'sh_1',
              },
            ],
          },
        },
      ]);
      expect(deck, contains('triggerShapeId'));
      expect(deck, contains('addEventListener("click"'));
      expect(deck, contains('data-ghita-id'));
    });
  });
}
