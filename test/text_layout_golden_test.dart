import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/text_metrics_service.dart';

const _contentWidthEmu = 8229600;
const _pxPerEmu = 9525;

final _seedSamples = <String>[
  '<p>${List.filled(18, 'đây là một đoạn văn bản khá dài').join(' ')}</p>',
  '<p>Phân tích hiệu quả kinh doanh của công ty trong quý vừa qua cho thấy doanh thu tăng trưởng ổn định.</p>',
  '<p><b>Tiêu đề chính cần nhấn mạnh với nội dung đậm và dài hơn một dòng so với bình thường.</b></p>',
  '<p><i>Phần chú thích nghiêng giải thích thêm về biểu đồ phân bố thị phần theo khu vực.</i></p>',
  '<p>Trước hết <b>phần đậm quan trọng</b> xuất hiện giữa câu, sau đó <i>phần nghiêng bổ sung</i> và cuối cùng là chữ thường để kết thúc đoạn.</p>',
  '<p>Đoạn một ngắn.</p><p>Đoạn hai dài hơn với nội dung giải thích chi tiết về quy trình vận hành của hệ thống.</p><p>Đoạn ba kết luận.</p>',
  '<ul><li>Mục ngắn</li><li>Mục dài giải thích chi tiết từng bước thực hiện của quy trình</li><li>Mục ba</li><li>Mục bốn với nội dung khá dài để tạo dòng thứ hai</li><li>Mục năm</li></ul>',
  '<p style="font-size:28px">Chữ cỡ lớn dùng cho tiêu đề nội bộ của từng phần trong slide.</p>',
  '<p style="font-size:12px">Chữ cỡ nhỏ dùng cho chú thích dưới chân slide với nội dung đầy đủ dấu câu.</p>',
  '<p>Dự báo tài chính quý IV: <span style="color:#B33">doanh thu tăng 12%</span>, chi phí giảm <b>8%</b>, lợi nhuận gộp <i>đứng vững</i> ở mốc kế hoạch.</p>',
];

String _generatedSample(int index) {
  const words = [
    'kết', 'quả', 'kinh', 'doanh', 'quý', 'này', 'cho', 'thấy', 'sự', 'tăng',
    'trưởng', 'ổn', 'định', 'của', 'toàn', 'bộ', 'hệ', 'thống', 'báo', 'cáo',
    'tài', 'chính', 'được', 'kiểm', 'soát', 'chặt', 'chẽ', 'theo', 'dõi',
  ];
  final count = 8 + (index * 7) % 40;
  final buf = StringBuffer();
  for (var w = 0; w < count; w++) {
    final word = words[(index * 13 + w * 5) % words.length];
    buf.write(w % 9 == 8 ? '<b>$word</b> ' : '$word ');
  }
  final body = buf.toString().trim();
  return '<p>$body</p>';
}

Future<void> _loadFonts() async {
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
  final segoe = TextMetricsService.metricsForFamily('Segoe UI');
  TextMetricsService.debugOverrideMetrics(segoe);
  TextMetricsService.clearBoldCache();
  TextMetricsService.clearItalicCache();
}

double _paintParagraphHeight(
  List<Map<String, String>> runs, {
  required double widthPx,
}) {
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

List<List<Map<String, String>>> _groupsOf(List<Map<String, dynamic>> blocks) {
  final groups = <List<Map<String, String>>>[];
  for (final block in blocks) {
    final type = block['type'] as String;
    if (type != 'text' && type != 'list') continue;
    final runs = (type == 'text' ? block['paragraphs'] : block['items']) as List;
    final marker = type == 'text' ? 'paragraphStart' : 'itemStart';
    var current = <Map<String, String>>[];
    for (final run in runs.cast<Map<String, String>>()) {
      if (run[marker] == 'true' && current.isNotEmpty) {
        groups.add(current);
        current = [];
      }
      current.add(run);
    }
    if (current.isNotEmpty) groups.add(current);
  }
  return groups;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('golden layout: 40 samples stay inside the track gates', () async {
    final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
    expect(fontFile.existsSync(), isTrue,
        reason: 'golden layout requires the real Segoe UI font (Windows)');
    await _loadFonts();

    final htmls = <String>[
      ..._seedSamples,
      for (var i = 0; i < 30; i++) _generatedSample(i),
    ];
    expect(htmls.length, 40);

    final errors = <double>[];
    for (var s = 0; s < htmls.length; s++) {
      final blocks = PPTGenerator.parseHtmlContentFull(htmls[s]);
      var estimated = 0.0;
      var truth = 0.0;
      const widthPx = _contentWidthEmu / _pxPerEmu;
      for (final group in _groupsOf(blocks)) {
        estimated += TextMetricsService.paragraphHeightEmu(group,
            widthEmu: _contentWidthEmu);
        truth += _paintParagraphHeight(group, widthPx: widthPx) * _pxPerEmu;
      }
      final err = truth <= 0 ? 0.0 : (estimated - truth).abs() / truth * 100;
      errors.add(err);
      expect(err, lessThan(25.0),
          reason: 'sample $s drifted beyond the worst-case gate ($err%)');
    }
    final mean = errors.reduce((a, b) => a + b) / errors.length;
    expect(mean, lessThan(12.0), reason: 'mean error $mean% beyond the gate');
  });
}
