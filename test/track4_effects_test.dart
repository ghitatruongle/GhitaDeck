import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/slide.dart';
import 'package:ghita_deck/services/effect_preview_service.dart';

void main() {
  group('Track 4 real transition keyframes', () {
    test('every Track 33 effect has keyframes distinct from the fade default',
        () {
      const defaultFade = 'from { opacity: 0; } to { opacity: 1; }';
      final track33 = SlideEffect.values
          .where((e) => EffectPreviewService.getEffectCategory(e) == 'Track 33')
          .toList();
      expect(track33.length, 26);
      for (final effect in track33) {
        final css = EffectPreviewService.generateEffectCss(effect);
        expect(css.contains('@keyframes'), isTrue, reason: '$effect name');
        expect(css.contains(defaultFade), isFalse,
            reason: '$effect still uses the plain fade default');
      }
    });

    test('each Track 33 effect has its own class name and easing', () {
      final cssAll = EffectPreviewService.generateAllEffectsCss();
      for (final name in const [
        'dissolve',
        'pageCurl',
        'ripple',
        'vortex',
        'origami',
        'honeycomb',
      ]) {
        expect(cssAll.contains('.slide-transition-$name{'), isTrue,
            reason: '$name class missing');
      }
      expect(cssAll.contains('cubic-bezier'), isTrue);
      expect(cssAll.contains('steps(6, end)'), isTrue);
    });

    test('deck CSS honors per-slide duration via CSS variable', () {
      final css = EffectPreviewService.generateEffectsCss(
        const [SlideEffect.pageCurl, SlideEffect.fade],
        duration: 0.5,
      );
      expect(css.contains('var(--st-duration,0.5s)'), isTrue);
      expect(
        RegExp(r'slide-transition-pageCurl\{[^}]*cubic-bezier')
            .hasMatch(css),
        isTrue,
      );
    });
  });
}
