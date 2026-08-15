import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/text_layout_service.dart';

void main() {
  group('Track 28 — Replace font', () {
    test('replaces quoted and unquoted font families', () {
      const html = '<p style="font-family: \'Segoe UI\', sans-serif">Hi</p>'
          '<p style="font-family: Segoe UI">Yo</p>';
      final out = TextLayoutService.replaceFont(html, 'Segoe UI', 'Arial');
      expect(out, contains("font-family: 'Arial', sans-serif"));
      expect(out, contains('font-family: Arial'));
      expect(out, isNot(contains('Segoe UI')));
    });

    test('case-insensitive match', () {
      const html = '<p style="FONT-FAMILY: segoe ui">x</p>';
      final out = TextLayoutService.replaceFont(html, 'Segoe UI', 'Arial');
      expect(out.toLowerCase(), contains('font-family: arial'));
    });

    test('no match leaves html unchanged', () {
      const html = '<p style="font-family: Arial">x</p>';
      expect(TextLayoutService.replaceFont(html, 'Comic', 'Arial'), html);
    });
  });

  group('Track 28 — Change case', () {
    const html = '<p><b>Hello</b> <i>World</i></p>';
    test('upper', () {
      final out = TextLayoutService.changeCase(html, 'upper');
      expect(out, contains('HELLO'));
      expect(out, contains('WORLD'));
    });
    test('lower', () {
      final out = TextLayoutService.changeCase(html, 'lower');
      expect(out, contains('hello'));
      expect(out, contains('world'));
    });
    test('title', () {
      final out = TextLayoutService.changeCase(html, 'title');
      expect(out, contains('Hello'));
      expect(out, contains('World'));
    });
    test('toggle', () {
      final out = TextLayoutService.changeCase(html, 'toggle');
      expect(out, contains('hELLO'));
      expect(out, contains('wORLD'));
    });
    test('keeps tags', () {
      final out = TextLayoutService.changeCase(html, 'upper');
      expect(out, contains('<b>'));
      expect(out, contains('<i>'));
    });
  });

  group('Track 28 — Character spacing', () {
    test('sets letter-spacing on paragraphs', () {
      const html = '<p>Hello</p>';
      final out = TextLayoutService.setCharacterSpacing(html, 2.5);
      expect(out, contains('letter-spacing: 2.5px'));
    });
    test('replaces existing spacing', () {
      const html = '<p style="letter-spacing: 10px">Hello</p>';
      final out = TextLayoutService.setCharacterSpacing(html, 1);
      expect(out, contains('letter-spacing: 1px'));
      expect(out, isNot(contains('10px')));
    });
  });

  group('Track 28 — Text direction', () {
    test('vertical adds writing-mode', () {
      const html = '<p>Hello</p>';
      expect(
        TextLayoutService.setTextDirection(html, 'vertical'),
        contains('writing-mode: vertical-rl'),
      );
    });
    test('rotated90 adds transform', () {
      const html = '<p>Hello</p>';
      final out = TextLayoutService.setTextDirection(html, 'rotated90');
      expect(out, contains('writing-mode: vertical-rl'));
      expect(out, contains('transform: rotate(90deg)'));
    });
    test('horizontal removes vertical styles', () {
      const html = '<p style="writing-mode: vertical-rl; transform: rotate(90deg)">x</p>';
      final out = TextLayoutService.setTextDirection(html, 'horizontal');
      expect(out, isNot(contains('writing-mode')));
      expect(out, isNot(contains('transform')));
    });
    test('bodyPr direction mapping', () {
      expect(TextLayoutService.bodyPrDirection('vertical'), ' vert="vert"');
      expect(TextLayoutService.bodyPrDirection('rotated270'), ' vert="eaVert"');
      expect(TextLayoutService.bodyPrDirection('horizontal'), '');
    });
  });

  group('Track 28 — Autofit', () {
    test('shrink marks container', () {
      const html = '<div><p>Hello</p></div>';
      final out = TextLayoutService.setAutofit(html, 'shrink');
      expect(out, contains('data-autofit="shrink"'));
      expect(out, contains('overflow: hidden'));
    });
    test('resizeShape marks container', () {
      const html = '<div><p>Hello</p></div>';
      final out = TextLayoutService.setAutofit(html, 'resizeShape');
      expect(out, contains('data-autofit="resizeShape"'));
    });
  });

  group('Track 28 — Bullets & tabs', () {
    test('bullets set ol start + indent', () {
      const html = '<ol><li>One</li><li>Two</li></ol>';
      final out = TextLayoutService.setBullets(html, startAt: 3, level: 1);
      expect(out, contains('<ol start="3">'));
      expect(out, contains('margin-left: 24px'));
    });
    test('bullets replace marker with image', () {
      const html = '<ul><li>Item</li></ul>';
      final out = TextLayoutService.setBullets(html, image: 'icon.png');
      expect(out, contains("list-style-image: url('icon.png')"));
      expect(out, contains('list-style-type: none'));
    });
    test('tab stops stored as data attributes', () {
      const html = '<div><p>x</p></div>';
      final out = TextLayoutService.setTabStops(html, [50, 200], leader: '.');
      expect(out, contains('data-tabstops="50,200"'));
      expect(out, contains('data-tableader="."'));
    });
    test('tabListXml emits EMU positions with leader', () {
      final xml = TextLayoutService.tabListXml([50, 200], leader: '.');
      expect(xml, contains('<a:tabLst>'));
      expect(xml, contains('<a:tab pos="'));
      expect(xml, contains('leader="dot"'));
      expect(xml, contains('</a:tabLst>'));
    });
    test('bulletAutoNum emits startAt', () {
      expect(
        TextLayoutService.bulletAutoNum(3),
        contains('<a:buAutoNum type="arabicPeriod" startAt="3"/>'),
      );
    });
  });
}
