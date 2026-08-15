import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/export_options.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:xml/xml.dart' as xml;

/// 1x1 black PNG used for image embedding tests.
const String kOnePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// Read all text parts of a generated PPTX into a map path -> content.
Map<String, String> readPptxParts(File file) {
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final parts = <String, String>{};
  for (final f in archive.files) {
    if (f.isFile && (f.name.endsWith('.xml') || f.name.endsWith('.rels'))) {
      parts[f.name] = utf8.decode(f.content as List<int>);
    } else if (f.isFile) {
      parts[f.name] = '';
    }
  }
  return parts;
}

Future<Map<String, String>> generateParts(
  List<Map<String, dynamic>> slides, {
  SlideEffect effect = SlideEffect.none,
}) async {
  final f = File(
      '${Directory.systemTemp.path}/gen_${DateTime.now().microsecondsSinceEpoch}.pptx');
  final file = await PPTGenerator.generatePPT(slides, f.path, effect: effect);
  final parts = readPptxParts(file);
  file.deleteSync();
  return parts;
}

// Tests for the PPTX generation engine
void main() {
  final tmpDir = Directory.systemTemp.path;

  group('parseHtmlContent - basic text', () {
    test('returns single paragraph for <p> tag', () {
      final r = PPTGenerator.parseHtmlContent('<p>Hello world</p>');
      expect(r.length, 1);
      expect(r.first['text'], 'Hello world');
    });
    test('returns single paragraph for plain text', () {
      final r = PPTGenerator.parseHtmlContent('Plain text');
      expect(r.length, 1);
      expect(r.first['text'], 'Plain text');
    });
    test('preserves bold via <b>', () {
      final r = PPTGenerator.parseHtmlContent('<b>Bold text</b>');
      expect(r.first['bold'], 'true');
    });
    test('preserves italic via <em>', () {
      final r = PPTGenerator.parseHtmlContent('<em>Italic text</em>');
      expect(r.first['italic'], 'true');
    });
    test('preserves both bold and italic', () {
      final r = PPTGenerator.parseHtmlContent('<b><em>Both</em></b>');
      expect(r.first['bold'], 'true');
      expect(r.first['italic'], 'true');
    });
    test('preserves strong via <strong>', () {
      final r = PPTGenerator.parseHtmlContent('<strong>Strong</strong>');
      expect(r.first['bold'], 'true');
    });
    test('preserves italic via <i>', () {
      final r = PPTGenerator.parseHtmlContent('<i>Italic</i>');
      expect(r.first['italic'], 'true');
    });
  });
  group('parseHtmlContent - structure', () {
    test('br creates break paragraphs', () {
      final r = PPTGenerator.parseHtmlContent('Line1<br>Line2');
      expect(r.where((p) => p['isBreak'] == 'true'), hasLength(1));
    });
    test('multiple <p> tags create separate paragraphs', () {
      final r = PPTGenerator.parseHtmlContent('<p>A</p><p>B</p>');
      expect(r.where((p) => (p['text'] ?? '').isNotEmpty), hasLength(2));
    });
    test('unordered list items preserved', () {
      final r = PPTGenerator.parseHtmlContent(
          '<ul><li>Item A</li><li>Item B</li></ul>');
      expect(r.where((p) => (p['text'] ?? '').contains('Item')), hasLength(2));
    });
    test('empty input returns fallback', () {
      final r = PPTGenerator.parseHtmlContent('');
      expect(r.length, 1);
    });
  });
  group('parseHtmlContentFull - structured blocks', () {
    test('detects list blocks', () {
      final blocks = PPTGenerator.parseHtmlContentFull(
          '<ul><li>One</li><li>Two</li></ul>');
      expect(blocks.any((b) => b['type'] == 'list'), isTrue);
      final listBlock = blocks.firstWhere((b) => b['type'] == 'list');
      expect((listBlock['items'] as List).length, 2);
      expect(listBlock['ordered'], false);
    });
    test('detects ordered list', () {
      final blocks =
          PPTGenerator.parseHtmlContentFull('<ol><li>First</li></ol>');
      final listBlock = blocks.firstWhere((b) => b['type'] == 'list');
      expect(listBlock['ordered'], true);
    });
    test('detects table blocks', () {
      final blocks = PPTGenerator.parseHtmlContentFull(
          '<table><tr><td>A</td><td>B</td></tr></table>');
      expect(blocks.any((b) => b['type'] == 'table'), isTrue);
    });
  });
  group('generatePPT - file creation', () {
    test('rejects an empty presentation instead of writing a corrupt package',
        () async {
      final f = File('$tmpDir/test_empty_ppt.pptx');
      await expectLater(
        PPTGenerator.generatePPT(const [], f.path),
        throwsA(isA<Exception>()),
      );
      expect(f.existsSync(), isFalse);
    });

    test('generates non-empty PPTX file with 16:9 default', () async {
      final f = File('$tmpDir/test_ppt.pptx');
      final slides = [
        {'title': 'Test', 'htmlContent': '<p>Content</p>'},
      ];
      final file = await PPTGenerator.generatePPT(slides, f.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      f.deleteSync();
    });
    test('generates PPTX with 4:3 when widescreen=false', () async {
      final f = File('$tmpDir/test_ppt_43.pptx');
      final slides = [
        {'title': 'Test', 'htmlContent': '<p>Content</p>'},
      ];
      final file =
          await PPTGenerator.generatePPT(slides, f.path, widescreen: false);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      f.deleteSync();
    });
    test('generates PPTX with list content', () async {
      final f = File('$tmpDir/test_ppt_list.pptx');
      final slides = [
        {
          'title': 'List Test',
          'htmlContent': '<ul><li>Item 1</li><li>Item 2</li></ul>',
        },
      ];
      final file = await PPTGenerator.generatePPT(slides, f.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      f.deleteSync();
    });
    test('generates PPTX with table content', () async {
      final f = File('$tmpDir/test_ppt_table.pptx');
      final slides = [
        {
          'title': 'Table Test',
          'htmlContent':
              '<table><tr><th>Name</th><th>Value</th></tr><tr><td>A</td><td>1</td></tr></table>',
        },
      ];
      final file = await PPTGenerator.generatePPT(slides, f.path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      f.deleteSync();
    });

    test('honors portrait dimensions and advanced include flags', () async {
      final f = File('$tmpDir/test_ppt_portrait_options.pptx');
      final file = await PPTGenerator.generatePPT(
        [
          {
            'title': 'Portrait',
            'bgColor': '#123456',
            'notes': 'Do not include this note',
            'htmlContent': '<p>Content</p>',
          }
        ],
        f.path,
        aspectRatio: ExportAspectRatio.portrait9x16,
        includeNotes: false,
        includeBackgrounds: false,
      );
      final parts = readPptxParts(file);

      expect(parts['ppt/presentation.xml'],
          contains('<p:sldSz cx="5143500" cy="9144000"/>'));
      expect(parts['ppt/slides/slide1.xml'], isNot(contains('<p:bg>')));
      expect(parts.keys, isNot(contains('ppt/notesSlides/notesSlide1.xml')));
      expect(parts.keys, isNot(contains('ppt/notesMasters/notesMaster1.xml')));
      file.deleteSync();
    });
  });

  group('v0.3.0 regressions - XML validity', () {
    test('uses schema-valid geometry and slide child order', () async {
      final parts = await generateParts(
        [
          {
            'title': 'Schema',
            'htmlContent': '<h2>Subtitle</h2><p>Body</p>',
          }
        ],
        effect: SlideEffect.fade,
      );
      final slideXml = parts['ppt/slides/slide1.xml']!;

      expect(slideXml, contains('<a:prstGeom prst="rect">'));
      expect(slideXml, isNot(contains('<a:presetGeom')));
      expect(slideXml.indexOf('<p:cSld>'),
          lessThan(slideXml.indexOf('<p:transition')));
      expect('<a:t>Subtitle</a:t>'.allMatches(slideXml), hasLength(1));
      expect(slideXml, isNot(contains('<p:ph type="subTitle"')));
    });

    test('keeps inline formatting and line breaks in one paragraph', () async {
      final parts = await generateParts([
        {
          'title': 'Runs',
          'htmlContent':
              '<p>Hello <strong>bold</strong>, <em>italic</em><br>next line</p>',
        }
      ]);
      final document = xml.XmlDocument.parse(parts['ppt/slides/slide1.xml']!);
      final contentShape = document.descendants
          .whereType<xml.XmlElement>()
          .firstWhere((element) =>
              element.name.local == 'sp' &&
              element.descendants.whereType<xml.XmlElement>().any((child) =>
                  child.name.local == 'cNvPr' &&
                  child.getAttribute('name') == 'Content Text'));
      final paragraphs = contentShape.descendants
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 'p')
          .toList();

      expect(paragraphs, hasLength(1));
      expect(
        paragraphs.single.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 'buNone'),
        hasLength(1),
      );
      expect(
        paragraphs.single.children
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 'br'),
        hasLength(1),
      );
      expect(
        paragraphs.single.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join(),
        'Hello bold, italicnext line',
      );
      expect(parts['ppt/slides/slide1.xml'], contains('xml:space="preserve"'));
    });

    test('keeps styled list runs in their original list item', () async {
      final parts = await generateParts([
        {
          'title': 'List runs',
          'htmlContent':
              '<ul><li>First <strong>bold</strong> item</li><li>Second</li></ul>',
        }
      ]);
      final document = xml.XmlDocument.parse(parts['ppt/slides/slide1.xml']!);
      final listShape = document.descendants
          .whereType<xml.XmlElement>()
          .firstWhere((element) =>
              element.name.local == 'sp' &&
              element.descendants.whereType<xml.XmlElement>().any((child) =>
                  child.name.local == 'cNvPr' &&
                  child.getAttribute('name') == 'List Content'));
      final paragraphs = listShape.descendants
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 'p')
          .toList();

      expect(paragraphs, hasLength(2));
      expect(
        paragraphs.first.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join(),
        'First bold item',
      );
      expect(
        paragraphs.first.descendants.whereType<xml.XmlElement>().where(
            (element) =>
                element.name.local == 'rPr' &&
                element.getAttribute('b') == '1'),
        isNotEmpty,
      );
    });

    test('lays out consecutive content blocks without overlap', () async {
      final parts = await generateParts([
        {
          'title': 'Flow',
          'htmlContent': '<p>Paragraph one</p><p>Paragraph two</p>'
              '<ul><li>First</li><li>Second</li></ul>'
              '<table><tr><th>A</th></tr><tr><td>B</td></tr></table>',
        }
      ]);
      final document = xml.XmlDocument.parse(parts['ppt/slides/slide1.xml']!);

      ({int y, int h}) geometry(String name) {
        final container = document.descendants
            .whereType<xml.XmlElement>()
            .firstWhere((element) =>
                (element.name.local == 'sp' ||
                    element.name.local == 'graphicFrame') &&
                element.descendants.whereType<xml.XmlElement>().any((child) =>
                    child.name.local == 'cNvPr' &&
                    child.getAttribute('name') == name));
        final transform = container.descendants
            .whereType<xml.XmlElement>()
            .firstWhere((element) => element.name.local == 'xfrm');
        final offset = transform.descendants
            .whereType<xml.XmlElement>()
            .firstWhere((element) => element.name.local == 'off');
        final extent = transform.descendants
            .whereType<xml.XmlElement>()
            .firstWhere((element) => element.name.local == 'ext');
        return (
          y: int.parse(offset.getAttribute('y')!),
          h: int.parse(extent.getAttribute('cy')!),
        );
      }

      final text = geometry('Content Text');
      final list = geometry('List Content');
      final table = geometry('Table');
      expect(text.y + text.h, lessThanOrEqualTo(list.y));
      expect(list.y + list.h, lessThanOrEqualTo(table.y));
    });

    test('ZIP headers declare correct UTF-8 byte sizes for non-ASCII content',
        () async {
      // Vietnamese title/notes + bullet glyph exercise multi-byte UTF-8.
      final f = File(
          '${Directory.systemTemp.path}/utf8_${DateTime.now().microsecondsSinceEpoch}.pptx');
      final file = await PPTGenerator.generatePPT([
        {
          'title': 'Xin chào Việt Nam — báo cáo quý',
          'htmlContent':
              '<p>Nội dung tiếng Việt đầy đủ dấu</p><ul><li>Gạch đầu dòng</li></ul>',
          'notes': 'Ghi chú thuyết trình bằng tiếng Việt',
        }
      ], f.path);
      final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
      for (final entry in archive.files.where((e) => e.isFile)) {
        final actual = (entry.content as List<int>).length;
        expect(entry.size, actual,
            reason:
                '${entry.name}: declared size ${entry.size} != actual bytes $actual');
      }
      f.deleteSync();
    });

    test('table cell txBody closing tag is not duplicated', () async {
      final parts = await generateParts([
        {
          'title': 'T',
          'htmlContent': '<table><tr><td>A</td></tr></table>',
        }
      ]);
      final slideXml = parts['ppt/slides/slide1.xml']!;
      expect(slideXml.contains('</a:txBody></a:txBody>'), isFalse);
      expect(() => xml.XmlDocument.parse(slideXml), returnsNormally);
    });

    test('bullet char is a real glyph, not a literal escape', () async {
      final parts = await generateParts([
        {
          'title': 'L',
          'htmlContent': '<ul><li>Item</li></ul>',
        }
      ]);
      final slideXml = parts['ppt/slides/slide1.xml']!;
      expect(slideXml, contains('buChar char="\u2022"'));
      expect(slideXml.contains(r'\u2022'), isFalse);
    });

    test('every slide XML part is well-formed', () async {
      final parts = await generateParts([
        {
          'title': 'Mix',
          'htmlContent': '<h2>Sub</h2><p>Text</p>'
              '<ul><li>A</li></ul>'
              '<table><tr><th>H</th></tr><tr><td>C</td></tr></table>',
        }
      ]);
      for (final entry in parts.entries) {
        if (entry.key.endsWith('.xml') || entry.key.endsWith('.rels')) {
          expect(() => xml.XmlDocument.parse(entry.value), returnsNormally,
              reason: '${entry.key} must be well-formed');
        }
      }
    });
  });

  group('v0.3.0 features - images', () {
    test('embeds base64 image with media part, rels and pic shape', () async {
      final parts = await generateParts([
        {
          'title': 'Img',
          'htmlContent':
              '<p>Before</p><img src="data:image/png;base64,$kOnePixelPngBase64">',
        }
      ]);
      expect(parts.keys, contains('ppt/media/image1.png'));
      expect(parts['[Content_Types].xml'],
          contains('Extension="png" ContentType="image/png"'));
      expect(parts['ppt/slides/slide1.xml'], contains('<p:pic>'));
      expect(parts['ppt/slides/_rels/slide1.xml.rels'],
          contains('../media/image1.png'));
    });

    test('image inside a paragraph is still embedded', () async {
      final parts = await generateParts([
        {
          'title': 'Img',
          'htmlContent':
              '<p>Caption <img src="data:image/png;base64,$kOnePixelPngBase64"></p>',
        }
      ]);
      expect(parts.keys, contains('ppt/media/image1.png'));
      expect(parts['ppt/slides/slide1.xml'], contains('<p:pic>'));
    });

    test('remote image URL is skipped without failing', () async {
      final parts = await generateParts([
        {
          'title': 'Img',
          'htmlContent': '<img src="https://example.com/pic.png"><p>Hi</p>',
        }
      ]);
      expect(parts['ppt/slides/slide1.xml']!.contains('<p:pic>'), isFalse);
    });
  });

  group('v0.3.0 features - styling', () {
    test('inline color, font-size and text-align are applied', () async {
      final parts = await generateParts([
        {
          'title': 'S',
          'htmlContent':
              '<p style="color:#ff0000;font-size:24px;text-align:center">Hi</p>',
        }
      ]);
      final slideXml = parts['ppt/slides/slide1.xml']!;
      expect(slideXml, contains('srgbClr val="FF0000"'));
      expect(slideXml, contains('sz="1800"')); // 24px = 18pt
      expect(slideXml, contains('algn="ctr"'));
    });

    test('underline and strike are applied', () async {
      final parts = await generateParts([
        {
          'title': 'S',
          'htmlContent': '<p><u>under</u> and <s>gone</s></p>',
        }
      ]);
      final slideXml = parts['ppt/slides/slide1.xml']!;
      expect(slideXml, contains('u="sng"'));
      expect(slideXml, contains('strike="sngStrike"'));
    });

    test('font-family maps to latin typeface', () async {
      final parts = await generateParts([
        {
          'title': 'S',
          'htmlContent': '<p style="font-family: Arial, sans-serif">Hi</p>',
        }
      ]);
      expect(parts['ppt/slides/slide1.xml'],
          contains('<a:latin typeface="Arial"/>'));
    });
  });

  group('v0.3.0 features - notes, hyperlinks, transitions', () {
    test('notes field produces a notes slide part', () async {
      final parts = await generateParts([
        {
          'title': 'N',
          'htmlContent': '<p>Body</p>',
          'notes': 'Remember to smile',
        }
      ]);
      expect(parts.keys, contains('ppt/notesSlides/notesSlide1.xml'));
      expect(parts['ppt/notesSlides/notesSlide1.xml'],
          contains('Remember to smile'));
      expect(parts['[Content_Types].xml'], contains('notesSlide1.xml'));
      expect(parts['ppt/slides/_rels/slide1.xml.rels'],
          contains('notesSlide1.xml'));
    });

    test('aside.notes in HTML becomes speaker notes, hidden from slide',
        () async {
      final parts = await generateParts([
        {
          'title': 'N',
          'htmlContent':
              '<p>Visible</p><aside class="notes">Secret note</aside>',
        }
      ]);
      expect(parts['ppt/notesSlides/notesSlide1.xml'], contains('Secret note'));
      expect(parts['ppt/slides/slide1.xml']!.contains('Secret note'), isFalse);
    });

    test('hyperlink produces external relationship and hlinkClick', () async {
      final parts = await generateParts([
        {
          'title': 'H',
          'htmlContent': '<p><a href="https://example.com">link</a></p>',
        }
      ]);
      expect(parts['ppt/slides/slide1.xml'], contains('<a:hlinkClick'));
      final rels = parts['ppt/slides/_rels/slide1.xml.rels']!;
      expect(rels, contains('https://example.com'));
      expect(rels, contains('TargetMode="External"'));
    });

    test('per-slide effect overrides the deck-wide effect', () async {
      final parts = await generateParts(
        [
          {'title': 'A', 'htmlContent': '<p>1</p>'},
          {'title': 'B', 'htmlContent': '<p>2</p>', 'effect': 'zoom'},
        ],
        effect: SlideEffect.fade,
      );
      expect(parts['ppt/slides/slide1.xml'], contains('<p:fade/>'));
      expect(parts['ppt/slides/slide2.xml'], contains('<p:zoom/>'));
    });

    test('auto-advance emits p:advTm in every slide transition', () async {
      final f = File(
          '${Directory.systemTemp.path}/gen_timing_${DateTime.now().microsecondsSinceEpoch}.pptx');
      final file = await PPTGenerator.generatePPT(
        [
          {'title': 'A', 'htmlContent': '<p>1</p>', 'effect': 'fade'},
          {'title': 'B', 'htmlContent': '<p>2</p>'},
        ],
        f.path,
        effect: SlideEffect.none,
        autoAdvance: const Duration(seconds: 4),
      );
      final parts = readPptxParts(file);
      file.deleteSync();

      // Slide with a visual transition also carries the timing element.
      expect(parts['ppt/slides/slide1.xml'], contains('<p:fade/>'));
      expect(parts['ppt/slides/slide1.xml'], contains('advTm="4000"'));
      // Slide with no visual effect still auto-advances.
      expect(parts['ppt/slides/slide2.xml'], contains('<p:transition'));
      expect(parts['ppt/slides/slide2.xml'], contains('advTm="4000"'));
      expect(parts['ppt/slides/slide1.xml'], isNot(contains('<p:advTm')));
      expect(parts['ppt/slides/slide2.xml'], isNot(contains('<p:advTm')));
      // Generated XML stays well-formed.
      expect(() => xml.XmlDocument.parse(parts['ppt/slides/slide1.xml']!),
          returnsNormally);
      expect(() => xml.XmlDocument.parse(parts['ppt/slides/slide2.xml']!),
          returnsNormally);
    });

    test('no p:advTm when auto-advance is not configured', () async {
      final parts = await generateParts([
        {'title': 'A', 'htmlContent': '<p>1</p>'},
      ]);
      expect(parts['ppt/slides/slide1.xml'], isNot(contains('advTm=')));
    });

    test('maps effects only to ISO PresentationML transition elements',
        () async {
      final checker = await generateParts(
        [
          {'title': 'C', 'htmlContent': '<p>x</p>'}
        ],
        effect: SlideEffect.checkerboard,
      );
      final clock = await generateParts(
        [
          {'title': 'W', 'htmlContent': '<p>x</p>'}
        ],
        effect: SlideEffect.clock,
      );
      final swivel = await generateParts(
        [
          {'title': 'S', 'htmlContent': '<p>x</p>'}
        ],
        effect: SlideEffect.swivel,
      );

      expect(checker['ppt/slides/slide1.xml'], contains('<p:checker/>'));
      expect(clock['ppt/slides/slide1.xml'], contains('<p:wheel/>'));
      expect(swivel['ppt/slides/slide1.xml'], contains('<p:fade/>'));
    });
  });

  group('slide metadata fidelity', () {
    test('typed bgColor overrides data-bg-color and is normalized', () async {
      final parts = await generateParts([
        {
          'title': 'Background',
          'htmlContent': '<div data-bg-color="#ff0000"><p>x</p></div>',
          'bgColor': 'rgb(0, 128, 255)',
        }
      ]);
      final slideXml = parts['ppt/slides/slide1.xml']!;
      expect(slideXml, contains('<a:srgbClr val="0080FF"/>'));
      expect(slideXml, isNot(contains('<a:srgbClr val="FF0000"/>')));
    });

    test('invalid background color is omitted instead of corrupting XML',
        () async {
      final parts = await generateParts([
        {
          'title': 'Background',
          'htmlContent': '<div data-bg-color="not-a-color"><p>x</p></div>',
        }
      ]);
      expect(parts['ppt/slides/slide1.xml'], isNot(contains('<p:bg>')));
    });
  });

  group('v0.3.0 features - package structure', () {
    test('theme, docProps and notes master parts exist', () async {
      final parts = await generateParts([
        {'title': 'T', 'htmlContent': '<p>x</p>', 'notes': 'note'}
      ]);
      expect(parts.keys, contains('ppt/theme/theme1.xml'));
      expect(parts.keys, contains('ppt/theme/theme2.xml'));
      expect(parts.keys, contains('docProps/core.xml'));
      expect(parts.keys, contains('docProps/app.xml'));
      expect(parts.keys, contains('ppt/notesMasters/notesMaster1.xml'));
      expect(parts.keys, contains('ppt/slideMasters/slideMaster1.xml'));
      expect(parts.keys, isNot(contains('ppt/slideMaster/slideMaster1.xml')));
      expect(parts['docProps/app.xml'], contains('Ghita PPT Converter'));
      expect(parts['docProps/core.xml'], contains('<dc:title>T</dc:title>'));
      expect(() => xml.XmlDocument.parse(parts['ppt/theme/theme1.xml']!),
          returnsNormally);
    });

    test('omits the complete notes chain when no slide has notes', () async {
      final parts = await generateParts([
        {'title': 'T', 'htmlContent': '<p>x</p>'}
      ]);
      expect(parts.keys, isNot(contains('ppt/notesMasters/notesMaster1.xml')));
      expect(parts.keys, isNot(contains('ppt/theme/theme2.xml')));
      expect(parts['ppt/presentation.xml'],
          isNot(contains('<p:notesMasterIdLst>')));
      expect(parts['ppt/_rels/presentation.xml.rels'],
          isNot(contains('relationships/notesMaster')));
      expect(parts['[Content_Types].xml'], isNot(contains('notesMaster1.xml')));
    });
  });

  group('CSS helpers', () {
    test('cssColorToHex handles formats', () {
      expect(PPTGenerator.cssColorToHex('#ff0000'), 'FF0000');
      expect(PPTGenerator.cssColorToHex('#f00'), 'FF0000');
      expect(PPTGenerator.cssColorToHex('rgb(0, 128, 255)'), '0080FF');
      expect(PPTGenerator.cssColorToHex('red'), 'FF0000');
      expect(PPTGenerator.cssColorToHex('not-a-color'), isNull);
    });

    test('cssFontSizeToSz converts units', () {
      expect(PPTGenerator.cssFontSizeToSz('24px'), '1800');
      expect(PPTGenerator.cssFontSizeToSz('18pt'), '1800');
      expect(PPTGenerator.cssFontSizeToSz('1.5em'), '1800');
      expect(PPTGenerator.cssFontSizeToSz('abc'), isNull);
    });
  });

  animationTimingTests();
  transitionTrack33Tests();
}

// ---- Track 32: per-object animation timing export ----------------------

void animationTimingTests() {
  group('Track 32 — p:timing export', () {
    test('slide with animation emits p:timing + animEffect', () async {
      final parts = await generateParts([
        {
          'title': 'S1',
          'htmlContent': '<h1>Hi</h1>',
          'visualElements': {
            'shapes': [
              {
                'id': 'a1',
                'type': 'rect',
                'x': 10,
                'y': 10,
                'w': 50,
                'h': 30,
                'zOrder': 0,
              },
            ],
            'animations': [
              {
                'shapeId': 'sh_a1',
                'effect': 'fadeIn',
                'group': 'entrance',
                'delay': 0,
                'duration': 0.5,
                'repeat': 0,
                'autoReverse': false,
                'start': 'onClick',
              },
            ],
          },
        },
      ]);
      final slideXml = parts['ppt/slides/slide1.xml'] ?? '';
      expect(slideXml, contains('<p:timing>'));
      expect(slideXml, contains('<p:seq concurrent="1" nextAc="seek">'));
      expect(slideXml, contains('<p:animEffect transition="in" filter="fade">'));
      expect(slideXml, contains('nodeType="clickEffect"'));
    });

    test('deck without animations has no p:timing rác', () async {
      final parts = await generateParts([
        {'title': 'S1', 'htmlContent': '<h1>Hi</h1>', 'effect': 'fade'},
      ]);
      final slideXml = parts['ppt/slides/slide1.xml'] ?? '';
      expect(slideXml, isNot(contains('<p:animEffect')));
    });
  });
}

// ---- Track 33: new transitions (ISO + p14) + duration + sound ----------

void transitionTrack33Tests() {
  group('Track 33 — new transitions export', () {
    Future<String> slideXmlFor(SlideEffect effect) async {
      final parts = await generateParts([
        {'title': 'S1', 'htmlContent': '<h1>Hi</h1>', 'effect': effect.name},
      ]);
      return parts['ppt/slides/slide1.xml'] ?? '';
    }

    test('dissolve maps to ISO p:dissolve', () async {
      final xml = await slideXmlFor(SlideEffect.dissolve);
      expect(xml, contains('<p:dissolve/>'));
    });

    test('cover maps with direction subtype', () async {
      final xml = await slideXmlFor(SlideEffect.coverLeft);
      expect(xml, contains('<p:cover dir="l"/>'));
    });

    test('diamond/wedge/newsflash are ISO transitions', () async {
      expect(await slideXmlFor(SlideEffect.diamond), contains('<p:diamond/>'));
      expect(await slideXmlFor(SlideEffect.wedge), contains('<p:wedge/>'));
      expect(await slideXmlFor(SlideEffect.newsflash), contains('<p:newsflash/>'));
    });

    test('p14-only effects declare the p14 namespace', () async {
      for (final e in [
        SlideEffect.curtain,
        SlideEffect.ferris,
        SlideEffect.flip,
        SlideEffect.gallery,
        SlideEffect.honeycomb,
        SlideEffect.invert,
        SlideEffect.orbit,
        SlideEffect.pageCurl,
        SlideEffect.ripple,
        SlideEffect.shred,
        SlideEffect.vortex,
        SlideEffect.origami,
        SlideEffect.reveal,
      ]) {
        final xml = await slideXmlFor(e);
        expect(xml, contains('xmlns:p14='),
            reason: '${e.name} must declare p14');
        expect(xml, contains('<p14:${e.name}/>'));
      }
    });

    test('cedar falls back to fade with a warning', () async {
      PPTGenerator.transitionWarnings.clear();
      final xml = await slideXmlFor(SlideEffect.cedar);
      expect(xml, contains('<p:fade/>'));
      expect(PPTGenerator.transitionWarnings, isNotEmpty);
      expect(PPTGenerator.transitionWarnings.single, contains('Cedar'));
    });

    test('legacy effects keep their type/subtype (regression)', () async {
      expect(await slideXmlFor(SlideEffect.pushRight), contains('<p:push dir="r"/>'));
      expect(await slideXmlFor(SlideEffect.splitIn), contains('<p:split dir="in"/>'));
      expect(await slideXmlFor(SlideEffect.clock), contains('<p:wheel/>'));
    });
  });

  group('Track 33 — duration & auto-advance', () {
    test('per-slide duration changes spd bucket', () async {
      final parts = await generateParts([
        {
          'title': 'S1',
          'htmlContent': '<h1>Hi</h1>',
          'effect': 'fade',
          'transitionDurationMs': 2500,
        },
      ]);
      final xml = parts['ppt/slides/slide1.xml'] ?? '';
      expect(xml, contains('spd="slow"'));
    });

    test('per-slide auto-advance overrides deck-wide', () async {
      final parts = await generateParts([
        {
          'title': 'S1',
          'htmlContent': '<h1>Hi</h1>',
          'effect': 'fade',
          'autoAdvanceMs': 1500,
        },
      ]);
      final xml = parts['ppt/slides/slide1.xml'] ?? '';
      expect(xml, contains('advTm="1500"'));
    });
  });
}
