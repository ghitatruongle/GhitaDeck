import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/services/format_painter_service.dart';

void main() {
  group('FormatSnapshot — text (HTML)', () {
    test('captures inline CSS from an HTML fragment', () {
      final snap = FormatSnapshot.fromHtmlFragment(
        '<span style="font-size: 24px; color: #FF0000; font-weight: bold;">Hello</span>',
      );
      expect(snap.css['font-size'], '24px');
      expect(snap.css['color'], '#FF0000');
      expect(snap.bold, isTrue);
    });

    test('detects <b>/<i>/<u> wrappers', () {
      final snap = FormatSnapshot.fromHtmlFragment('<b><i>text</i></b>');
      expect(snap.bold, isTrue);
      expect(snap.italic, isTrue);
      expect(snap.underline, isFalse);
    });

    test('applies snapshot by wrapping a plain text selection', () {
      const snap = FormatSnapshot(
        css: {'color': '#00AA00', 'font-size': '18px'},
        bold: true,
        underline: true,
      );
      final out = snap.applyToSelection('target');
      expect(out, contains('<b>'));
      expect(out, contains('<u>'));
      expect(out, contains('style="color: #00AA00; font-size: 18px"'));
      expect(out, contains('target'));
    });

    test('empty snapshot reports isEmpty', () {
      expect(const FormatSnapshot().isEmpty, isTrue);
      expect(
        const FormatSnapshot(css: {'color': '#000'}).isEmpty,
        isFalse,
      );
    });
  });

  group('FormatSnapshot — shape', () {
    test('captures fill/stroke/gradient from a DrawnShape', () {
      const shape = DrawnShape(
        id: 's1',
        type: ShapeType.rect,
        fillColor: '#4472C4',
        fillTransparency: 0.3,
        strokeColor: '#000000',
        strokeWidth: 2.5,
        gradientStart: '#FF8A00',
        gradientEnd: '#E52E71',
        gradientAngle: 45,
      );
      final snap = FormatSnapshot.fromShape(shape);
      expect(snap.fillColor, '#4472C4');
      expect(snap.fillTransparency, 0.3);
      expect(snap.strokeWidth, 2.5);
      expect(snap.gradientStart, '#FF8A00');
      expect(snap.gradientAngle, 45);
    });

    test('applies shape style to another shape (copy-on-write)', () {
      const source =
          DrawnShape(id: 'src', fillColor: '#FF0000', strokeWidth: 4, strokeColor: '#00FF00');
      const target = DrawnShape(id: 'tgt', type: ShapeType.oval, x: 10, y: 20, w: 30, h: 40);
      final snap = FormatSnapshot.fromShape(source);
      final updated = snap.applyToShape(target);
      expect(updated.id, 'tgt');
      expect(updated.type, ShapeType.oval);
      expect(updated.x, 10); // geometry untouched
      expect(updated.fillColor, '#FF0000');
      expect(updated.strokeWidth, 4);
      expect(updated.strokeColor, '#00FF00');
      // original untouched
      expect(target.fillColor, '#4472C4');
    });
  });

  group('FormatPainterService — capture/use semantics', () {
    test('one-shot paste disarms after use', () {
      final svc = FormatPainterService();
      svc.capture(const FormatSnapshot(css: {'color': '#123456'}));
      expect(svc.isArmed, isTrue);
      final snap = svc.use();
      expect(snap, isNotNull);
      expect(svc.isArmed, isFalse);
      expect(svc.use(), isNull);
    });

    test('persistent paste keeps the painter armed', () {
      final svc = FormatPainterService();
      svc.capture(const FormatSnapshot(css: {'color': '#123456'}), persistent: true);
      expect(svc.use(persistent: true), isNotNull);
      expect(svc.isArmed, isTrue);
      svc.clear();
      expect(svc.isArmed, isFalse);
    });

    test('nothing to use before capture', () {
      final svc = FormatPainterService();
      expect(svc.use(), isNull);
    });
  });
}
