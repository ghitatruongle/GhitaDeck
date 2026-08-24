// T02 (v2.0.1-beta.2) — PptChartWriter tests (phases 5–6).
//
// Golden-substring assertions against the DrawingML the writer emits, plus a
// full XML parse of every produced part (a malformed part would crash
// PowerPoint on load), plus an embedded-workbook round-trip through the zip.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/chart_data.dart';
import 'package:ghita_ppt_converter/services/ppt_chart_writer.dart';
import 'package:xml/xml.dart';

ChartData _chart(
  ChartType type, {
  List<String> categories = const ['Q1', 'Q2'],
  List<ChartSeries> series = const [
    ChartSeries(name: 'Nội bộ', values: [120, 180]),
    ChartSeries(name: 'Xuất khẩu', values: [70, 90]),
  ],
  ChartStyle style = const ChartStyle(),
}) =>
    ChartData(type: type, title: 'Doanh thu', categories: categories, series: series, style: style);

void _assertParses(String xmlText, String label) {
  expect(() => XmlDocument.parse(xmlText), returnsNormally,
      reason: '$label must stay well-formed XML');
}

void main() {
  group('chartXml per chart type', () {
    test('column chart writes a clustered col barChart with axes', () {
      final pkg = PptChartWriter.build(_chart(ChartType.column), index: 1);

      expect(pkg.chartName, 'chart1.xml');
      expect(pkg.chartXml, contains('<c:barChart><c:barDir val="col"/>'));
      expect(pkg.chartXml, contains('<c:grouping val="clustered"/>'));
      expect(pkg.chartXml, contains('<c:catAx>'));
      expect(pkg.chartXml, contains('<c:valAx>'));
      _assertParses(pkg.chartXml, 'column chartXml');
    });

    test('horizontal bar chart flips barDir to bar', () {
      final pkg = PptChartWriter.build(_chart(ChartType.bar), index: 2);
      expect(pkg.chartXml, contains('<c:barDir val="bar"/>'));
      _assertParses(pkg.chartXml, 'bar chartXml');
    });

    test('stacked style switches the grouping', () {
      final pkg = PptChartWriter.build(
        _chart(ChartType.column, style: const ChartStyle(stacked: true)),
        index: 3,
      );
      expect(pkg.chartXml, contains('<c:grouping val="stacked"/>'));
      expect(pkg.chartXml, isNot(contains('<c:grouping val="clustered"/>')));
    });

    test('line chart emits lineChart with markers; area chart emits areaChart',
        () {
      final line = PptChartWriter.build(_chart(ChartType.line), index: 4);
      expect(line.chartXml, contains('<c:lineChart>'));
      expect(line.chartXml, contains('<c:marker val="1"/>'));
      _assertParses(line.chartXml, 'line chartXml');

      final area = PptChartWriter.build(_chart(ChartType.area), index: 5);
      expect(area.chartXml, contains('<c:areaChart>'));
      _assertParses(area.chartXml, 'area chartXml');
    });

    test('pie and doughnut charts skip axes and use their own plot tags', () {
      final pie = PptChartWriter.build(_chart(ChartType.pie), index: 6);
      expect(pie.chartXml, contains('<c:pieChart>'));
      expect(pie.chartXml, isNot(contains('<c:catAx>')));
      _assertParses(pie.chartXml, 'pie chartXml');

      final donut = PptChartWriter.build(_chart(ChartType.donut), index: 7);
      expect(donut.chartXml, contains('<c:doughnutChart>'));
      expect(donut.chartXml, contains('<c:firstSliceAng val="0"/>'));
      _assertParses(donut.chartXml, 'doughnut chartXml');
    });

    test('combo renders a column group plus a line group for later series',
        () {
      final pkg = PptChartWriter.build(_chart(ChartType.combo), index: 8);
      expect(pkg.chartXml, contains('<c:barChart><c:barDir val="col"/>'));
      expect(pkg.chartXml, contains('<c:lineChart>'));
      _assertParses(pkg.chartXml, 'combo chartXml');
    });
  });

  group('series payload', () {
    test('series carry idx/order and cache every category and value', () {
      final pkg = PptChartWriter.build(_chart(ChartType.column), index: 1);
      final xml = pkg.chartXml;

      expect(xml, contains('<c:ser><c:idx val="0"/><c:order val="0"/>'));
      expect(xml, contains('<c:ser><c:idx val="1"/><c:order val="1"/>'));
      expect(xml, contains('<c:ptCount val="2"/>'));
      expect(xml, contains('<c:v>Q1</c:v>'));
      // ChartSeries.values is List<double>, so numbers serialize with .0.
      expect(xml, contains('<c:v>120.0</c:v>'));
      expect(xml, contains('<c:v>90.0</c:v>'));
      // Series names live in the workbook's B1 cell, never in the chart XML.
      expect(xml, isNot(contains('<c:tx>')));
    });

    test('legend follows showLegend but only with more than one series', () {
      // Default style has showLegend=true and two series → legend on.
      final twoSeries =
          PptChartWriter.build(_chart(ChartType.column), index: 1).chartXml;
      expect(twoSeries, contains('<c:legend><c:legendPos val="b"/>'));

      final singleSeries = PptChartWriter.build(
        _chart(ChartType.column,
            series: const [ChartSeries(name: 'Duy nhất', values: [1.0, 2.0])],
            style: const ChartStyle(showLegend: true)),
        index: 1,
      ).chartXml;
      expect(singleSeries, isNot(contains('<c:legend>')),
          reason: 'a one-series chart never shows a legend');

      final legendOff = PptChartWriter.build(
        _chart(ChartType.column,
            style: const ChartStyle(showLegend: false)),
        index: 1,
      ).chartXml;
      expect(legendOff, isNot(contains('<c:legend>')));
    });

    test('category text is XML-escaped inside strCache', () {
      final hostile = PptChartWriter.build(
        _chart(ChartType.column, categories: ['<Q1 & "khác">']),
        index: 1,
      );
      expect(hostile.chartXml, contains('&lt;Q1 &amp; &quot;khác&quot;&gt;'));
      _assertParses(hostile.chartXml, 'escaped category chartXml');
    });
  });

  group('package wiring', () {
    test('rels point at the matching embedded workbook', () {
      final pkg = PptChartWriter.build(_chart(ChartType.column), index: 4);
      expect(pkg.chartName, 'chart4.xml');
      expect(
        pkg.relsXml,
        contains('../embeddings/Microsoft_Excel_Sheet4.xlsx'),
      );
      _assertParses(pkg.relsXml, 'relsXml');
    });

    test('embedded xlsx round-trips through the zip with names and numbers',
        () {
      final Uint8List bytes =
          PptChartWriter.build(_chart(ChartType.column), index: 1).xlsxBytes;

      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('xl/workbook.xml'));
      expect(names, contains('xl/worksheets/sheet1.xml'));
      expect(names, contains('xl/sharedStrings.xml'));

      String part(String name) => utf8.decode(
        archive.files.firstWhere((f) => f.name == name).content as List<int>,
      );

      final sharedStrings = part('xl/sharedStrings.xml');
      expect(sharedStrings, contains('Nội bộ'));
      expect(sharedStrings, contains('Xuất khẩu'));
      expect(sharedStrings, contains('Q1'));

      final sheet = part('xl/worksheets/sheet1.xml');
      expect(sheet, contains('>120.0<'));
      expect(sheet, contains('>90.0<'));
      _assertParses(sheet, 'sheet1.xml');
    });

    test('ragged series are zero-padded to the longest axis', () {
      final ragged = PptChartWriter.build(
        _chart(ChartType.column, series: const [
          ChartSeries(name: 'A', values: [1, 2, 3]),
          ChartSeries(name: 'B', values: [7]),
        ]),
        index: 1,
      );
      // n = max(categories=2, values=3) → B padded to 3 points.
      expect(ragged.chartXml, contains('<c:ptCount val="3"/>'));
      expect(ragged.chartXml, contains('<c:v>7.0</c:v>'));
      expect(ragged.chartXml, contains('<c:v>0.0</c:v>'),
          reason: 'missing tail values become explicit zeros');
      _assertParses(ragged.chartXml, 'ragged chartXml');
    });
  });
}
