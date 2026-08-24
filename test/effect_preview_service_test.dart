// T03 (v2.0.1-beta.2) — EffectPreviewService tests (phase 7).
//
// Pure CSS-generation contract: per-effect keyframes + classes, body-level
// deduplication (identical keyframe bodies emit one @keyframes and alias the
// rest), category grouping exhaustiveness, and PPTX transition mapping.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/effect_preview_service.dart';

void main() {
  group('generateEffectCss', () {
    test('none produces no CSS at all', () {
      expect(EffectPreviewService.generateEffectCss(SlideEffect.none), '');
    });

    test('fade emits its keyframes, class rule and custom duration', () {
      final css = EffectPreviewService.generateEffectCss(
        SlideEffect.fade,
        duration: 0.8,
      );
      expect(css, contains('@keyframes fade'));
      expect(css, contains('from { opacity: 0; } to { opacity: 1; }'));
      expect(css, contains('.slide-transition-fade'));
      expect(css, contains('animation: fade 0.8s ease forwards'));
    });

    test('each effect family carries a distinctive transform', () {
      expect(EffectPreviewService.generateEffectCss(SlideEffect.pushLeft),
          contains('translateX(100%)'));
      expect(EffectPreviewService.generateEffectCss(SlideEffect.zoom),
          contains('scale(0)'));
      expect(EffectPreviewService.generateEffectCss(SlideEffect.spin),
          contains('rotate(360deg)'));
    });
  });

  group('generateEffectsCss deduplication', () {
    test('identical keyframe bodies are emitted once and aliased', () {
      // fade and appear share the exact same opacity keyframes.
      final css = EffectPreviewService.generateEffectsCss(
          [SlideEffect.fade, SlideEffect.appear]);

      expect('@keyframes'.allMatches(css), hasLength(1),
          reason: 'one shared @keyframes block for both effects');
      expect(css, contains('@keyframes fade{'));
      expect(css, contains('.slide-transition-fade{animation:fade'));
      expect(css, contains('.slide-transition-appear{animation:fade'),
          reason: 'appear aliases the canonical fade keyframes');
    });

    test('none is skipped and every distinct effect keeps its own keyframes',
        () {
      final css = EffectPreviewService.generateEffectsCss([
        SlideEffect.none,
        SlideEffect.fade,
        SlideEffect.zoom,
      ]);
      expect('@keyframes'.allMatches(css), hasLength(2));
      expect(css, isNot(contains('.slide-transition-none')));
    });
  });

  group('generateAllEffectsCss', () {
    test('covers every declared effect exactly once as a class', () {
      final css = EffectPreviewService.generateAllEffectsCss();
      for (final effect in SlideEffect.values) {
        if (effect == SlideEffect.none) continue;
        expect(css, contains('.slide-transition-${effect.name}'),
            reason: '${effect.name} must ship with the deck stylesheet');
      }
    });
  });

  group('transition class helper', () {
    test('null and none resolve to an empty class', () {
      expect(EffectPreviewService.getTransitionClass(null), '');
      expect(EffectPreviewService.getTransitionClass(SlideEffect.none), '');
    });

    test('a real effect returns slide-transition-<name>', () {
      expect(EffectPreviewService.getTransitionClass(SlideEffect.wipe),
          'slide-transition-wipe');
    });
  });

  group('category grouping', () {
    test('every effect maps to a non-empty category label', () {
      for (final effect in SlideEffect.values) {
        expect(EffectPreviewService.getEffectCategory(effect), isNotEmpty,
            reason: '${effect.name} must belong to a category');
      }
    });

    test('spot checks across all five families', () {
      expect(EffectPreviewService.getEffectCategory(SlideEffect.fade), 'Basic');
      expect(EffectPreviewService.getEffectCategory(SlideEffect.flyInLeft),
          'Entrance');
      expect(
          EffectPreviewService.getEffectCategory(SlideEffect.pulse), 'Emphasis');
      expect(EffectPreviewService.getEffectCategory(SlideEffect.disappear),
          'Exit');
      expect(EffectPreviewService.getEffectCategory(SlideEffect.arc),
          'Motion Path');
    });

    test('category queries return members for each listed category', () {
      for (final category in EffectPreviewService.categories) {
        expect(EffectPreviewService.getEffectsByCategory(category),
            isNotEmpty, reason: '$category must list at least one effect');
      }
    });

    test('category icons resolve', () {
      expect(EffectPreviewService.getCategoryIcon('Entrance'), '🟢');
      expect(EffectPreviewService.getCategoryIcon('Unknown'), '⚪');
    });
  });

  group('toPptxTransitionType', () {
    test('canonical mappings', () {
      expect(
          EffectPreviewService.toPptxTransitionType(SlideEffect.fade), 'fade');
      expect(EffectPreviewService.toPptxTransitionType(SlideEffect.pushLeft),
          'push');
      expect(
          EffectPreviewService.toPptxTransitionType(SlideEffect.wipe), 'wipe');
      expect(EffectPreviewService.toPptxTransitionType(SlideEffect.splitOut),
          'split');
      expect(EffectPreviewService.toPptxTransitionType(SlideEffect.swivel),
          'rotate');
      expect(EffectPreviewService.toPptxTransitionType(SlideEffect.flyOutLeft),
          'fly');
    });

    test('unmapped legacy effects fall back to fade', () {
      expect(EffectPreviewService.toPptxTransitionType(SlideEffect.dissolve),
          'fade');
    });
  });
}
