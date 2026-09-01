import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/docx_report_service.dart';
import 'package:xml/xml.dart';

/// Track 03 (N1) — DOCX report: package structure, Vietnamese/escaping
/// correctness, long-notes + 100-slide robustness and option toggling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> slide(String title, String html,
          {String notes = '', int outlineLevel = 1}) =>
      {
        'title': title,
        'htmlContent': html,
        'notes': notes,
        'outlineLevel': outlineLevel,
      };

  List<String> wTexts(Archive decoded) {
    final doc = decoded.files.firstWhere((f) => f.name == 'word/document.xml');
    final xml = XmlDocument.parse(
        utf8.decode(doc.content as List<int>));
    return [
      for (final t in xml.findAllElements('w:t')) t.innerText.trim(),
    ];
  }

  test('package structure round-trip: parts + content-types + rels',
      () {
    final bytes = DocxReportService.buildDocx([
      slide('Slide A', '<h1>A</h1><p>Body text</p>', notes: 'Note A'),
    ], includeSlideList: false);

    final decoded = ZipDecoder().decodeBytes(bytes);
    final names = decoded.files.map((f) => f.name).toSet();
    expect(names, containsAll([
      '[Content_Types].xml',
      '_rels/.rels',
      'word/document.xml',
      'docProps/core.xml',
    ]));

    // Every XML part parses.
    for (final f in decoded.files) {
      if (f.name.endsWith('.xml') || f.name.endsWith('.rels')) {
        XmlDocument.parse(utf8.decode(f.content as List<int>));
      }
    }

    // Content-types covers document.xml.
    final ct = XmlDocument.parse(String.fromCharCodes(decoded
        .files
        .firstWhere((f) => f.name == '[Content_Types].xml')
        .content as List<int>));
    final overrides = [
      for (final o in ct.findAllElements('Override')) o.getAttribute('PartName')
    ];
    expect(overrides, contains('/word/document.xml'));

    // Root rels target resolves.
    final rels = XmlDocument.parse(String.fromCharCodes(decoded
        .files
        .firstWhere((f) => f.name == '_rels/.rels')
        .content as List<int>));
    final targets = [
      for (final r in rels.findAllElements('Relationship'))
        r.getAttribute('Target')
    ];
    expect(targets, contains('word/document.xml'));
  });

  test('content: outline order, notes, and slide list toggles', () {
    final slides = [
      slide('Slide A', '<h1>A</h1><p>Body A</p>', notes: 'Note A'),
      slide('Slide B', '<ul><li>Item B1</li></ul>', notes: 'Note B'),
    ];

    final withList = DocxReportService.buildDocx(slides);
    final texts = wTexts(ZipDecoder().decodeBytes(withList));
    expect(texts.first, 'Slide A'); // document title from first slide.
    expect(texts, contains('Slide A'));
    expect(texts, contains('Body A'));
    expect(texts, contains('Note A'));
    expect(texts, contains('Item B1'));
    expect(texts, contains('1. Slide A'));
    expect(texts, contains('2. Slide B'));

    final noList = DocxReportService.buildDocx(slides, includeSlideList: false);
    final textsNoList = wTexts(ZipDecoder().decodeBytes(noList));
    expect(textsNoList, isNot(contains('1. Slide A')));

    final noNotes = DocxReportService.buildDocx(slides, includeNotes: false);
    final textsNoNotes = wTexts(ZipDecoder().decodeBytes(noNotes));
    expect(textsNoNotes, isNot(contains('Note A')));
  });

  test('Vietnamese + XML escaping survive the round-trip exactly', () {
    final tricky = slide(
      'Tiêu đề & <kèm> "dấu" phẩy\'',
      '<p>Ă ă Â â Ê ê Ô ô Ơ ơ Ư ư — đầy đủ dấu tiếng Việt</p>',
      notes: 'Ghi chú với & < >> &amp; không ý nghĩa XML',
    );
    final decoded =
        ZipDecoder().decodeBytes(DocxReportService.buildDocx([tricky]));
    final texts = wTexts(decoded);
    expect(texts.first, 'Tiêu đề & <kèm> "dấu" phẩy\'');
    expect(texts, contains('Ă ă Â â Ê ê Ô ô Ơ ơ Ư ư — đầy đủ dấu tiếng Việt'));
    expect(texts, contains('Ghi chú với & < >> &amp; không ý nghĩa XML'));
  });

  test('100 slides with long notes: well-formed, no throw', () {
    final longNotes = 'Ghi chú dài ${'nội dung giảng giải. ' * 500}';
    final slides = [
      for (var i = 0; i < 100; i++)
        slide('Slide $i', '<p>Nội dung slide $i dài dòng lặp lại lần nữa</p>',
            notes: '$longNotes $i'),
    ];
    final decoded = ZipDecoder().decodeBytes(DocxReportService.buildDocx(slides));
    final texts = wTexts(decoded);
    expect(texts, contains('Slide 0'));
    expect(texts, contains('Slide 99'));
    expect(texts, contains('1. Slide 0'));
    expect(texts, contains('100. Slide 99'));
  });

  test('empty deck is rejected, not silently exported', () {
    expect(() => DocxReportService.buildDocx([]),
        throwsA(isA<ArgumentError>()));
  });

  test('exportReport writes the file and returns the path', () async {
    final tmp = await Directory.systemTemp.createTemp('docx_export');
    addTearDown(() => tmp.delete(recursive: true));
    final out = '${tmp.path}/nested/report.docx';
    final path = await DocxReportService.exportReport(
      [slide('Xuất file', '<p>Nội dung</p>')],
      out,
    );
    expect(path, out);
    expect(File(out).existsSync(), isTrue);
    expect(ZipDecoder().decodeBytes(File(out).readAsBytesSync()).files,
        isNotEmpty);
  });

  test('probe file for the real-Word COM open (GHITA_DOCX_PROBE=1)', () {
    if (Platform.environment['GHITA_DOCX_PROBE'] != '1') return;
    final bytes = DocxReportService.buildDocx([
      slide('Báo cáo demo', '<p>Nội dung báo cáo tiếng Việt</p>',
          notes: 'Đây là ghi chú trình bày của slide demo.'),
      slide('Phần hai', '<ul><li>Mục 1</li><li>Mục 2</li></ul>'),
    ]);
    final file = File('build/t03_docx_probe.docx');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    expect(file.existsSync(), isTrue);
  });
}
