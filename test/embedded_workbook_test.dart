import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/chart_data.dart';
import 'package:ghita_ppt_converter/screens/widgets/chart_data_grid.dart';
import 'package:ghita_ppt_converter/services/chart_service.dart';
import 'package:ghita_ppt_converter/services/embedded_workbook_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:xml/xml.dart' as xml;

/// Track 09 tests — Excel-style data grid + embedded workbook (FEAT 3).
///
///  * the embedded workbook is a real xlsx (sheet1 + sharedStrings) that
///    mirrors the chart caches,
///  * CSV parsing (quotes, commas, CRLF),
///  * grid → ChartData mapping (two-way sync source),
///  * PowerPoint "Edit Data" equivalent: the workbook opens (parts valid)
///    and its numbers match the chart's numCache,
///  * empty charts are skipped (friendly message, no crash).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('embedded workbook is a real xlsx with sharedStrings', () {
    final bytes = EmbeddedWorkbookService.buildXlsx([
      ['', 'Nội bộ', 'Xuất khẩu'],
      ['Q1', 120, 70],
      ['Q2', 180, 90],
    ]);
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(zip.files.any((e) => e.name == 'xl/workbook.xml'), isTrue);
    expect(zip.files.any((e) => e.name == 'xl/worksheets/sheet1.xml'), isTrue);
    expect(zip.files.any((e) => e.name == 'xl/sharedStrings.xml'), isTrue);

    String part(String name) => utf8.decode(
        zip.files.firstWhere((e) => e.name == name).content as List<int>);

    final sheet = part('xl/worksheets/sheet1.xml');
    expect(() => xml.XmlDocument.parse(sheet), returnsNormally);
    // String cells reference the shared table; numbers are inline.
    expect(sheet, contains('t="s"'));
    // A1 is empty (not a shared string) → shared indices start at 1.
    expect(sheet, contains('<v>1</v>'));
    expect(sheet, contains('<v>120</v>'));
    final shared = part('xl/sharedStrings.xml');
    expect(shared, contains('Nội bộ'));
    expect(shared, contains('Xuất khẩu'));
    expect(shared, contains('Q1'));
    expect(shared, contains('uniqueCount="4"'));
  });

  test('CSV parser handles quotes, commas and CRLF', () {
    final rows = EmbeddedWorkbookService.parseCsv(
        'Q1,"120,5",70\r\n"Đà Nẵng","có ""nháy"" kép",90\n');
    expect(rows.length, 2);
    expect(rows[0], ['Q1', '120,5', '70']);
    expect(rows[1], ['Đà Nẵng', 'có "nháy" kép', '90']);
  });

  test('grid data maps to ChartData (two-way sync source)', () {
    final grid = ChartGridData(
      categories: ['Q1', 'Q2'],
      series: [
        ('Nội bộ', [120, 180]),
        ('Xuất khẩu', [70, 90]),
      ],
    );
    final chart = grid.toChartData(
      type: ChartType.column,
      title: 'Doanh thu',
    );
    expect(chart.categories, ['Q1', 'Q2']);
    expect(chart.series.length, 2);
    expect(chart.series[1].values, [70, 90]);
    expect(chart.type, ChartType.column);
  });

  test('embedded workbook mirrors the chart caches (P4/P8)', () async {
    final dir = await Directory.systemTemp.createTemp('ghita_t09_');
    try {
      const chart = ChartData(
        type: ChartType.column,
        title: 'Mirror',
        categories: ['Q1', 'Q2', 'Q3'],
        series: [ChartSeries(name: 'S1', values: [10, 20, 30])],
      );
      final html =
          "<div data-chart='${ChartService.escapeAttribute(chart)}'></div>";
      await PPTGenerator.generatePPT(
        [
          {'title': 'C', 'htmlContent': html},
        ],
        '${dir.path}/out.pptx',
      );
      final archive = ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());

      String part(String name) => utf8.decode(archive.files
          .firstWhere((e) => e.name == name)
          .content as List<int>);

      // Chart caches.
      final chartXml = part('ppt/charts/chart1.xml');
      for (final v in ['<c:v>10.0</c:v>', '<c:v>20.0</c:v>', '<c:v>30.0</c:v>']) {
        expect(chartXml, contains(v));
      }
      expect(chartXml, contains('Sheet1!\$B\$2:\$B\$4'));

      // Workbook numbers match the caches (PowerPoint reads these when the
      // user opens "Edit Data").
      final sheetZip = ZipDecoder().decodeBytes(archive.files
          .firstWhere((e) => e.name == 'ppt/embeddings/Microsoft_Excel_Sheet1.xlsx')
          .content as List<int>);
      final sheet = utf8.decode(sheetZip.files
          .firstWhere((e) => e.name == 'xl/worksheets/sheet1.xml')
          .content as List<int>);
      expect(sheet, contains('<v>10.0</v>'));
      expect(sheet, contains('<v>30.0</v>'));
      // Edit simulation: a changed value would appear in both the workbook
      // and (after re-export) the cache — verify the sharedStrings path.
      final shared = utf8.decode(sheetZip.files
          .firstWhere((e) => e.name == 'xl/sharedStrings.xml')
          .content as List<int>);
      expect(shared, contains('S1'));
      expect(shared, contains('Q3'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('empty charts are skipped in PPTX and show a friendly SVG (P10)',
      () async {
    const empty = ChartData(type: ChartType.column, title: 'Rỗng');
    final dir = await Directory.systemTemp.createTemp('ghita_t09_empty_');
    try {
      final html =
          "<div data-chart='${ChartService.escapeAttribute(empty)}'></div>"
              '<p>Vẫn xuất được</p>';
      await PPTGenerator.generatePPT(
        [
          {'title': 'E', 'htmlContent': html},
        ],
        '${dir.path}/out.pptx',
      );
      final archive = ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
      // No chart part, no chart shape, no crash.
      expect(
          archive.files.any((e) => e.name.startsWith('ppt/charts/')), isFalse);
      final slide = utf8.decode(archive.files
          .firstWhere((e) => e.name == 'ppt/slides/slide1.xml')
          .content as List<int>);
      expect(slide, isNot(contains('<p:graphicFrame>')));

      // HTML path shows a friendly placeholder instead of crashing.
      final svg = ChartService.renderSvg(empty);
      expect(svg, contains('Không có dữ liệu biểu đồ'));
      expect(svg, endsWith('</svg>'));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}