import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/free_shape.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/wordart_service.dart';

/// Track 17 tests — WordArt & TextBox tự do (FEAT 15, 16).
///
///  * FreeTextShape round-trip + HTML markup (P1),
///  * WordArt service: 12 styles, CSS + OOXML effect/gradient (P4),
///  * visualElements export: PPTX p:sp with xfrm at %→EMU, HTML absolute
///    div, PDF widget (P3, P5, P6),
///  * TextBox at 30%,40% keeps position in PPTX (P10),
///  * regression: deck without visualElements exports unchanged (P10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> slideWithFreeTexts(List<Map<String, dynamic>> texts) => {
        'title': 'Free Text',
        'htmlContent': '<h1>Title</h1><p>Body</p>',
        'visualElements': {'freeTexts': texts},
      };

  Future<Archive> exportPptx(Map<String, dynamic> slide) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t17_');
    try {
      await PPTGenerator.generatePPT([slide], '${dir.path}/out.pptx');
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  group('FreeTextShape model (P1)', () {
    test('round-trips through toMap/fromMap', () {
      const shape = FreeTextShape(
        id: 'ft1',
        text: 'Hello',
        x: 30,
        y: 40,
        w: 25,
        h: 12,
        rotation: 15,
        zOrder: 3,
        fontSize: 24,
        fontWeight: 'bold',
        color: '#FF0000',
        backgroundColor: '#EEEEEE',
        shadow: true,
        wordArtStyle: 5,
      );
      final restored = FreeTextShape.fromMap(shape.toMap());
      expect(restored.id, 'ft1');
      expect(restored.x, 30);
      expect(restored.y, 40);
      expect(restored.w, 25);
      expect(restored.h, 12);
      expect(restored.rotation, 15);
      expect(restored.zOrder, 3);
      expect(restored.fontWeight, 'bold');
      expect(restored.color, '#FF0000');
      expect(restored.shadow, isTrue);
      expect(restored.wordArtStyle, 5);
    });

    test('round-trips through JSON', () {
      const shape = FreeTextShape(text: 'JSON', x: 10, y: 20, w: 30, h: 15);
      final restored = FreeTextShape.fromJson(shape.toJson());
      expect(restored.text, 'JSON');
      expect(restored.x, 10);
      expect(restored.y, 20);
    });

    test('htmlMarkup uses percentage coordinates', () {
      const shape = FreeTextShape(
        text: 'Hello',
        x: 30,
        y: 40,
        w: 25,
        h: 12,
        color: '#FF0000',
        backgroundColor: 'transparent',
      );
      final html = shape.htmlMarkup;
      expect(html, contains('left:30.0%'));
      expect(html, contains('top:40.0%'));
      expect(html, contains('width:25.0%'));
      expect(html, contains('height:12.0%'));
      expect(html, contains('color:#FF0000'));
      expect(html, contains('>Hello</div>'));
    });
  });

  group('WordArt service (P4)', () {
    test('has 12 styles', () {
      expect(WordArtService.count, 12);
    });

    test('styleCss returns CSS for valid style, empty for 0/out-of-range', () {
      expect(WordArtService.styleCss(0), isEmpty);
      expect(WordArtService.styleCss(1), isNotEmpty);
      expect(WordArtService.styleCss(12), isNotEmpty);
      expect(WordArtService.styleCss(13), isEmpty);
    });

    test('styleName returns names', () {
      expect(WordArtService.styleName(0), 'None');
      expect(WordArtService.styleName(1), isNotEmpty);
    });

    test('pptxGradFill returns gradFill for gradient styles', () {
      expect(WordArtService.pptxGradFill(5), contains('<a:gradFill>'));
      expect(WordArtService.pptxGradFill(6), contains('<a:gradFill>'));
      expect(WordArtService.pptxGradFill(7), contains('<a:gradFill>'));
      expect(WordArtService.pptxGradFill(1), isEmpty);
    });

    test('pptxEffectLst returns effects for outline/shadow/glow', () {
      expect(WordArtService.pptxEffectLst(9), contains('a:ln'));
      expect(WordArtService.pptxEffectLst(10), contains('outerShdw'));
      expect(WordArtService.pptxEffectLst(12), contains('glow'));
      expect(WordArtService.pptxEffectLst(1), isEmpty);
    });
  });

  group('PPTX export (P3, P5, P10)', () {
    test('TextBox at 30%,40% becomes a p:sp at correct EMU', () async {
      final slide = slideWithFreeTexts([
        {
          'id': 'ft1',
          'text': 'Hello Box',
          'x': 30.0,
          'y': 40.0,
          'w': 25.0,
          'h': 10.0,
          'fontSize': 24.0,
          'color': '#FF0000',
          'zOrder': 1,
        },
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      // 30% of 9144000 = 2743200, 40% of 6858000 = 2743200
      expect(slideXml, contains('<a:off x="2743200" y="2743200"/>'));
      // 25% of 9144000 = 2286000, 10% of 6858000 = 685800
      expect(slideXml, contains('<a:ext cx="2286000" cy="685800"/>'));
      expect(slideXml, contains('name="FreeText ft1"'));
      expect(slideXml, contains('>Hello Box</a:t>'));
      // Text colour red
      expect(slideXml, contains('val="FF0000"'));
    });

    test('WordArt style 5 maps to a gradient fill in PPTX', () async {
      final slide = slideWithFreeTexts([
        {
          'id': 'ft2',
          'text': 'Gradient',
          'x': 10.0,
          'y': 10.0,
          'w': 40.0,
          'h': 15.0,
          'wordArtStyle': 5,
        },
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('<a:gradFill>'));
      expect(slideXml, contains('FF5F6D'));
    });

    test('WordArt style 10 maps to a shadow effect', () async {
      final slide = slideWithFreeTexts([
        {
          'id': 'ft3',
          'text': 'Shadow',
          'x': 10.0,
          'y': 10.0,
          'w': 40.0,
          'h': 15.0,
          'wordArtStyle': 10,
        },
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('outerShdw'));
    });

    test('rotation writes the rot attribute', () async {
      final slide = slideWithFreeTexts([
        {
          'id': 'ft4',
          'text': 'Rotated',
          'x': 10.0,
          'y': 10.0,
          'w': 40.0,
          'h': 15.0,
          'rotation': 90.0,
        },
      ]);
      final archive = await exportPptx(slide);
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      // 90 * 60000 = 5400000
      expect(slideXml, contains('rot="5400000"'));
    });

    test('deck without visualElements exports unchanged (P10)', () async {
      final archive = await exportPptx({
        'title': 'Plain',
        'htmlContent': '<h1>Hello</h1>',
      });
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, isNot(contains('FreeText')));
    });
  });

  group('HTML export (P6)', () {
    test('freeTexts render as absolute divs', () {
      final html = HtmlExportService().buildPresentationHtml([
        slideWithFreeTexts([
          {'id': 'ft1', 'text': 'Hello Box', 'x': 30.0, 'y': 40.0, 'w': 25.0, 'h': 10.0},
        ]),
      ]);
      expect(html, contains('position:absolute'));
      expect(html, contains('left:30.0%'));
      expect(html, contains('top:40.0%'));
      expect(html, contains('>Hello Box</div>'));
    });

    test('deck without visualElements has no absolute divs', () {
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'Plain', 'htmlContent': '<h1>Hello</h1>'},
      ]);
      expect(html, isNot(contains('position:absolute')));
    });
  });

  group('PDF export (P6)', () {
    test('freeTexts render without crashing', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t17pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf([
          slideWithFreeTexts([
            {'id': 'ft1', 'text': 'Hello Box', 'x': 30.0, 'y': 40.0, 'w': 25.0, 'h': 10.0, 'color': '#FF0000'},
          ]),
        ], path);
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('Slide.visualElements persistence (P3)', () {
    test('Slide toMap/fromMap round-trips visualElements', () {
      final slide = Slide(
        title: 'T',
        htmlContent: '<p>x</p>',
        visualElements: {
          'freeTexts': [
            {'id': 'ft1', 'text': 'Hello', 'x': 30.0, 'y': 40.0, 'w': 25.0, 'h': 10.0},
          ],
        },
      );
      final restored = Slide.fromMap(slide.toMap());
      expect(restored.visualElements['freeTexts'], isA<List>());
      final ft = FreeTextShape.fromMap(
          Map<String, dynamic>.from((restored.visualElements['freeTexts'] as List).first as Map));
      expect(ft.text, 'Hello');
      expect(ft.x, 30.0);
    });
  });
}