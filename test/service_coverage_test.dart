import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/object_animation.dart';
import 'package:ghita_deck/services/animation_engine.dart';
import 'package:ghita_deck/services/icon_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimationEngine', () {
    test('every effect has a display name and a group', () {
      for (final e in AnimationEffect.values) {
        expect(AnimationEngine.effectNames[e], isNotNull, reason: '$e');
      }
      for (final e in AnimationEffect.values) {
        expect(AnimationEngine.groupOf(e).toString(), isNotEmpty);
      }
      final grouped = AnimationEngine.effectsByGroup();
      final total = grouped.values.expand((v) => v).length;
      expect(total, AnimationEffect.values.length);
    });

    test('keyframes are generated for every effect', () {
      for (final e in AnimationEffect.values) {
        final css = AnimationEngine.keyframesFor(e);
        expect(css.contains('@keyframes'), isTrue, reason: '$e');
      }
    });

    test('motion presets exist and produce keyframes', () {
      final presets = AnimationEngine.motionPresets();
      expect(presets, isNotEmpty);
      for (final entry in presets.entries) {
        final css = AnimationEngine.motionKeyframes(
            'path-${entry.key.name}', entry.value);
        expect(css.contains('@keyframes'), isTrue);
      }
    });

    test('cssClass sanitizes and selectorFor scopes', () {
      const anim = ObjectAnimation(
        shapeId: 'shape 1!',
        effect: AnimationEffect.fadeIn,
        group: AnimationGroup.entrance,
        duration: 0.8,
      );
      final cls = AnimationEngine.cssClass(anim);
      expect(cls.contains(' '), isFalse);
      expect(AnimationEngine.selectorFor(anim),
          '[data-ghita-id="shape 1!"]');
      final shorthand = AnimationEngine.animationShorthand(anim);
      expect(shorthand.contains('0.8s'), isTrue);
    });

    test('cssFor emits declarations for a list', () {
      const list = [
        ObjectAnimation(
            shapeId: 'a',
            effect: AnimationEffect.flyIn,
            group: AnimationGroup.entrance,
            duration: 0.4),
        ObjectAnimation(
            shapeId: 'b',
            effect: AnimationEffect.zoomIn,
            group: AnimationGroup.entrance,
            duration: 1.2),
      ];
      final css = AnimationEngine.cssFor(list);
      expect(css.contains('@keyframes'), isTrue);
      expect(AnimationEngine.orderIndex(list.first), greaterThanOrEqualTo(0));
      expect(
          AnimationEngine.orderIndex(list.last),
          greaterThanOrEqualTo(AnimationEngine.orderIndex(list.first)));
    });
  });

  group('IconLibraryService', () {
    test('search by name and category', () {
      final hits = IconLibraryService.search('add');
      expect(hits, isNotEmpty);
      expect(
          hits.any((i) => i.name.toLowerCase().contains('add')), isTrue);
      expect(IconLibraryService.search('zzzz-no-match'), isEmpty);
    });

    test('escapeAttribute and iconMarkup round-trip', () {
      final icon = IconLibraryService.search('Close').first;
      final escaped = IconLibraryService.escapeAttribute(icon);
      expect(escaped.contains('&'), isFalse);
      final markup = IconLibraryService.iconMarkup(icon);
      expect(markup.contains('data-icon'), isTrue);
    });

    test('iconCount and replaceIconAt', () {
      final icon = IconLibraryService.search('Add').first;
      const html = '<p>Hello</p>';
      expect(IconLibraryService.iconCount(html), 0);
      final withIcon = IconLibraryService.replaceIconAt(
          IconLibraryService.iconMarkup(icon), 0, icon);
      expect(IconLibraryService.iconCount(withIcon), 1);
    });

    test('iconsByCategory groups everything', () {
      final grouped = IconLibraryService.iconsByCategory;
      expect(grouped, isNotEmpty);
      final total = grouped.values.expand((v) => v).length;
      expect(total, greaterThan(100));
    });

    test('iconsIn extracts icons from deck html', () {

      final icon = IconLibraryService.search('Add').first;
      final html = IconLibraryService.iconMarkup(icon);
      final found = IconLibraryService.iconsIn(html);
      expect(found, isNotEmpty);
    });
  });
}
