import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/slide.dart';
import 'package:ghita_deck/services/ppt_generator.dart';

Uint8List _png() {
  const w = 120;
  const h = 90;
  final raw = <int>[];
  for (var y = 0; y < h; y++) {
    raw.add(0);
    for (var x = 0; x < w; x++) {
      raw.add((x * 5) & 0xFF);
      raw.add((y * 7) & 0xFF);
      raw.add(((x + y)) & 0xFF);
    }
  }
  return Uint8List.fromList(raw);
}

void main() {
  test('generate bisect decks for the COM check', () async {
    final image = base64Encode(_png());
    const chartJson =
        '{"type":"column","labels":["Q1","Q2","Q3","Q4"],"series":[{"name":"Doanh thu","values":[120,150,180,210]}]}';
    const smartartJson =
        '{"layout":"basicProcess","nodes":[{"id":"n1","text":"Lap ke hoach"},{"id":"n2","text":"Thuc hien"},{"id":"n3","text":"Kiem tra"}]}';
    const iconJson = '{"name":"chart-bar","color":"#1F6FEB","size":48}';
    const equationJson =
        '{"mathml":"<math><msup><mi>a</mi><mn>2</mn></msup><mo>+</mo><msup><mi>b</mi><mn>2</mn></msup><mo>=</mo><msup><mi>c</mi><mn>2</mn></msup></math>"}';
    const actionJson =
        '{"kind":"next","label":"Tiep theo","x":70,"y":80,"w":20,"h":10}';
    final oleJson =
        '{"fileName":"data.txt","fileBase64":"${base64Encode('Ghita OLE payload'.codeUnits)}"}';
    const zoomJson = '{"x":5,"y":10,"w":30,"h":20,"slide":2}';
    const cameoJson = '{"x":60,"y":60,"w":25,"h":30}';

    final base = Slide(
      title: 'Tổng quan',
      htmlContent: '<h2>Báo cáo quý</h2>'
          '<p>Nội dung <b>đậm</b>, <i>nghiêng</i> và <u>gạch chân</u>.</p>'
          '<img src="data:image/png;base64,$image">',
      notes: 'Ghi chú slide một',
    );

    final variants = <String, List<Slide>>{
      'f_gold_combined': [
        base,
        Slide(
          title: 'Biểu đồ',
          htmlContent: "<div data-chart='$chartJson'></div>"
              "<div data-smartart='$smartartJson'></div>"
              "<span data-icon='$iconJson'></span>"
              "<div data-equation='$equationJson'></div>",
        ),
        Slide(
          title: 'Tương tác',
          htmlContent: "<div data-action='$actionJson'></div>"
              "<div data-zoom='$zoomJson'></div>"
              "<div data-cameo='$cameoJson'></div>",
        ),
      ],
      'c1_action': [
        base,
        Slide(title: 'Action', htmlContent: "<div data-action='$actionJson'></div>"),
      ],
      'c2_zoom': [
        base,
        Slide(title: 'Zoom', htmlContent: "<div data-zoom='$zoomJson'></div>"),
      ],
      'c3_cameo': [
        base,
        Slide(title: 'Cameo', htmlContent: "<div data-cameo='$cameoJson'></div>"),
      ],
      'a_text_only': [base],
      'b_chart_smartart_icon_equation': [
        base,
        Slide(
          title: 'Biểu đồ',
          htmlContent: "<div data-chart='$chartJson'></div>"
              "<div data-smartart='$smartartJson'></div>"
              "<span data-icon='$iconJson'></span>"
              "<div data-equation='$equationJson'></div>",
        ),
      ],
      'c_action_zoom_cameo': [
        base,
        Slide(
          title: 'Tương tác',
          htmlContent: "<div data-action='$actionJson'></div>"
              "<div data-zoom='$zoomJson'></div>"
              "<div data-cameo='$cameoJson'></div>",
        ),
      ],
      'd_ole': [
        base,
        Slide(title: 'OLE', htmlContent: "<div data-ole='$oleJson'></div>"),
      ],
      'e_full': [
        base,
        Slide(
          title: 'Biểu đồ',
          htmlContent: "<div data-chart='$chartJson'></div>"
              "<div data-smartart='$smartartJson'></div>"
              "<span data-icon='$iconJson'></span>"
              "<div data-equation='$equationJson'></div>",
        ),
        Slide(
          title: 'Tương tác',
          htmlContent: "<div data-action='$actionJson'></div>"
              "<div data-zoom='$zoomJson'></div>"
              "<div data-cameo='$cameoJson'></div>"
              "<div data-ole='$oleJson'></div>",
        ),
      ],
    };

    final dir = Directory('build/com_check');
    dir.createSync(recursive: true);
    for (final entry in variants.entries) {
      final file = File('${dir.path}/deck_${entry.key}.pptx');
      await PPTGenerator.generatePPT(
        entry.value.map((s) => s.toMap()).toList(),
        file.path,
      );
      stdout.writeln('made ${file.path} ${file.lengthSync()} bytes');
    }
  });
}
