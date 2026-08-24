// T02 (v2.0.1-beta.2) — P9 engine round-trip.
//
// One slide carrying a chart block, a SmartArt block and a merged polygon
// shape goes through PPTGenerator.generatePPT; the produced package must
// carry the chart part + embedded workbook, the four diagram parts, their
// content-type overrides, and a slide XML that binds everything.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/chart_data.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/models/smartart.dart';
import 'package:ghita_ppt_converter/services/chart_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/smartart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chart + smartart + merged shape survive a full PPTX export',
      () async {
    const chart = ChartData(
      type: ChartType.column,
      title: 'Doanh thu',
      categories: ['Q1', 'Q2'],
      series: [ChartSeries(name: 'Nội bộ', values: [120, 180])],
    );
    const graph = SmartArtGraph(
      layout: SmartArtLayout.basicProcess,
      title: 'Quy trình',
      nodes: [
        SmartArtNode(id: 1, text: 'Bước 1'),
        SmartArtNode(id: 2, text: 'Bước 2', parentId: 1),
      ],
    );

    final html = "<div data-chart='${ChartService.escapeAttribute(chart)}'>"
        '</div>'
        '${SmartArtService.smartartMarkup(graph)}';

    // A boolean-merged freeform shape (the polygon_boolean consumer).
    const mergedShape = DrawnShape(
      id: 'sh_merged',
      type: ShapeType.merged,
      x: 5,
      y: 5,
      w: 40,
      h: 30,
      mergeOp: 'union',
      mergedIds: ['sh_a', 'sh_b'],
      fillColor: '#3B82F6',
    );

    final dir = await Directory.systemTemp.createTemp('ghita_t02_roundtrip');
    try {
      await PPTGenerator.generatePPT([
        {
          'title': 'Engine round-trip',
          'htmlContent': html,
          'visualElements': {
            'shapes': [mergedShape.toMap()],
          },
        },
      ], '${dir.path}/out.pptx');

      final archive = ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
      String part(String name) => utf8.decode(
        archive.files.firstWhere((f) => f.name == name).content as List<int>,
      );
      final names = archive.files.map((f) => f.name).toList();

      expect(names, contains('ppt/charts/chart1.xml'));
      expect(names, contains('ppt/charts/_rels/chart1.xml.rels'));
      expect(names, contains('ppt/embeddings/Microsoft_Excel_Sheet1.xlsx'));
      expect(names, contains('ppt/diagrams/data1.xml'));
      expect(names, contains('ppt/diagrams/layout1.xml'));
      expect(names, contains('ppt/diagrams/quickStyle1.xml'));
      expect(names, contains('ppt/diagrams/colors1.xml'));

      final contentTypes = part('[Content_Types].xml');
      expect(contentTypes, contains('/ppt/charts/chart1.xml'));
      expect(contentTypes, contains('/ppt/diagrams/data1.xml'));

      final chartXml = part('ppt/charts/chart1.xml');
      expect(chartXml, contains('<c:v>120.0</c:v>'));

      final dataXml = part('ppt/diagrams/data1.xml');
      expect(dataXml, contains('<a:t>Bước 1</a:t>'));

      final slideXml = part('ppt/slides/slide1.xml');
      expect(slideXml, contains('dgm:relIds'),
          reason: 'the documented PowerPoint-safe diagram binding form');
      expect(slideXml, contains('graphicFrame'),
          reason: 'the chart rides in a graphic frame');
      expect(slideXml, contains('sh_merged'),
          reason: 'the merged polygon shape is exported');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
