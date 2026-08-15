import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/action_button_service.dart';
import 'package:ghita_ppt_converter/services/equation_service.dart';
import 'package:ghita_ppt_converter/services/ole_service.dart';
import 'package:ghita_ppt_converter/services/symbol_service.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 18 tests — Action buttons, Equation, Symbol (FEAT 17, 18, 19, 20).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String actionDiv(ActionButton btn) =>
      '<div data-action=\'${btn.toJson().replaceAll("'", '&#39;')}\'></div>';

  String equationDiv(EquationData eq) =>
      '<div data-equation=\'${eq.toJson().replaceAll("'", '&#39;')}\'></div>';

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t18_');
    try {
      await PPTGenerator.generatePPT(
        [{'title': 'T18', 'htmlContent': htmlContent}],
        '${dir.path}/out.pptx',
      );
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  group('ActionButton (P1–P2)', () {
    test('ActionButton round-trips through JSON', () {
      const btn = ActionButton(
        kind: ActionButtonKind.home,
        action: ActionType.slideFirst,
        label: 'Home',
        x: 10, y: 20, w: 15, h: 8,
      );
      final restored = ActionButton.fromJson(btn.toJson());
      expect(restored.kind, ActionButtonKind.home);
      expect(restored.action, ActionType.slideFirst);
      expect(restored.x, 10);
    });

    test('defaultLabel returns correct labels', () {
      expect(const ActionButton(kind: ActionButtonKind.home).defaultLabel, 'Home');
      expect(const ActionButton(kind: ActionButtonKind.next).defaultLabel, 'Next');
      expect(const ActionButton(kind: ActionButtonKind.help).defaultLabel, 'Help');
    });

    test('htmlMarkup produces a styled button div', () {
      const btn = ActionButton(
        kind: ActionButtonKind.next, label: 'Next', x: 40, y: 85, w: 10, h: 6);
      final html = btn.htmlMarkup;
      expect(html, contains('left:40.0%'));
      expect(html, contains('top:85.0%'));
      expect(html, contains('>Next</div>'));
    });

    test('service actionsIn / actionMarkup / replaceActionAt', () {
      const btn = ActionButton(kind: ActionButtonKind.home);
      final html = '${actionDiv(btn)}\n<p>text</p>';
      expect(ActionButtonService.actionCount(html), 1);
      expect(ActionButtonService.actionsIn(html).length, 1);
      const btn2 = ActionButton(kind: ActionButtonKind.end);
      final replaced = ActionButtonService.replaceActionAt(html, 0, btn2);
      expect(ActionButtonService.actionsIn(replaced).first.kind, ActionButtonKind.end);
    });

    test('PPTX export: action button becomes a p:sp with hlinkClick', () async {
      const btn = ActionButton(
        kind: ActionButtonKind.next, action: ActionType.slideNext,
        x: 40, y: 85, w: 10, h: 6);
      final archive = await exportPptx(actionDiv(btn));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('name="ActionButton next"'));
      expect(slideXml, contains('ppaction://hlinksldjump'));
      expect(slideXml, contains('prst="chevron"'));
    });

    test('PPTX export: action button with URL gets a hyperlink rel', () async {
      const btn = ActionButton(
        kind: ActionButtonKind.custom, action: ActionType.url,
        url: 'https://example.com', x: 10, y: 10, w: 20, h: 10);
      final archive = await exportPptx(actionDiv(btn));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('r:id="rId'));
      // Check the rels file has the hyperlink
      final relsXml = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(relsXml, contains('example.com'));
    });

    test('HTML export: action button renders as styled div', () {
      const btn = ActionButton(
        kind: ActionButtonKind.next, label: 'Next', x: 40, y: 85, w: 10, h: 6);
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': actionDiv(btn)},
      ]);
      expect(html, contains('data-action-html'));
      expect(html, contains('>Next</div>'));
    });

    test('Regression: deck without actions unchanged', () async {
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'Plain', 'htmlContent': '<h1>Hello</h1>'},
      ]);
      expect(html, isNot(contains('data-action')));
    });
  });

  group('Equation (P3–P4)', () {
    test('EquationData round-trips through JSON', () {
      const eq = EquationData(mathml: '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      final restored = EquationData.fromJson(eq.toJson());
      expect(restored.mathml, contains('mfrac'));
    });

    test('service equationsIn / equationMarkup / replaceEquationAt', () {
      const eq = EquationData(mathml: '<math><mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup></math>');
      final html = '${equationDiv(eq)}\n<p>x</p>';
      expect(EquationService.equationCount(html), 1);
      expect(EquationService.equationsIn(html).length, 1);
      const eq2 = EquationData(mathml: '<math><mn>42</mn></math>');
      final replaced = EquationService.replaceEquationAt(html, 0, eq2);
      expect(EquationService.equationsIn(replaced).first.mathml, contains('42'));
    });

    test('mathmlToOoxml converts fraction', () {
      final ooxml = EquationService.mathmlToOoxml(
          '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      expect(ooxml, isNotNull);
      expect(ooxml, contains('<m:f>'));
      expect(ooxml, contains('<m:num>'));
      expect(ooxml, contains('<m:den>'));
    });

    test('mathmlToOoxml converts sqrt', () {
      final ooxml = EquationService.mathmlToOoxml(
          '<math><msqrt><mi>x</mi></msqrt></math>');
      expect(ooxml, contains('<m:rad>'));
    });

    test('mathmlToOoxml converts superscript', () {
      final ooxml = EquationService.mathmlToOoxml(
          '<math><msup><mi>x</mi><mn>2</mn></msup></math>');
      expect(ooxml, contains('<m:sSup>'));
    });

    test('PPTX export: equation gets a:math namespace + m:oMath', () async {
      const eq = EquationData(mathml: '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      final archive = await exportPptx(equationDiv(eq));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"'));
      expect(slideXml, contains('m:oMath'));
      expect(slideXml, contains('<m:f>'));
    });

    test('HTML export: equation renders as inline SVG', () {
      const eq = EquationData(mathml: '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': equationDiv(eq)},
      ]);
      expect(html, contains('<svg'));
      expect(html, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(html, contains('viewBox'));
      expect(html, contains('role="img"'));
    });

    test('renderSvg produces valid SVG with fraction bar', () {
      final svg = EquationService.renderSvg(
          '<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
      expect(svg, contains('<svg'));
      expect(svg, contains('<line'));
      expect(svg, contains('stroke="#000"'));
    });

    test('renderSvg produces valid SVG with sqrt', () {
      final svg = EquationService.renderSvg(
          '<math><msqrt><mi>x</mi></msqrt></math>');
      expect(svg, contains('<path'));
      expect(svg, contains('fill="none"'));
    });
  });

  group('Symbol (P5)', () {
    test('SymbolService has categories', () {
      expect(SymbolService.byCategory, isNotEmpty);
      expect(SymbolService.byCategory.containsKey('Currency'), isTrue);
      expect(SymbolService.byCategory.containsKey('Arrows'), isTrue);
    });

    test('SymbolService search finds by name', () {
      final results = SymbolService.search('Arrow');
      expect(results, isNotEmpty);
      // Search matches name or category — everything returned relates to arrows.
      expect(results.any((s) => s.name.toLowerCase().contains('arrow')), isTrue);
    });

    test('SymbolService search finds by code point', () {
      final results = SymbolService.search('€');
      expect(results, isNotEmpty);
      expect(results.any((s) => s.char == '€'), isTrue);
    });
  });

  group('OLE (P6)', () {
    test('OleData round-trips through JSON', () {
      const ole = OleData(fileName: 'test.xlsx', iconLabel: 'Sheet', x: 30, y: 40, w: 20, h: 15);
      final restored = OleData.fromJson(ole.toJson());
      expect(restored.fileName, 'test.xlsx');
      expect(restored.x, 30);
    });

    test('service olesIn / oleMarkup / replaceOleAt', () {
      const ole = OleData(fileName: 'doc.docx', iconLabel: 'Doc');
      final html = '${OleService.oleMarkup(ole)}\n<p>text</p>';
      expect(OleService.oleCount(html), 1);
      expect(OleService.olesIn(html).length, 1);
    });

    test('htmlMarkup produces a styled document icon', () {
      const ole = OleData(fileName: 'data.xlsx', iconLabel: 'Data');
      final html = ole.htmlMarkup;
      expect(html, contains('📄'));
      expect(html, contains('data-ole-html'));
      expect(html, contains('data.xlsx'));
    });

    test('PPTX export: OLE block emits oleObj with oleRid', () async {
      const ole = OleData(
        fileName: 'test.xlsx',
        fileBytes: [0, 1, 2, 3, 4],
        iconLabel: 'Sheet',
        x: 30, y: 40, w: 20, h: 15,
      );
      final markup = OleService.oleMarkup(ole);
      final archive = await exportPptx(markup);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('oleObj'));
      expect(slideXml, contains('progId="Excel.Sheet"'));
      // The oleObject binary is stored in ppt/media/ (via _MediaFile).
      final oleFiles = archive.files.where((e) =>
          e.name.startsWith('ppt/media/') && e.name.contains('oleObject')).toList();
      expect(oleFiles, isNotEmpty);
    });

    test('HTML export: OLE renders as styled div', () {
      const ole = OleData(fileName: 'report.pdf', iconLabel: 'Report');
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': OleService.oleMarkup(ole)},
      ]);
      expect(html, contains('📄'));
      expect(html, contains('report.pdf'));
    });
  });

  group('Regression (P10)', () {
    test('Hyperlink text still works unchanged', () async {
      const html = '<p>Visit <a href="https://example.com">Example</a></p>';
      final archive = await exportPptx(html);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('hlinkClick'));
      // The URL lives in the rels file (external target).
      final relsXml = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(relsXml, contains('example.com'));
      expect(relsXml, contains('TargetMode="External"'));
    });

    test('Plain slide without any track 18 features exports unchanged', () async {
      final archive = await exportPptx('<h1>Hello</h1>');
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, isNot(contains('ActionButton')));
      expect(slideXml, isNot(contains('m:oMath')));
    });
  });
}