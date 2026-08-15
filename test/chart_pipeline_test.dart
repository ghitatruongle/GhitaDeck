import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/chart_data.dart';
import 'package:ghita_ppt_converter/services/chart_service.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

/// Track 08 tests — chart engine (FEAT 1–2).
///
///  * ChartData/ChartService round-trip + block detection (P1–P2),
///  * the PPTX package carries a real `<c:chart>` part + embedded xlsx +
///    rels + content-types, deduplicated per definition (P4),
///  * every chart type renders inline SVG (P6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String chartDiv(ChartData chart) =>
      "<div data-chart='${ChartService.escapeAttribute(chart)}'></div>";

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t08_');
    try {
      await PPTGenerator.generatePPT(
        [
          {'title': 'Chart slide', 'htmlContent': htmlContent},
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

  group('model + service (P1–P2)', () {
    test('ChartData round-trips through JSON', () {
      const chart = ChartData(
        type: ChartType.column,
        title: 'Doanh thu',
        categories: ['Q1', 'Q2'],
        series: [
          ChartSeries(name: 'Nội bộ', values: [120, 180]),
          ChartSeries(name: 'Xuất khẩu', values: [70, 90]),
        ],
        style: ChartStyle(showDataLabels: true),
      );
      final restored = ChartData.fromJson(chart.toJson())!;
      expect(restored.type, ChartType.column);
      expect(restored.title, 'Doanh thu');
      expect(restored.series.length, 2);
      expect(restored.series[1].values, [70, 90]);
      expect(restored.style.showDataLabels, isTrue);
      expect(restored.maxValue, 180);
    });

    test('chartsIn detects every embedded block in document order', () {
      const a = ChartData(type: ChartType.pie, title: 'A');
      const b = ChartData(type: ChartType.line, title: 'B');
      final html = '<p>x</p>${chartDiv(a)}<p>y</p>${chartDiv(b)}';
      final charts = ChartService.chartsIn(html);
      expect(charts.length, 2);
      expect(charts[0].type, ChartType.pie);
      expect(charts[1].type, ChartType.line);
    });
  });

  group('PPTX chart package (P4)', () {
    test('slide with a chart carries chart1.xml + xlsx + rels + content types',
        () async {
      final chart = ChartData.sample(ChartType.column);
      final archive = await exportPptx('${chartDiv(chart)}<p>Nội dung</p>');

      final chartXml = part(archive, 'ppt/charts/chart1.xml');
      expect(() => xml.XmlDocument.parse(chartXml), returnsNormally);
      expect(chartXml, contains('<c:chartSpace'));
      expect(chartXml, contains('<c:barChart><c:barDir val="col"/>'));
      expect(chartXml, contains('<c:ser><c:idx val="0"/>'));
      // Series names live in the embedded workbook (B1), like Excel's own
      // charts — no c:tx in the series.
      expect(chartXml, isNot(contains('<c:tx>')));
      expect(chartXml, contains('Sheet1!\$A\$2:\$A\$5')); // categories
      expect(chartXml, contains('<c:numCache><c:formatCode>General</c:formatCode>'));
      expect(chartXml, contains('<c:grouping val="clustered"/>'));
      expect(chartXml, contains('<c:invertIfNegative val="0"/>'));
      expect(chartXml, contains('<c:catAx>'));
      expect(chartXml, contains('<c:valAx>'));
      expect(chartXml, contains('<c:legend>'));

      // Embedded workbook: a valid ZIP with the mirrored data.
      final xlsxBytes = archive.files
          .firstWhere((e) => e.name == 'ppt/embeddings/Microsoft_Excel_Sheet1.xlsx')
          .content as List<int>;
      final sheetZip = ZipDecoder().decodeBytes(xlsxBytes);
      final sheet = utf8.decode(sheetZip.files
          .firstWhere((e) => e.name == 'xl/worksheets/sheet1.xml')
          .content as List<int>);
      // Track 09: the workbook now uses shared strings.
      expect(sheet, contains('t="s"'));
      expect(sheet, isNot(contains('t="inlineStr"')));
      expect(sheet, contains('<v>210.0</v>'));
      final shared = utf8.decode(sheetZip.files
          .firstWhere((e) => e.name == 'xl/sharedStrings.xml')
          .content as List<int>);
      expect(shared, contains('Nội bộ'));
      expect(shared, contains('Q4'));

      // Chart rels → the workbook.
      final rels = part(archive, 'ppt/charts/_rels/chart1.xml.rels');
      expect(rels, contains('Target="../embeddings/Microsoft_Excel_Sheet1.xlsx"'));
      // Content types declare the chart + xlsx parts.
      final contentTypes = part(archive, '[Content_Types].xml');
      expect(contentTypes, contains('PartName="/ppt/charts/chart1.xml"'));
      expect(contentTypes, contains('Extension="xlsx"'));
    });

    test('slide xml embeds the chart graphicFrame + rels', () async {
      final chart = ChartData.sample(ChartType.line);
      final archive = await exportPptx(chartDiv(chart));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('<p:graphicFrame>'));
      expect(slideXml, contains(
          'uri="http://schemas.openxmlformats.org/drawingml/2006/chart"'));
      expect(slideXml, contains('r:id="'));
      final slideRels = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(slideRels, contains('Target="../charts/chart1.xml"'));
      expect(
          slideRels,
          contains(
              'relationships/chart'));
      // The chart div produced no stray text shape.
      expect(slideXml, isNot(contains('data-chart')));
    });

    test('identical charts are deduplicated into one part', () async {
      final chart = ChartData.sample(ChartType.pie);
      final archive = await exportPptx(
          '${chartDiv(chart)}<p>x</p>${chartDiv(chart)}');
      final chartParts = archive.files
          .where((e) => e.name.startsWith('ppt/charts/') &&
              e.name.endsWith('.xml') &&
              !e.name.contains('_rels'))
          .toList();
      expect(chartParts.length, 1, reason: 'one part for two occurrences');
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(RegExp('<p:graphicFrame>').allMatches(slideXml).length, 2);
    });
  });

  group('SVG rendering (P6)', () {
    test('every chart type renders a valid inline SVG', () {
      for (final type in ChartType.values) {
        final chart = ChartData.sample(type);
        final svg = ChartService.renderSvg(chart);
        expect(svg, startsWith('<svg '), reason: type.name);
        expect(svg, endsWith('</svg>'), reason: type.name);
        expect(() => xml.XmlDocument.parse(svg), returnsNormally,
            reason: type.name);
      }
    });

    test('type-specific SVG primitives are present', () {
      String svg(ChartType t) =>
          ChartService.renderSvg(ChartData.sample(t));
      expect(svg(ChartType.column), contains('<rect '));
      expect(svg(ChartType.bar), contains('<rect '));
      expect(svg(ChartType.line), contains('<polyline '));
      expect(svg(ChartType.area), contains('<polygon '));
      expect(svg(ChartType.pie), contains('<path '));
      expect(svg(ChartType.donut), contains('stroke-dasharray'));
      expect(svg(ChartType.combo), contains('<polyline '));
      expect(svg(ChartType.treemap), contains('<rect '));
      expect(svg(ChartType.sunburst), contains('stroke-dasharray'));
      expect(svg(ChartType.histogram), contains('<rect '));
      expect(svg(ChartType.boxWhisker), contains('<rect '));
      expect(svg(ChartType.waterfall), contains('<rect '));
      expect(svg(ChartType.funnel), contains('<path '));
      expect(svg(ChartType.map), contains('<rect '));
    });
  });

  group('HTML + PDF pipelines (P5–P6)', () {
    test('HTML deck replaces chart placeholders with inline SVG', () {
      final chart = ChartData.sample(ChartType.line);
      final html = HtmlExportService().buildPresentationHtml([
        {
          'title': 'C',
          'htmlContent': '${chartDiv(chart)}<p>Văn bản</p>',
        }
      ]);
      expect(html, contains('<svg '));
      expect(html, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(html, contains('<polyline '));
      // The placeholder attribute survives for re-editing.
      expect(html, contains('data-chart'));
      expect(() => html_parser.parse(html), returnsNormally);
    });

    test('PDF export renders a slide with a chart', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t08_pdf_');
      try {
        final chart = ChartData.sample(ChartType.column);
        await PdfExportService().exportToPdf(
          [
            {
              'title': 'Biểu đồ',
              'htmlContent': '${chartDiv(chart)}<p>Nội dung</p>',
            }
          ],
          '${dir.path}/out.pdf',
          includeNotes: true,
        );
        final bytes = File('${dir.path}/out.pdf').readAsBytesSync();
        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('insert + edit helpers (P7–P8)', () {
    test('chartMarkup round-trips through the parser', () {
      final chart = ChartData.sample(ChartType.donut);
      final markup = ChartService.chartMarkup(chart);
      expect(markup, startsWith("<div data-chart='"));
      expect(markup, endsWith("'></div>"));
      final parsed = ChartService.chartsIn(markup);
      expect(parsed.length, 1);
      expect(parsed.first.type, ChartType.donut);
    });

    test('replaceChartAt swaps the nth chart in place', () {
      final a = ChartData.sample(ChartType.pie);
      final b = ChartData.sample(ChartType.line);
      final c = ChartData.sample(ChartType.column);
      final html = '${chartDiv(a)}<p>x</p>${chartDiv(b)}';
      final replaced = ChartService.replaceChartAt(html, 0, c);
      final charts = ChartService.chartsIn(replaced);
      expect(charts.length, 2);
      expect(charts[0].type, ChartType.column);
      expect(charts[1].type, ChartType.line);
      // Out-of-range index leaves the HTML untouched.
      expect(ChartService.replaceChartAt(html, 5, c), html);
    });
  });
}