import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/core/document/slide_document.dart';
import 'package:ghita_ppt_converter/core/html/html_parser.dart';

const _chartPayload = '{"type":"bar","labels":["A","B"],"series":[{"name":"S","values":[1,2]}]}';

const _edgeCases = <String, String>{
  'top-level chart': "<div data-chart='$_chartPayload'></div><p>body</p>",
  'chart in plain div': "<div class='wrap'><div data-chart='$_chartPayload'></div></div>",
  'chart nested in p': "<p>x<div data-chart='$_chartPayload'></div></p>",
  'multiple charts': "<div data-chart='$_chartPayload'></div><div data-chart='$_chartPayload'></div>",
  'smartart block': "<div data-smartart='{\"layout\":\"list\",\"nodes\":[{\"id\":\"n1\",\"text\":\"A\"}]}'></div>",
  'video with src': "<video data-video='{\"src\":\"media/v.mp4\"}' src='media/v.mp4' poster='media/p.jpg'></video>",
  'cameo block': "<div data-cameo='{\"x\":10,\"y\":20,\"w\":30,\"h\":40}'></div>",
  'zoom block': "<div data-zoom='{\"x\":1,\"y\":2,\"w\":3,\"h\":4,\"slide\":2}'></div>",
  'section zoom': "<div data-sectionzoom='{\"x\":1,\"y\":2,\"w\":3,\"h\":4,\"title\":\"s\"}'></div>",
  'action button': "<div data-action='{\"kind\":\"next\",\"x\":5,\"y\":6,\"w\":7,\"h\":8}'></div>",
  'equation block': "<div data-equation='{\"mathml\":\"<math><mi>x</mi></math>\"}'></div>",
  'ole block': "<div data-ole='{\"fileName\":\"a.bin\",\"fileBase64\":\"\"}'></div>",
  'model3d block': "<div data-model3d='{\"src\":\"data:model/gltf-binary;base64,Z2xURg==\"}'></div>",
  'bg color attr': "<div data-bg-color='#ff8800'><p>hi</p></div>",
  'no data blocks': '<h1>Title</h1><p>plain body text</p>',
};

const _pptxAlignedDivergences = <String, String>{
  'chart in list item': "<ul><li>a<div data-chart='$_chartPayload'></div></li></ul>",
  'chart in table cell': "<table><tr><td><div data-chart='$_chartPayload'></div></td></tr></table>",
};

String _fixtureHtml() {
  final dir = Directory('assets/templates');
  final buffer = StringBuffer();
  for (final file in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html'))) {
    buffer.writeln(file.readAsStringSync());
  }
  return buffer.toString();
}

List<String> _regexPayloads(String html, RegExp pattern, int group) =>
    pattern.allMatches(html).map((m) => m.group(group)!).toList();

void _expectParity(String label, String html) {
  final doc = SlideDocumentParser.fromHtml(html, cache: HtmlParseCache(capacity: 4));
  final attrs = doc.attributes;
  final expected = <DocBlockKind, List<String>>{
    DocBlockKind.smartart: _regexPayloads(html, HtmlAttrScan.diagramPatternRe, 2),
    DocBlockKind.chart: _regexPayloads(html, HtmlAttrScan.chartPatternRe, 1),
    DocBlockKind.model3d: _regexPayloads(html, HtmlAttrScan.model3dPatternRe, 2),
    DocBlockKind.action: _regexPayloads(html, HtmlAttrScan.actionPatternRe, 2),
    DocBlockKind.equation: _regexPayloads(html, HtmlAttrScan.equationPatternRe, 2),
    DocBlockKind.ole: _regexPayloads(html, HtmlAttrScan.olePatternRe, 2),
    DocBlockKind.zoom: _regexPayloads(html, HtmlAttrScan.zoomPatternRe, 2),
    DocBlockKind.sectionzoom: _regexPayloads(html, HtmlAttrScan.sectionZoomPatternRe, 2),
    DocBlockKind.cameo: _regexPayloads(html, HtmlAttrScan.cameoPatternRe, 2),
  };
  expected.forEach((kind, payloads) {
    expect(attrs.payloadsFor(kind), payloads,
        reason: '$label: block-derived payloads diverge from regex for ${kind.name}');
  });
}

void main() {
  test('IR round-trips every fixture and edge case block-for-block', () {
    final cases = <String, List<String>>{
      'templates': [_fixtureHtml()],
      'edges': _edgeCases.values.toList(),
    };
    cases.forEach((label, htmls) {
      for (final html in htmls) {
        final blocks = HtmlParseCore.parseHtmlContentFull(html);
        for (final block in blocks) {
          final typed = DocBlock.fromLegacy(block);
          final back = typed.toLegacy();
          expect(jsonEncode(back), jsonEncode(block),
              reason: '$label: round-trip drift for block ${block['type']}');
        }
      }
    });
  });

  test('IR attribute payloads match the legacy regex extraction on templates', () {
    _expectParity('templates', _fixtureHtml());
  });

  test('IR attribute payloads match the legacy regex extraction on edge cases', () {
    _edgeCases.forEach(_expectParity);
  });

  test('PPTX aligns to the block tree where the legacy regex saw more', () {
    _pptxAlignedDivergences.forEach((label, html) {
      final doc = SlideDocumentParser.fromHtml(html, cache: HtmlParseCache(capacity: 4));
      expect(doc.attributes.chart, isEmpty,
          reason: '$label: PPTX must render exactly what PDF and HTML render');
      expect(HtmlAttrScan.chartPatternRe.allMatches(html), hasLength(1),
          reason: '$label: the legacy regex path was the outlier');
    });
  });

  test('IR sees payloads the single-quote regex is blind to', () {
    const html = '<div data-chart="$_chartPayload"></div>';
    final doc = SlideDocumentParser.fromHtml(html, cache: HtmlParseCache(capacity: 4));
    expect(doc.attributes.chart, hasLength(1));
    expect(HtmlAttrScan.chartPatternRe.allMatches(html), isEmpty);
  });

  test('SlideDocumentParser surfaces notes, subtitle and bg color', () {
    const html = '<h2>Deck subtitle</h2><p>body</p>'
        '<div data-bg-color="#102030"></div>'
        '<aside class="notes">speaker line</aside>';
    final doc = SlideDocumentParser.fromHtml(html, cache: HtmlParseCache(capacity: 4));
    expect(doc.subtitle, 'Deck subtitle');
    expect(doc.notes, 'speaker line');
    expect(doc.bgColor, '#102030');
    expect(doc.schemaVersion, SlideDocument.currentSchemaVersion);
  });

  test('video blocks carry src and poster for the PPTX writer', () {
    final html = _edgeCases['video with src']!;
    final doc = SlideDocumentParser.fromHtml(html, cache: HtmlParseCache(capacity: 4));
    expect(doc.attributes.video, hasLength(1));
    final block = doc.blocks.firstWhere((b) => b.kind == DocBlockKind.video);
    expect(block.src, 'media/v.mp4');
    expect(block.poster, 'media/p.jpg');
  });
}
