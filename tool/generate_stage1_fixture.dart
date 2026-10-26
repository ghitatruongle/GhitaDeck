import 'dart:io';

import 'package:ghita_deck/models/slide.dart';
import 'package:ghita_deck/services/ppt_generator.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
        'Usage: dart run tool/generate_stage1_fixture.dart <output.pptx> '
        '[--single|--minimal|--minimal-4x3]');
    exitCode = 64;
    return;
  }

  const onePixelPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
  final slides = <Map<String, dynamic>>[];
  final mode = args.length == 2 ? args[1] : '';
  final minimal = mode == '--minimal' || mode == '--minimal-4x3';
  final widescreen = mode != '--minimal-4x3';
  final effects = args.length == 2
      ? [minimal ? SlideEffect.none : SlideEffect.fade]
      : SlideEffect.values;
  for (var index = 0; index < effects.length; index++) {
    final effect = effects[index];
    slides.add({
      'title': 'Kiểm định ${effect.name}',
      'htmlContent': minimal
          ? '<p>Minimal</p>'
          : index == 0
              ? '''
<section data-bg-color="#F4F7FB">
  <h2>Phụ đề</h2>
  <p style="color:#102A43;text-align:center">Văn bản <strong>đậm</strong>, <em>nghiêng</em>, <a href="https://example.com"><u>liên kết</u></a> và <span style="background-color:#FFFF00;font-family:Arial;font-size:20px"><s>đánh dấu</s></span><br>xuống dòng.</p>
  <ul><li>Mục một</li><li>Mục hai</li></ul>
  <ol><li>Mục số một</li><li>Mục số hai</li></ol>
  <table><tr><th>Tên</th><th>Giá trị</th></tr><tr><td>A</td><td>1</td></tr></table>
  <img src="data:image/png;base64,$onePixelPng">
</section>
'''
              : '<p>Hiệu ứng <strong>${effect.name}</strong></p>',
      if (!minimal) 'notes': 'Ghi chú tiếng Việt cho ${effect.name}',
      'effect': effect.name,
      if (!minimal && index == 0) 'bgColor': '#F4F7FB',
    });
  }

  await PPTGenerator.generatePPT(
    slides,
    args.first,
    widescreen: widescreen,
    autoAdvance: minimal ? null : const Duration(seconds: 4),
  );
}
