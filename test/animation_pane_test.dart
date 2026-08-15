import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/object_animation.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('Track 30 — Animation state operations', () {
    PresentationState makeState() {
      final state = PresentationState();
      state.addSlide(Slide(
        title: 'S1',
        htmlContent: '<h1>Hi</h1>',
        visualElements: {'shapes': []},
      ));
      return state;
    }

    test('upsertAnimation adds then replaces same shape+effect', () {
      final state = makeState();
      state.upsertAnimation(const ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.fadeIn,
        group: AnimationGroup.entrance,
        duration: 0.5,
      ));
      state.upsertAnimation(const ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.fadeIn,
        group: AnimationGroup.entrance,
        duration: 2.0,
      ));
      final anims = state.currentAnimations;
      expect(anims.length, 1);
      expect(anims.single.duration, 2.0);
    });

    test('updateAnimations reorders the timeline', () {
      final state = makeState();
      state.updateAnimations([
        const ObjectAnimation(
            shapeId: 'sh_a',
            effect: AnimationEffect.fadeIn,
            group: AnimationGroup.entrance),
        const ObjectAnimation(
            shapeId: 'sh_b',
            effect: AnimationEffect.flyIn,
            group: AnimationGroup.entrance),
      ]);
      state.updateAnimations(state.currentAnimations.reversed.toList());
      expect(state.currentAnimations.first.shapeId, 'sh_b');
      expect(state.currentAnimations.last.shapeId, 'sh_a');
    });

    test('updateAnimations with empty list clears visualElements', () {
      final state = makeState();
      state.upsertAnimation(const ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.pulse,
        group: AnimationGroup.emphasis,
      ));
      state.updateAnimations([]);
      expect(state.currentAnimations, isEmpty);
      final raw = state.currentSlide?.visualElements['animations'];
      expect(raw, isNull);
    });

    test('painter copies timing to another shape', () {
      final state = makeState();
      state.upsertAnimation(const ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.zoomIn,
        group: AnimationGroup.entrance,
        duration: 1.4,
        delay: 0.2,
        repeat: 2,
      ));
      final source = state.currentAnimations.first;
      final copied = source.copyWith(shapeId: 'sh_2');
      state.upsertAnimation(copied);
      final anims = state.currentAnimations;
      expect(anims.length, 2);
      final target = anims.firstWhere((a) => a.shapeId == 'sh_2');
      expect(target.duration, 1.4);
      expect(target.delay, 0.2);
      expect(target.repeat, 2);
      expect(target.effect, AnimationEffect.zoomIn);
    });

    test('animations survive slide map round-trip', () {
      final state = makeState();
      state.upsertAnimation(const ObjectAnimation(
        shapeId: 'sh_1',
        effect: AnimationEffect.spin,
        group: AnimationGroup.emphasis,
        autoReverse: true,
      ));
      final map = state.currentSlide!.toMap();
      final back = Slide.fromMap(map);
      final raw = back.visualElements['animations'] as List;
      expect(raw.length, 1);
      final a = ObjectAnimation.fromMap(Map<String, dynamic>.from(raw.first as Map));
      expect(a.effect, AnimationEffect.spin);
      expect(a.autoReverse, isTrue);
    });
  });
}
