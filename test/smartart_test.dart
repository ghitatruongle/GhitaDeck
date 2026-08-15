import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/smartart.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/smartart_service.dart';
import 'package:xml/xml.dart' as xml;

/// Track 10 tests — SmartArt (FEAT 4).
///
///  * model round-trip, relayout keeps nodes, colour themes (P1–P2, P6),
///  * PPTX carries the `<dgm:>` package (data + layout + quickStyle +
///    colors + relIds), deduplicated per definition (P3),
///  * HTML/PDF render diagrams (P4),
///  * empty diagrams are skipped (P10),
///  * decks without SmartArt stay unchanged (P10 regression).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String diagramDiv(SmartArtGraph graph) =>
      '<div data-smartart=\'${graph.toJson().replaceAll("'", '&#39;')}\'></div>';

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t10_');
    try {
      await PPTGenerator.generatePPT(
        [
          {'title': 'SmartArt', 'htmlContent': htmlContent},
        ],
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

  group('model (P1–P2, P6)', () {
    test('SmartArtGraph round-trips through JSON', () {
      const graph = SmartArtGraph(
        layout: SmartArtLayout.chevronProcess,
        title: 'Quy trình',
        colorTheme: SmartArtColorTheme.colorful,
        nodes: [
          SmartArtNode(id: 1, text: 'Bước 1'),
          SmartArtNode(id: 2, text: 'Bước 2'),
          SmartArtNode(id: 3, text: 'Bước 3', parentId: 2),
        ],
      );
      final restored = SmartArtGraph.fromJson(graph.toJson())!;
      expect(restored.layout, SmartArtLayout.chevronProcess);
      expect(restored.colorTheme, SmartArtColorTheme.colorful);
      expect(restored.orderedNodes.length, 3);
      expect(restored.orderedNodes.last.parentId, 2);
    });

    test('relayout preserves the node texts (P6)', () {
      final graph = SmartArtGraph.sample(SmartArtLayout.basicProcess);
      final relaid = graph.relayout(SmartArtLayout.orgChart);
      expect(relaid.layout, SmartArtLayout.orgChart);
      expect(relaid.nodes.map((n) => n.text).toList(),
          graph.nodes.map((n) => n.text).toList());
      // Colour theme swap keeps content.
      final recolored = relaid.copyWith(colorTheme: SmartArtColorTheme.gradient);
      expect(recolored.nodes.length, relaid.nodes.length);
    });
  });

  group('PPTX <dgm:> package (P3)', () {
    test('diagram parts + relIds are emitted for a smartart block', () async {
      final graph = SmartArtGraph.sample(SmartArtLayout.basicProcess);
      final archive = await exportPptx('${diagramDiv(graph)}<p>Nội dung</p>');

      final data = part(archive, 'ppt/diagrams/data1.xml');
      expect(() => xml.XmlDocument.parse(data), returnsNormally);
      expect(data, contains('<dgm:dataModel'));
      expect(data, contains('<dgm:ptLst>'));
      // P8 (real PowerPoint): <dgm:t> is a full text body, not a bare string.
      expect(data, contains('<dgm:t><a:bodyPr/>'));
      expect(data, contains('<a:t>Mục 1</a:t>'));
      expect(data, contains('<dgm:cxnLst>'));
      expect(data, contains('srcId="0"'));

      final layout = part(archive, 'ppt/diagrams/layout1.xml');
      expect(() => xml.XmlDocument.parse(layout), returnsNormally);
      expect(layout, contains('<dgm:layoutDef'));
      expect(layout, contains('layoutNode'));

      final style = part(archive, 'ppt/diagrams/quickStyle1.xml');
      final colors = part(archive, 'ppt/diagrams/colors1.xml');
      expect(() => xml.XmlDocument.parse(style), returnsNormally);
      expect(() => xml.XmlDocument.parse(colors), returnsNormally);
      expect(colors, contains('4472C4')); // office theme accent1

      // Slide: <dgm:relIds> binding with the four relationship ids (the form
      // real PowerPoint requires — the legacy dgm:dataId attribute form is
      // rejected with a corrupt-file error).
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(slide, contains('<p:graphicFrame>'));
      expect(slide, contains('r:dm="'));
      expect(slide, contains('r:lo="'));
      expect(slide, contains('r:qs="'));
      expect(slide, contains('r:cs="'));
      // Rels point at the right diagram parts.
      final rels = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(rels, contains('diagramData'));
      expect(rels, contains('Target="../diagrams/data1.xml"'));
      expect(rels, contains('diagramLayout'));
      expect(rels, contains('diagramQuickStyle'));
      expect(rels, contains('diagramColors'));
      // Content types declare the diagram parts.
      final contentTypes = part(archive, '[Content_Types].xml');
      expect(contentTypes, contains('PartName="/ppt/diagrams/data1.xml"'));
      expect(contentTypes, contains('PartName="/ppt/diagrams/layout1.xml"'));
    });

    test('identical diagrams share one data part (dedupe)', () async {
      final graph = SmartArtGraph.sample(SmartArtLayout.chevronProcess);
      final archive = await exportPptx(
          '${diagramDiv(graph)}<p>x</p>${diagramDiv(graph)}');
      final dataParts = archive.files
          .where((e) =>
              e.name.startsWith('ppt/diagrams/data') && e.name.endsWith('.xml'))
          .toList();
      expect(dataParts.length, 1, reason: 'one data part for two occurrences');
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(RegExp('<p:graphicFrame>').allMatches(slide).length, 2);
    });

    test('empty diagrams are skipped (P10)', () async {
      const empty = SmartArtGraph(layout: SmartArtLayout.basicProcess, nodes: []);
      final archive = await exportPptx('${diagramDiv(empty)}<p>Vẫn xuất</p>');
      expect(archive.files.any((e) => e.name.startsWith('ppt/diagrams/')),
          isFalse);
    });

    test('deck without SmartArt carries no diagram parts (P10 regression)',
        () async {
      final archive = await exportPptx('<p>Chỉ có văn bản</p>');
      expect(archive.files.any((e) => e.name.startsWith('ppt/diagrams/')),
          isFalse);
      final contentTypes = part(archive, '[Content_Types].xml');
      expect(contentTypes, isNot(contains('diagramData+xml')));
    });
  });

  group('HTML + PDF (P4)', () {
    test('HTML deck renders inline SVG for every group', () {
      for (final group in SmartArtGroup.values) {
        final layout = SmartArtLayout.values.firstWhere((l) => l.group == group);
        final graph = SmartArtGraph.sample(layout);
        final html = HtmlExportService().buildPresentationHtml([
          {
            'title': 'S',
            'htmlContent': diagramDiv(graph),
          }
        ]);
        expect(html, contains('<svg '), reason: group.name);
        expect(html, contains('data-smartart'), reason: group.name);
      }
    });

    test('SVG renders each group and a friendly empty state', () {
      for (final group in SmartArtGroup.values) {
        final layout = SmartArtLayout.values.firstWhere((l) => l.group == group);
        final svg = SmartArtService.renderSvg(SmartArtGraph.sample(layout));
        expect(svg, startsWith('<svg '), reason: group.name);
        expect(svg, endsWith('</svg>'), reason: group.name);
      }
      const empty = SmartArtGraph(layout: SmartArtLayout.basicProcess, nodes: []);
      final svg = SmartArtService.renderSvg(empty);
      expect(svg, contains('Không có nội dung SmartArt'));
    });

    test('PDF export renders a slide with SmartArt', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t10_pdf_');
      try {
        final graph = SmartArtGraph.sample(SmartArtLayout.basicPyramid);
        await PdfExportService().exportToPdf(
          [
            {
              'title': 'SmartArt',
              'htmlContent': diagramDiv(graph),
            }
          ],
          '${dir.path}/out.pdf',
        );
        final bytes = File('${dir.path}/out.pdf').readAsBytesSync();
        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}