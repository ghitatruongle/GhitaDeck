import 'dart:math' as math;
import 'dart:typed_data';

import '../models/chart_data.dart';
import 'embedded_workbook_service.dart';

/// Generated OOXML chart package (Track 08/10): `chartN.xml` +
/// `Microsoft_Excel_SheetN.xlsx` + chart rels.
///
/// The chart XML follows the exact structure Excel/PowerPoint write (verified
/// against real PowerPoint via COM): series carry only idx/order/
/// invertIfNegative/cat/val — the series NAME lives in the embedded
/// workbook's B1 cell, exactly like PowerPoint's own charts.
class PptChartPackage {
  PptChartPackage({
    required this.chartXml,
    required this.relsXml,
    required this.xlsxBytes,
    required this.chartName,
  });

  final String chartXml;
  final String relsXml;
  final Uint8List xlsxBytes;
  final String chartName;
}

/// Builds DrawingML `<c:chart>` parts + embedded workbooks.
class PptChartWriter {
  PptChartWriter._();

  static PptChartPackage build(ChartData chart, {required int index}) {
    final chartName = 'chart$index.xml';
    final sheetName = 'Microsoft_Excel_Sheet$index.xlsx';
    final chartXml = _chartXml(chart);
    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/package" Target="../embeddings/$sheetName"/>
</Relationships>''';
    return PptChartPackage(
      chartXml: chartXml,
      relsXml: relsXml,
      xlsxBytes: _xlsxBytes(chart),
      chartName: chartName,
    );
  }

  static String _chartXml(ChartData chart) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
          '<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<c:date1904 val="0"/><c:lang val="en-US"/>')
      ..write('<c:roundedCorners val="0"/>')
      ..write('<c:chart><c:autoTitleDeleted val="0"/>')
      ..write('<c:plotArea><c:layout/>');
    switch (chart.type) {
      case ChartType.column:
      case ChartType.histogram:
      case ChartType.treemap:
      case ChartType.boxWhisker:
      case ChartType.waterfall:
      case ChartType.map:
        _bar(b, chart, 'col');
        _axes(b);
      case ChartType.bar:
      case ChartType.funnel:
        _bar(b, chart, 'bar');
        _axes(b);
      case ChartType.line:
        _lineArea(b, chart, area: false);
      case ChartType.area:
        _lineArea(b, chart, area: true);
      case ChartType.pie:
      case ChartType.sunburst:
        _pie(b, chart, doughnut: false);
      case ChartType.donut:
        _pie(b, chart, doughnut: true);
      case ChartType.combo:
        _bar(b, chart, 'col', seriesRange: const [0, 1]);
        if (chart.series.length > 1) {
          _lineArea(b, chart, area: false, seriesRange: const [1, null]);
        }
        _axes(b);
    }
    b.write('</c:plotArea>');
    if (chart.style.showLegend && chart.series.length > 1) {
      b.write('<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>');
    }
    b.write('<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/><c:showDLblsOverMax val="0"/>');
    b.write('</c:chart>');
    b.write(
        '<c:printSettings><c:headerFooter/><c:pageMargins b="0.75" l="0.7" r="0.7" t="0.75" header="0.3" footer="0.3"/><c:pageSetup/></c:printSettings>');
    b.write('</c:chartSpace>');
    return b.toString();
  }

  static void _bar(StringBuffer b, ChartData chart, String dir,
      {List<int?>? seriesRange}) {
    final start = seriesRange?[0] ?? 0;
    final end = seriesRange?[1] ?? chart.series.length;
    if (start >= end) return;
    b.write('<c:barChart><c:barDir val="$dir"/>');
    b.write(chart.style.stacked
        ? '<c:grouping val="stacked"/>'
        : '<c:grouping val="clustered"/>');
    b.write('<c:varyColors val="0"/>');
    for (var s = start; s < end; s++) {
      _ser(b, chart, s);
    }
    b.write('<c:gapWidth val="150"/>');
    b
      ..write('<c:axId val="261087776"/>')
      ..write('<c:axId val="1675213520"/>')
      ..write('</c:barChart>');
  }

  static void _lineArea(StringBuffer b, ChartData chart,
      {required bool area, List<int?>? seriesRange}) {
    final start = seriesRange?[0] ?? 0;
    final end = seriesRange?[1] ?? chart.series.length;
    if (start >= end) return;
    b.write(area
        ? '<c:areaChart><c:grouping val="standard"/><c:varyColors val="0"/>'
        : '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>');
    for (var s = start; s < end; s++) {
      _ser(b, chart, s);
    }
    b
      ..write('<c:marker val="1"/>')
      ..write('<c:axId val="261087776"/>')
      ..write('<c:axId val="1675213520"/>')
      ..write(area ? '</c:areaChart>' : '</c:lineChart>');
  }

  static void _pie(StringBuffer b, ChartData chart,
      {required bool doughnut}) {
    b.write(doughnut
        ? '<c:doughnutChart><c:firstSliceAng val="0"/>'
        : '<c:pieChart><c:varyColors val="0"/>');
    for (var s = 0; s < chart.series.length; s++) {
      _ser(b, chart, s);
    }
    b.write(doughnut ? '</c:doughnutChart>' : '</c:pieChart>');
  }

  /// Series exactly like Excel writes them: idx/order/invertIfNegative, then
  /// cat (strCache) and val (numCache) — no c:tx (the name comes from the
  /// embedded workbook's B1 cell).
  static void _ser(StringBuffer b, ChartData chart, int seriesIndex) {
    final series = chart.series[seriesIndex];
    final n = math.max(chart.categories.length, series.values.length);
    if (n == 0) return;
    b
      ..write('<c:ser><c:idx val="$seriesIndex"/>')
      ..write('<c:order val="$seriesIndex"/>')
      ..write('<c:invertIfNegative val="0"/>');
    // Categories (A2:A{n+1}).
    b
      ..write('<c:cat><c:strRef><c:f>Sheet1!\$A\$2:\$A\$${n + 1}</c:f>')
      ..write('<c:strCache><c:ptCount val="$n"/>');
    for (var c = 0; c < n; c++) {
      b.write(
          '<c:pt idx="$c"><c:v>${_xml(c < chart.categories.length ? chart.categories[c] : '')}</c:v></c:pt>');
    }
    b.write('</c:strCache></c:strRef></c:cat>');
    // Values (B2:B{n+1}).
    b
      ..write('<c:val><c:numRef><c:f>Sheet1!\$${_col(seriesIndex)}\$2:\$${_col(seriesIndex)}\$${n + 1}</c:f>')
      ..write('<c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="$n"/>');
    for (var c = 0; c < n; c++) {
      final v = c < series.values.length ? series.values[c] : 0;
      b.write('<c:pt idx="$c"><c:v>$v</c:v></c:pt>');
    }
    b.write('</c:numCache></c:numRef></c:val>');
    b.write('</c:ser>');
  }

  static void _axes(StringBuffer b) {
    b
      ..write('<c:catAx><c:axId val="261087776"/>'
          '<c:scaling><c:orientation val="minMax"/></c:scaling>'
          '<c:delete val="0"/><c:axPos val="b"/>'
          '<c:numFmt formatCode="General" sourceLinked="1"/>'
          '<c:majorTickMark val="out"/><c:minorTickMark val="none"/>'
          '<c:tickLblPos val="nextTo"/>'
          '<c:crossAx val="1675213520"/><c:crosses val="autoZero"/>'
          '<c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/>'
          '<c:noMultiLvlLbl val="0"/></c:catAx>')
      ..write('<c:valAx><c:axId val="1675213520"/>'
          '<c:scaling><c:orientation val="minMax"/></c:scaling>'
          '<c:delete val="0"/><c:axPos val="l"/><c:majorGridlines/>'
          '<c:numFmt formatCode="General" sourceLinked="1"/>'
          '<c:majorTickMark val="out"/><c:minorTickMark val="none"/>'
          '<c:tickLblPos val="nextTo"/>'
          '<c:crossAx val="261087776"/><c:crosses val="autoZero"/>'
          '<c:crossBetween val="between"/></c:valAx>');
  }

  static String _col(int index) => _alpha(index + 2); // 0 → B, 1 → C, …

  static String _alpha(int number) {
    var n = number;
    final sb = StringBuffer();
    while (n > 0) {
      n--;
      sb.writeCharCode(65 + n % 26);
      n ~/= 26;
    }
    return sb.toString();
  }

  static String _xml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static Uint8List _xlsxBytes(ChartData chart) {
    var n = chart.categories.length;
    for (final s in chart.series) {
      if (s.values.length > n) n = s.values.length;
    }
    n = math.max(n, 1);
    final grid = <List<Object?>>[
      ['', ...chart.series.map((s) => s.name)],
      for (var r = 0; r < n; r++)
        [
          r < chart.categories.length ? chart.categories[r] : '',
          for (var s = 0; s < chart.series.length; s++)
            r < chart.series[s].values.length ? chart.series[s].values[r] : 0,
        ],
    ];
    return EmbeddedWorkbookService.buildXlsx(grid);
  }
}