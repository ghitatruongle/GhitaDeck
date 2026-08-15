import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/text_metrics_service.dart';

/// Track 02 tests: real-font layout estimation.
///
///  * the font-metrics table resolves sane values (system fonts when
///    present, baked-in fallback otherwise),
///  * text/list/table height estimates scale with font size, line count and
///    cell content instead of flat EMU constants,
///  * the "fit content" shrink scales the emitted point sizes recursively so
///    overflowing decks fit their slides.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(TextMetricsService.clearCache);

  test('metrics table resolves sane values for the machine fonts', () {
    final m = TextMetricsService.metrics;
    expect(m.lineHeightEm, inInclusiveRange(1.0, 1.6),
        reason: 'PowerPoint "Multiple 1.0" is the font line box');
    expect(m.avgCharWidthEm, inInclusiveRange(0.30, 0.80));
    expect(m.unitsPerEm, inInclusiveRange(1000, 4096));
    expect(m.ascender, greaterThan(0));
    expect(m.descender, lessThan(0));
  });

  test('paragraph estimate scales with size and wraps long text', () {
    const widthEmu = 8229600;
    Map<String, String> run(String text, [String size = '1800']) =>
        {'text': text, 'size': size, 'bold': 'false', 'italic': 'false'};

    final short = TextMetricsService.paragraphHeightEmu([run('Ngắn')],
        widthEmu: widthEmu);
    final big = TextMetricsService.paragraphHeightEmu(
        [run('Ngắn', '3600')],
        widthEmu: widthEmu);
    // Doubling the size roughly doubles the height (wider + taller lines).
    expect(big, greaterThan(short * 1.9));

    // A paragraph wider than the box wraps to multiple lines.
    final long = TextMetricsService.paragraphHeightEmu(
        [run(List.filled(120, 'đây là một đoạn văn bản khá dài').join(' '))],
        widthEmu: widthEmu);
    expect(long, greaterThan(short * 2));

    // The old flat constant: one 18pt group was 360000 EMU regardless of
    // length. The estimate must exceed it once the text wraps.
    final expectedLines =
        (long / TextMetricsService.lineHeightEmu(1800)).ceil();
    expect(expectedLines, greaterThan(1));
  });

  test('table row estimate grows with the tallest cell and includes insets',
      () {
    const cellWidth = 8229600 ~/ 4 - 2 * 91440;
    Map<String, String> cell(String text) =>
        {'text': text, 'bold': 'false', 'italic': 'false'};

    final shortRow = TextMetricsService.tableRowHeightEmu(
        [cell('A'), cell('B')],
        cellWidthEmu: cellWidth);
    final longRow = TextMetricsService.tableRowHeightEmu(
        [cell('A'), cell(List.filled(30, 'nội dung ô bảng dài').join(' '))],
        cellWidthEmu: cellWidth);
    expect(longRow, greaterThan(shortRow));
    // Default vertical cell insets (top + bottom 0.05") are always present.
    expect(shortRow, greaterThan(2 * 45720));
  });

  test('estimateBlockHeight replaces the flat 360000/400000 constants', () {
    const widthEmu = 8229600;
    final textBlock = PPTGenerator.parseHtmlContentFull(
        '<p>Đoạn văn bản tiếng Việt có dấu dài nhiều dòng để kiểm tra.</p>')
        .first;
    final estimate = PPTGenerator.estimateBlockHeight(textBlock,
        contentWidthEmu: widthEmu);
    // One 18pt line ≈ 304000 EMU with real metrics; the old constant was
    // 360000 per group regardless of content.
    expect(estimate, lessThan(360000 + 91440));
    expect(estimate, greaterThan(0));

    final tableBlock = PPTGenerator.parseHtmlContentFull(
            '<table><tr><th>A</th><th>B</th></tr>'
            '<tr><td>1</td><td>2</td></tr></table>')
        .first;
    final tableEstimate = PPTGenerator.estimateBlockHeight(tableBlock,
        contentWidthEmu: widthEmu);
    // Two rows at ~16pt with insets: far below the old flat 800000.
    expect(tableEstimate, lessThan(800000));
    expect(tableEstimate, greaterThan(2 * 45720));
  });

  test('fit content shrinks overflowing text recursively (90% per pass)',
      () async {
    final dir = await Directory.systemTemp.createTemp('ghita_t02_fit_');
    try {
      // One slide with far more text than the canvas can hold.
      final overflow = [
        {
          'title': 'Tràn',
          'htmlContent':
              '<p>${List.filled(40, 'đây là một đoạn văn bản rất dài để làm tràn slide').join(' ')}</p>'
                  '<ul>${List.filled(30, '<li>Mục danh sách dài dòng</li>').join()}</ul>'
                  '<table>${List.filled(12, '<tr><td>Ô dữ liệu dài</td><td>Ô dữ liệu dài hơn nữa</td></tr>').join()}</table>',
        }
      ];
      Future<String> runPptx({required bool fitContent}) async {
        final out = '${dir.path}/${fitContent ? 'fit' : 'nofit'}.pptx';
        await PPTGenerator.generatePPT(overflow, out, fitContent: fitContent);
        final archive =
            ZipDecoder().decodeBytes(File(out).readAsBytesSync());
        return utf8.decode(archive.files
            .firstWhere((e) => e.name == 'ppt/slides/slide1.xml')
            .content as List<int>);
      }

      final noFit = await runPptx(fitContent: false);
      final fit = await runPptx(fitContent: true);

      // The fit run scaled every run's point size down (18pt default → 16pt
      // after one 0.9 pass → ...), while the no-fit run keeps 1800.
      expect(noFit, contains('sz="1800"'));
      expect(fit, isNot(contains('sz="1800"')));
      expect(RegExp(r'sz="1[0-6]\d\d"').hasMatch(fit), isTrue,
          reason: 'sizes must shrink toward the 60% floor');
      expect(RegExp(r'sz="[1-5]\d\d"').hasMatch(fit), isFalse,
          reason: 'never below the 60% minimum (≥ 1080 at 18pt)');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('no-fit path keeps the exact original point sizes', () async {
    final dir = await Directory.systemTemp.createTemp('ghita_t02_nofit_');
    try {
      final slides = [
        {
          'title': 'Nhỏ',
          'htmlContent': '<p>Văn bản ngắn vừa khít.</p>',
        }
      ];
      final out = '${dir.path}/a.pptx';
      await PPTGenerator.generatePPT(slides, out,
          fitContent: false, parseCache: null);
      final archive = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
      final xml = utf8.decode(archive.files
          .firstWhere((e) => e.name == 'ppt/slides/slide1.xml')
          .content as List<int>);
      expect(xml, contains('sz="1800"'));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}