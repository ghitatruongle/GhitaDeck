import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/slide.dart';

void main() {
  group('Slide model', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final slide = Slide(
        title: 'Hello',
        htmlContent: '<p>World</p>',
        notes: 'Speaker note',
        effect: SlideEffect.zoom,
        timestamp: 12345,
      );
      final restored = Slide.fromMap(slide.toMap());
      expect(restored.title, 'Hello');
      expect(restored.htmlContent, '<p>World</p>');
      expect(restored.notes, 'Speaker note');
      expect(restored.effect, SlideEffect.zoom);
      expect(restored.timestamp, 12345);
    });

    test('fromMap is backward compatible with legacy maps', () {
      // Legacy persisted slides only had title/htmlContent/timestamp.
      final slide = Slide.fromMap({
        'title': 'Old',
        'htmlContent': '<p>Legacy</p>',
        'timestamp': 999,
      });
      expect(slide.title, 'Old');
      expect(slide.htmlContent, '<p>Legacy</p>');
      expect(slide.notes, '');
      expect(slide.effect, isNull);
      expect(slide.timestamp, 999);
    });

    test('fromMap tolerates missing/invalid fields', () {
      final slide = Slide.fromMap({'effect': 'not_an_effect'});
      expect(slide.title, 'Untitled Slide');
      expect(slide.htmlContent, '');
      expect(slide.effect, isNull);
      expect(slide.timestamp, greaterThan(0));
    });

    test('toMap omits empty notes and null effect', () {
      final map = Slide(title: 'T', htmlContent: '<p>x</p>').toMap();
      expect(map.containsKey('notes'), isFalse);
      expect(map.containsKey('effect'), isFalse);
    });

    test('copyWith clearEffect resets the override', () {
      final slide = Slide(
          title: 'T', htmlContent: '', effect: SlideEffect.fade);
      expect(slide.copyWith(clearEffect: true).effect, isNull);
      expect(slide.copyWith(effect: SlideEffect.wipe).effect,
          SlideEffect.wipe);
      expect(slide.copyWith().effect, SlideEffect.fade);
    });
  });
}
