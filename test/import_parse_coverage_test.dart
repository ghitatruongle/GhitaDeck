import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/drawn_shape.dart';
import 'package:ghita_deck/services/advanced_import_service.dart';
import 'package:ghita_deck/services/equation_service.dart';
import 'package:ghita_deck/services/shape_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdvancedImportService.parseMarkdown', () {
    test('headings become slides with titles', () {
      final slides = AdvancedImportService.parseMarkdown(
          '# Alpha\nbody one\n---\n## Beta\nbody two');
      expect(slides, hasLength(2));
      expect(slides.first.title, 'Alpha');
      expect(slides.first.htmlContent.contains('body one'), isTrue);
      expect(slides.last.title, 'Slide 2');
      expect(slides.last.htmlContent.contains('Beta'), isTrue);
    });

    test('separator splits slides without headings', () {
      final slides = AdvancedImportService.parseMarkdown(
          'first\n---\nsecond');
      expect(slides, hasLength(2));
      expect(slides.first.title, 'Slide 1');
      expect(slides.last.title, 'Slide 2');
    });

    test('code fences render as pre blocks', () {
      final slides =
          AdvancedImportService.parseMarkdown('# Code\n```\nx=1\n```');
      expect(slides.single.htmlContent.contains('<pre><code>'), isTrue);
    });

    test('lists and bold/italic inline markup convert', () {
      final slides = AdvancedImportService.parseMarkdown(
          '# L\n- item **bold**\n- item2 *ital*');
      final html = slides.single.htmlContent;
      expect(html.contains('<li>'), isTrue);
      expect(html.contains('<b>bold</b>'), isTrue);
      expect(html.contains('<i>ital</i>'), isTrue);
    });

    test('tables convert to html tables', () {
      final slides = AdvancedImportService.parseMarkdown(
          '# T\n| a | b |\n|---|---|\n| 1 | 2 |');
      final html = slides.single.htmlContent;
      expect(html.contains('<table>'), isTrue);
      expect(html.contains('<td>1</td>'), isTrue);
    });

    test('empty input yields a single placeholder slide', () {
      expect(AdvancedImportService.parseMarkdown(''), hasLength(1));
    });
  });

  group('EquationService deep MathML', () {
    test('nested fraction with square root converts', () {
      final out = EquationService.mathmlToOoxml(
          '<math><mfrac><mrow><mn>1</mn></mrow>'
          '<msqrt><mrow><mn>2</mn></mrow></msqrt></mfrac></math>');
      expect(out, isNotNull);
      expect(out!.contains('<m:f>'), isTrue);
      expect(out.contains('<m:rad>'), isTrue);
    });

    test('subscript and superscript convert', () {
      final sub = EquationService.mathmlToOoxml(
          '<math><msub><mi>x</mi><mn>1</mn></msub></math>');
      expect(sub, isNotNull);
      final sup = EquationService.mathmlToOoxml(
          '<math><msup><mi>x</mi><mn>2</mn></msup></math>');
      expect(sup, isNotNull);
    });

    test('malformed markup falls back to a text run', () {
      expect(
          EquationService.mathmlToOoxml('<math><mfrac><mi>a</mi></math>'),
          '<m:r><m:t>a</m:t></m:r>');
    });
  });

  group('ShapeEngine subtract and gradients', () {
    DrawnShape rect(double x, double y, double w, double h) => DrawnShape(
          id: 'r$x$y',
          type: ShapeType.rect,
          x: x,
          y: y,
          w: w,
          h: h,
        );

    test('mergeSubtract of contained shape leaves an outer loop', () {
      final outer = rect(0, 0, 100, 100);
      final inner = rect(40, 40, 20, 20);
      final merged = ShapeEngine.mergeSubtract(outer, inner);
      expect(merged.type, ShapeType.merged);
      final points =
          ShapeEngine.debugPathPoints(merged.freeformPath);
      expect(points.length, greaterThanOrEqualTo(4));
    });

    test('renderPptxShape emits gradient fill when set', () {
      const shape = DrawnShape(
        id: 'g1',
        type: ShapeType.rect,
        x: 10,
        y: 10,
        w: 30,
        h: 20,
        gradientStart: '#FF8A00',
        gradientEnd: '#E52E71',
        gradientAngle: 45,
      );
      final xml = ShapeEngine.renderPptxShape(
          shapeId: 5, shape: shape, offX: 100, offY: 100, extCx: 300, extCy: 200);
      expect(xml.contains('gradFill'), isTrue);
      expect(xml.contains('FF8A00'), isTrue);
      expect(xml.contains('E52E71'), isTrue);
    });

    test('renderPptxShape solid fill has no gradient', () {
      final xml = ShapeEngine.renderPptxShape(
          shapeId: 6,
          shape: rect(10, 10, 30, 20),
          offX: 100,
          offY: 100,
          extCx: 300,
          extCy: 200);
      expect(xml.contains('gradFill'), isFalse);
      expect(xml.contains('solidFill'), isTrue);
    });
  });
}
