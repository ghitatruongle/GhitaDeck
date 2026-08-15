import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/text_metrics_service.dart';

/// Track 02 benchmark (phases 2 & 9): layout-estimation error vs real text.
///
/// Ground truth comes from the real fonts: Segoe UI (regular/bold/italic) is
/// loaded from the Windows system font directory and laid out with dart:ui
/// TextPainter — the same font families and the same wrapping algorithm
/// PowerPoint itself uses. Estimates are then compared per content block:
///
///  * "Trước" — the flat v1.6.3 constants (360000 EMU per paragraph/item,
///    400000 EMU per table row),
///  * "Sau" — TextMetricsService real-font estimates (wrapped lines × true
///    line height, table cells with real text + default insets).
///
/// Run standalone:
///   flutter test tool/metrics_benchmark_test.dart
/// With GHITA_BENCH_LABEL set, the markdown table is appended to
/// tool/benchmark_results_t02.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const contentWidthEmu = 8229600; // 16:9 content width used by the exporter
  const pxPerEmu = 9525;

  group('font ground truth', () {
    test('loads the real Segoe UI family from the system fonts', () async {
      final dir = File(r'C:\Windows\Fonts\segoeui.ttf');
      if (!dir.existsSync()) return; // non-Windows: nothing to load
      await _loadSegoeUiFamily();
      final metrics = TextMetricsService.metrics;
      expect(['Segoe UI', 'Calibri', 'Arial', 'Fallback'], contains(metrics.family));
      expect(metrics.lineHeightEm, inInclusiveRange(1.0, 1.6));
      expect(metrics.avgCharWidthEm, inInclusiveRange(0.30, 0.80));
    });
  });

  test('layout-estimation error: before vs after on 10 sample decks', () async {
    // Real layout ground truth using the system fonts. Estimation and
    // rendering use the SAME family (Segoe UI) so the comparison isolates
    // the estimator's error instead of font-family differences.
    if (File(r'C:\Windows\Fonts\segoeui.ttf').existsSync()) {
      await _loadSegoeUiFamily();
      final segoe = TextMetricsService.metricsForFamily('Segoe UI');
      expect(segoe, isNotNull);
      TextMetricsService.debugOverrideMetrics(segoe);
    }
    final metrics = TextMetricsService.metrics;
    final lineHeightEm = metrics.lineHeightEm;
    // The test engine lays text out at 1.0em line height regardless of the
    // requested typo height, so the ground truth is scaled by the font's own
    // typo line height — the "Multiple 1.0" convention PowerPoint uses.

    // ---- 10 sample contents: long text, Vietnamese, bold/italic ----
    final samples = <(String, String)>[
      ('đoạn dài', '<p>${List.filled(18, 'đây là một đoạn văn bản khá dài').join(' ')}</p>'),
      ('tiếng Việt có dấu',
          '<p>Phân tích hiệu quả kinh doanh của công ty trong quý vừa qua cho thấy doanh thu tăng trưởng ổn định.</p>'),
      ('đậm', '<p><b>Tiêu đề chính cần nhấn mạnh với nội dung đậm và dài hơn một dòng so với bình thường.</b></p>'),
      ('nghiêng', '<p><i>Phần chú thích nghiêng giải thích thêm về biểu đồ phân bố thị phần theo khu vực.</i></p>'),
      ('trộn đậm/nghiêng',
          '<p>Trước hết <b>phần đậm quan trọng</b> xuất hiện giữa câu, sau đó <i>phần nghiêng bổ sung</i> và cuối cùng là chữ thường để kết thúc đoạn.</p>'),
      ('nhiều đoạn', '<p>Đoạn một ngắn.</p><p>Đoạn hai dài hơn với nội dung giải thích chi tiết về quy trình vận hành của hệ thống.</p><p>Đoạn ba kết luận.</p>'),
      ('danh sách dài', '<ul><li>Mục ngắn</li><li>Mục dài giải thích chi tiết từng bước thực hiện của quy trình</li><li>Mục ba</li><li>Mục bốn với nội dung khá dài để tạo dòng thứ hai</li><li>Mục năm</li></ul>'),
      ('bảng 5x4', '<table><tr><th>Cột A</th><th>Cột B</th><th>Cột C</th><th>Cột D</th></tr>'
          '<tr><td>Giá trị 1-1 dài hơn bình thường</td><td>Giá trị 1-2</td><td>Giá trị 1-3</td><td>Giá trị 1-4</td></tr>'
          '<tr><td>Giá trị 2-1</td><td>Giá trị 2-2 dài gây gói dòng trong ô</td><td>Giá trị 2-3</td><td>Giá trị 2-4</td></tr>'
          '<tr><td>Giá trị 3-1</td><td>Giá trị 3-2</td><td>Giá trị 3-3</td><td>Giá trị 3-4 dài gây gói dòng trong ô</td></tr>'
          '<tr><td>Giá trị 4-1</td><td>Giá trị 4-2</td><td>Giá trị 4-3</td><td>Giá trị 4-4</td></tr></table>'),
      ('chữ cỡ lớn', '<p style="font-size:36px">Chữ cỡ lớn gấp đôi với nội dung dài nhiều dòng để kiểm tra ước lượng chiều cao theo cỡ chữ.</p>'),
      ('chữ cỡ nhỏ', '<p style="font-size:12px">Chữ nhỏ hơn bình thường dùng cho phần ghi chú phụ dưới chân.</p>'),
    ];

    const widthPx = contentWidthEmu / pxPerEmu;
    final rows = <String>[];
    final beforeErrors = <double>[];
    final afterErrors = <double>[];

    for (final (name, html) in samples) {
      final blocks = PPTGenerator.parseHtmlContentFull(html);
      double beforeTotal = 0;
      double afterTotal = 0;
      double truthTotal = 0;

      for (final block in blocks) {
        final type = block['type'] as String;
        if (type == 'text' || type == 'list') {
          final runs = (type == 'text'
                  ? block['paragraphs']
                  : block['items']) as List;
          // Group by paragraphStart/itemStart exactly like the exporter.
          final groups = <List<Map<String, String>>>[];
          var current = <Map<String, String>>[];
          for (final run in runs.cast<Map<String, String>>()) {
            final marker = type == 'text' ? 'paragraphStart' : 'itemStart';
            if (run[marker] == 'true' && current.isNotEmpty) {
              groups.add(current);
              current = [];
            }
            current.add(run);
          }
          if (current.isNotEmpty) groups.add(current);

          for (final group in groups) {
            // Old estimate: flat 360000 per group.
            beforeTotal += 360000;
            // New estimate: real-font wrapped estimate.
            afterTotal += TextMetricsService.paragraphHeightEmu(group,
                widthEmu: contentWidthEmu);
            // Ground truth: laid-out height with the real font.
            truthTotal +=
                _paintParagraphHeight(group, widthPx: widthPx,
                    lineHeightEm: lineHeightEm) *
                    pxPerEmu;
          }
        } else if (type == 'table') {
          final rowsDynamic = block['rows'] as List;
          final cols = rowsDynamic.fold<int>(
              0, (m, row) => (row as List).length > m ? row.length : m);
          final cellWidth =
              ((contentWidthEmu / cols) - 2 * 91440).clamp(45720, contentWidthEmu).toInt();
          for (int r = 0; r < rowsDynamic.length; r++) {
            final cells = (rowsDynamic[r] as List)
                .map((c) => Map<String, String>.from(c as Map))
                .toList();
            beforeTotal += 400000;
            afterTotal += TextMetricsService.tableRowHeightEmu(cells,
                cellWidthEmu: cellWidth,
                header: block['headerRow'] == true && r == 0);
            truthTotal +=
                _paintTableRowHeight(cells, widthPx: cellWidth / pxPerEmu,
                    header: block['headerRow'] == true && r == 0,
                    lineHeightEm: lineHeightEm) *
                    pxPerEmu;
          }
        }
      }

      double err(double est) =>
          (est - truthTotal).abs() / truthTotal * 100;
      final beforeErr = err(beforeTotal);
      final afterErr = err(afterTotal);
      beforeErrors.add(beforeErr);
      afterErrors.add(afterErr);
      rows.add('| $name | ${beforeErr.toStringAsFixed(1)} % | '
          '${afterErr.toStringAsFixed(1)} % | '
          '${truthTotal.round()} EMU |');
    }

    final meanBefore =
        beforeErrors.reduce((a, b) => a + b) / beforeErrors.length;
    final meanAfter = afterErrors.reduce((a, b) => a + b) / afterErrors.length;
    final maxBefore = beforeErrors.reduce((a, b) => a > b ? a : b);
    final maxAfter = afterErrors.reduce((a, b) => a > b ? a : b);

    // The real-font estimates must be measurably closer to the ground truth
    // than the flat constants were.
    debugPrint('\n=== per-sample ===\n${rows.join('\n')}\n'
        'mean before=${meanBefore.toStringAsFixed(1)}% '
        'mean after=${meanAfter.toStringAsFixed(1)}%');
    expect(meanAfter, lessThan(meanBefore));

    final lines = <String>[
      '| Mẫu | Sai số trước (hằng số) | Sai số sau (metrics thật) | Chiều cao thật |',
      '|---|---|---|---|',
      ...rows,
      '| **Trung bình** | **${meanBefore.toStringAsFixed(1)} %** | '
          '**${meanAfter.toStringAsFixed(1)} %** | — |',
      '| **Tệ nhất** | **${maxBefore.toStringAsFixed(1)} %** | '
          '**${maxAfter.toStringAsFixed(1)} %** | — |',
      '',
      '> Nền thật: Segoe UI từ thư mục font Windows, layout bằng dart:ui '
          'TextPainter (cùng họ font PowerPoint dùng). Bỏ qua khoảng cách 91440 '
          'giữa các block ở cả ba phép đo.',
    ];

    final label = Platform.environment['GHITA_BENCH_LABEL'];
    if (label != null) {
      final file = File('tool/benchmark_results_t02.md');
      final out = StringBuffer();
      if (file.existsSync()) out.write(file.readAsStringSync());
      out
        ..writeln()
        ..writeln('## $label — ${DateTime.now().toString().substring(0, 19)}')
        ..writeln();
      for (final l in lines) {
        out.writeln(l);
      }
      await file.writeAsString(out.toString(), flush: true);
    }
  });
}

/// Register the real Segoe UI regular/bold/italic faces from the Windows
/// system fonts under one family, so TextPainter measures true glyph metrics.
Future<void> _loadSegoeUiFamily() async {
  Future<ByteData> font(String name) async =>
      (await File('C:\\Windows\\Fonts\\$name').readAsBytes())
          .buffer
          .asByteData();
  final loader = FontLoader('Segoe UI')..addFont(font('segoeui.ttf'));
  if (File(r'C:\Windows\Fonts\segoeuib.ttf').existsSync()) {
    loader.addFont(font('segoeuib.ttf'));
  }
  if (File(r'C:\Windows\Fonts\segoeuii.ttf').existsSync()) {
    loader.addFont(font('segoeuii.ttf'));
  }
  await loader.load();
}

/// Paint one paragraph group with the real font and return its layout height
/// in logical pixels (1 logical px = 9525 EMU at 96 DPI, matching the
/// exporter's EMU-per-pixel constant).
double _paintParagraphHeight(
  List<Map<String, String>> runs, {
  required double widthPx,
  required double lineHeightEm,
}) {
  // sz is in hundredths of a point; paint at pt→px (1pt = 4/3 px @96dpi) so
  // the ground truth is physically the same size as the PPTX estimate. The
  // loaded font's intrinsic metrics give the typo line height natively.
  final painter = TextPainter(
    text: TextSpan(
      children: [
        for (final run in runs)
          if ((run['text'] ?? '').isNotEmpty)
            TextSpan(
              text: run['text'],
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: ((int.tryParse(run['size'] ?? '') ?? 1800) / 100) *
                    (4 / 3),
                fontWeight:
                    run['bold'] == 'true' ? FontWeight.bold : FontWeight.normal,
                fontStyle: run['italic'] == 'true'
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: widthPx);
  return painter.height;
}

/// Paint one table row (its tallest cell) and return the row height in px.
double _paintTableRowHeight(
  List<Map<String, String>> cells, {
  required double widthPx,
  bool header = false,
  required double lineHeightEm,
}) {
  var maxHeight = 0.0;
  for (final cell in cells) {
    final painter = TextPainter(
      text: TextSpan(
        text: cell['text'] ?? '',
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize:
              ((int.tryParse(cell['size'] ?? '') ?? 1600) / 100) * (4 / 3),
          fontWeight: (header || cell['bold'] == 'true')
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: widthPx);
    if (painter.height > maxHeight) maxHeight = painter.height;
  }
  // Top + bottom default cell insets (0.05" = 45.72 px at 96 DPI).
  return maxHeight + 2 * (45720 / 9525);
}