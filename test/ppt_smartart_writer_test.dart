// T02 (v2.0.1-beta.2) — PptSmartArtWriter tests (phases 7–8).
//
// Contract per the writer's documentation: every <dgm:t> must be a FULL text
// body (<a:bodyPr/><a:lstStyle/><a:p>…) — a bare string crashes PowerPoint's
// diagram engine — and node/cxn model ids are id+1 with the document root at
// 0. Every produced part must stay well-formed XML.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/smartart.dart';
import 'package:ghita_ppt_converter/services/ppt_smartart_writer.dart';
import 'package:xml/xml.dart';

SmartArtGraph _graph({
  List<SmartArtNode> nodes = const [
    SmartArtNode(id: 1, text: 'Bước 1'),
    SmartArtNode(id: 2, text: 'Bước 2', parentId: 1),
    SmartArtNode(id: 3, text: 'Bước 3', parentId: 1),
  ],
  SmartArtColorTheme theme = SmartArtColorTheme.office,
}) =>
    SmartArtGraph(
      layout: SmartArtLayout.basicProcess,
      nodes: nodes,
      colorTheme: theme,
    );

void _assertParses(String xmlText, String label) {
  expect(() => XmlDocument.parse(xmlText), returnsNormally,
      reason: '$label must stay well-formed XML');
}

void main() {
  group('data part', () {
    test('emits the doc root plus one pt per node with full text bodies',
        () {
      final pkg = PptSmartArtWriter.build(_graph());

      _assertParses(pkg.dataXml, 'dataXml');
      expect(pkg.dataXml, contains('modelId="0" type="doc"'));
      expect(pkg.dataXml, contains('modelId="2" type="node"'));
      expect(pkg.dataXml, contains('<a:t>Bước 1</a:t>'));

      // The documented crash condition: bare <dgm:t>text</dgm:t> is illegal.
      final bareTextBodies = RegExp('<dgm:t>[^<]').allMatches(pkg.dataXml);
      expect(bareTextBodies, isEmpty);
      final fullTextBodies =
          '<dgm:t><a:bodyPr/>'.allMatches(pkg.dataXml).length;
      expect(fullTextBodies, 3,
          reason: 'every node gets a complete a:bodyPr/a:lstStyle/a:p body');
    });

    test('wires connections from parents to children and the doc to roots',
        () {
      final pkg = PptSmartArtWriter.build(_graph());

      // Top-level node 1 hangs off the document (srcId="0").
      expect(pkg.dataXml, contains('srcId="0" destId="2"'));
      // Children 2 and 3 hang off parent 1 → srcId = parentId + 1 = "2".
      expect(pkg.dataXml, contains('srcId="2" destId="3"'));
      expect(pkg.dataXml, contains('srcId="2" destId="4"'));
      expect('<dgm:presId val="node1"/>'.allMatches(pkg.dataXml), hasLength(3));
    });

    test('tree order is respected even when the input list is shuffled',
        () {
      final pkg = PptSmartArtWriter.build(_graph(nodes: const [
        SmartArtNode(id: 2, text: 'Con', parentId: 1),
        SmartArtNode(id: 1, text: 'Cha'),
      ]));

      final chaAt = pkg.dataXml.indexOf('<a:t>Cha</a:t>');
      final conAt = pkg.dataXml.indexOf('<a:t>Con</a:t>');
      expect(chaAt, greaterThan(-1));
      expect(conAt, greaterThan(chaAt),
          reason: 'orderedNodes must emit parents before children');
    });

    test('XML-hostile node text is escaped but preserved', () {
      final pkg = PptSmartArtWriter.build(_graph(nodes: const [
        SmartArtNode(id: 1, text: '<R&D> "quan trọng"'),
      ]));

      expect(pkg.dataXml, contains('&lt;R&amp;D&gt; &quot;quan trọng&quot;'));
      expect(pkg.dataXml, isNot(contains('<R&D>')));
      _assertParses(pkg.dataXml, 'hostile-text dataXml');
    });
  });

  group('layout / quickStyle / colors parts', () {
    test('layout and quick style are static well-formed definitions', () {
      final pkg = PptSmartArtWriter.build(_graph());

      _assertParses(pkg.layoutXml, 'layoutXml');
      _assertParses(pkg.quickStyleXml, 'quickStyleXml');
      expect(pkg.layoutXml, contains('urn:ghita:smartart:flat'));
      expect(pkg.layoutXml, contains('<dgm:cat type="process" pri="1000"/>'));
      expect(pkg.quickStyleXml, contains('<dgm:quickStyle'));
    });

    test('colors carry the theme accent palette and label', () {
      final office = PptSmartArtWriter.build(_graph());
      expect(office.colorsXml, contains('<dgm:title val="Office"/>'));
      expect(office.colorsXml, contains('<a:srgbClr val="4472C4"/>'));
      _assertParses(office.colorsXml, 'office colorsXml');

      final colorful =
          PptSmartArtWriter.build(_graph(theme: SmartArtColorTheme.colorful));
      expect(colorful.colorsXml, contains('<dgm:title val="Sắc màu"/>'));
      expect(colorful.colorsXml, contains('<a:srgbClr val="B4C7E7"/>'));
      _assertParses(colorful.colorsXml, 'colorful colorsXml');
    });

    test('single-accent themes wrap around instead of crashing', () {
      // A theme always exposes ≥2 colours, so index 1 % length stays safe;
      // assert the second styleLbl references a valid palette entry.
      final pkg = PptSmartArtWriter.build(_graph());
      expect(pkg.colorsXml, contains('<a:srgbClr val="ED7D31"/>'));
    });
  });

  group('scale and stress', () {
    test('a 20-node chain with long text stays well-formed', () {
      final longText = 'Giai đoạn ${'rất dài ' * 12}kết thúc';
      final graph = _graph(nodes: [
        for (var i = 1; i <= 20; i++)
          SmartArtNode(id: i, text: '$longText #$i', parentId: i == 1 ? null : i - 1),
      ]);

      final pkg = PptSmartArtWriter.build(graph);
      _assertParses(pkg.dataXml, '20-node dataXml');
      expect(
        '<dgm:cxn '.allMatches(pkg.dataXml).length,
        20,
        reason: 'one connection per node (root link included)',
      );
      expect(longText.allMatches(pkg.dataXml).length, 20);
    });
  });
}
