import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/src/rust/api/htmlparse.dart' as rust_api;
import 'package:ghita_ppt_converter/src/rust/frb_generated.dart' as frb;

/// T13.3 parity: the Rust tokenizer must produce the exact same block tree
/// as the Dart parser for every corpus input. Corpus = the real templates +
/// hand-written edge cases (lists/tables/styled spans/data-* kinds).
///
/// Run: flutter test test/htmlparse_parity_test.dart
void main() {
  late bool rustReady;

  setUpAll(() async {
    try {
      await frb.RustLib.init();
      rustReady = true;
    } catch (_) {
      rustReady = false;
    }
    // Mirrors the pp: parser's expected tree.
  });

  final corpus = <String, String>{
    't_business': File('assets/templates/business.html').readAsStringSync(),
    't_creative': File('assets/templates/creative.html').readAsStringSync(),
    't_academic': File('assets/templates/academic.html').readAsStringSync(),
    't_marketing': File('assets/templates/marketing.html').readAsStringSync(),
    't_minimal': File('assets/templates/minimal.html').readAsStringSync(),
    't_tech_dashboard':
        File('assets/templates/tech_dashboard.html').readAsStringSync(),
    't_special_title':
        File('assets/templates/special_title.html').readAsStringSync(),
    't_data_timeline':
        File('assets/templates/data_timeline.html').readAsStringSync(),

    // Edge cases ------------------------------------------------------------
    'plain_text': 'Chỉ là văn bản không thẻ',
    'heading': '<h1>Tiêu đề</h1><h2>Phụ đề</h2><p>Đoạn văn</p>',
    'list_ul': '<ul><li>Một</li><li>Hai</li></ul>',
    'list_ol': '<ol><li>Đầu</li><li>Cuối</li></ol>',
    'mixed_list_paragraph': '<p>Dẫn</p><ul><li>A</li></ul><p>Kết</p>',
    'nested_list':
        '<ul><li>Cha<ul><li>Con 1</li><li>Con 2</li></ul></li><li>Anh</li></ul>',
    'table_simple':
        '<table><tr><th>Cột A</th><th>Cột B</th></tr><tr><td>1</td><td>2</td></tr></table>',
    'table_thead_tbody':
        '<table><thead><tr><th>H</th></tr></thead><tbody><tr><td>D</td></tr></tbody></table>',
    'bold_italic':
        '<p><b>Đậm</b> và <i>nghiêng</i> và <strong>Đậm2</strong></p>',
    'underline_strike':
        '<p><u>Gạch chân</u> <s>Gạch ngang</s> <del>Xóa</del></p>',
    'inline_styles':
        '<p style="color:#FF0000">Đỏ</p>'
        '<p style="font-size:20px;font-family:Arial;text-align:center">Mix</p>',
    'anchor_br':
        '<p>Xem <a href="https://example.com">liên kết</a><br>dòng mới</p>',
    'data_blocks':
        '<div data-chart="line;1"></div><div data-action="next"></div>'
        '<span data-icon="star"></span><div data-smartart="x"></div>',
    'image_video':
        '<img src="a.png"/><video data-video="v.mp4" poster="p.jpg"></video>',
    'div_blocks':
        '<div><h1>Tựa</h1><p>Nội dung</p><ul><li>N</li></ul></div>',
    'break_in_paragraph': '<p>Dòng một<br>dòng hai</p>',
    'empty_input': '',
    'only_spaces': '   ',
    'multiple_paragraphs': '<p>A</p><p>B</p><span>C</span><p>D</p>',
    'whitespace_collapse':
        '<p>  Nhiều\n\tkhoảng\n\t\tcách  </p>',
    'table_with_inline':
        '<table><tr><td style="color:#00FF00">Xanh</td><td><b>Đậm</b></td></tr></table>',
    'notes_aside':
        '<h1>Tựa</h1><p>Body</p><aside class="notes">Ghi chú 1</aside>',
    'aside_other':
        '<p>Body</p><aside class="footer">Chân trang</aside>',
    'list_style_li': '<ul><li style="color:#0099FF">A</li><li>B</li></ul>',
    'span_plain': '<span>Plain span</span><p>After</p>',
    'nested_bold_italic': '<p><b>Đậm <i>và nghiêng</i></b></p>',
    'p_has_block_children_and_text': '<p>Xin chào<ul><li>1</li></ul></p>',
    'tab_inside_table': '<table><tr><td>A</td></tr></table>p kế sau',
    'odd_tag_padding': '<div><p>A</p>  <b>B</b> <em>C</em></div>',
    'empty_li': '<ul><li></li><li>Có nội dung</li></ul>',
    'no_body_text': '<html><head><title>T</title></head></html>',
    'only_note': '<aside class="notes">Chỉ ghi chú</aside>',
    'h_only_empty_h1_h2': '<h1></h1><h2>Tựa từ h2</h2>',
  };

  // Dart reference tree for one HTML input.
  Map<String, dynamic> dartTree(String html) {
    return {
      'blocks': PPTGenerator.parseHtmlContentFull(html),
      'notes': PPTGenerator.extractNotes(html),
    };
  }

  // Deep equality ignoring map key order (Dart Map preserves insertion
  // order; serde_json's BTreeMap sorts keys — the trees must be equal as
  // structures, not as serialized strings).
  bool deepEq(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  test('corpus: Rust and Dart block trees are identical', () {
    if (!rustReady) {
      markTestSkipped('Rust DLL not loadable in this environment');
      return;
    }
    final mismatches = <String>[];
    for (final entry in corpus.entries) {
      final name = entry.key;
      final html = entry.value;
      final rustJson = rust_api.htmlparseBlocks(html: html);
      final rust = jsonDecode(rustJson) as Map<String, dynamic>;
      if (rust.containsKey('error')) {
        mismatches.add('$name: Rust returned error: ${rust['error']}');
        continue;
      }
      final dart = dartTree(html);
      if (!deepEq(rust['blocks'], dart['blocks'])) {
        mismatches.add('$name: blocks differ\n'
            '  dart: ${dart['blocks']}\n'
            '  rust: ${rust['blocks']}');
      }
    }
    expect(mismatches, isEmpty,
        reason: 'Rust/Dart parse parity failed:\n${mismatches.join('\n\n')}');
  });
}
