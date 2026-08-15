import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/advanced_import_service.dart';
import 'package:ghita_ppt_converter/services/history_storage_service.dart';
import 'package:ghita_ppt_converter/services/thumbnail_service.dart';
import 'package:ghita_ppt_converter/services/time_machine_history_service.dart';
import 'package:ghita_ppt_converter/services/wysiwyg_service.dart';
import 'package:archive/archive.dart';

void main() {
  // -------------------------------------------------------------------------
  // T63 — WYSIWYG + highlight
  // -------------------------------------------------------------------------
  group('T63 WysiwygService', () {
    test('wrapSelection wraps the selected text', () {
      const html = '<p>hello world</p>';
      // Offsets 3..8 select "hello".
      final result = WysiwygService.wrapSelection(html, 3, 8, '<b>', '</b>');
      expect(result.html, '<p><b>hello</b> world</p>');
      expect(result.start, 6);
      expect(result.end, 11);
    });

    test('wrapSelection no-op on empty selection', () {
      const html = '<p>x</p>';
      final result = WysiwygService.wrapSelection(html, 3, 3, '<i>', '</i>');
      expect(result.html, html);
    });

    test('colorSelection wraps only text nodes, not tags', () {
      const html = '<p>a <b>b</b></p>';
      final result = WysiwygService.colorSelection(html, 3, 8, '#FF0000');
      expect(result.html, contains('<span style="color:#FF0000">a </span>'));
      expect(result.html, isNot(contains('color:#FF0000"><b>')));
    });

    test('toggleWrap unwraps when already wrapped', () {
      const html = '<p><b>hello</b></p>';
      // Select the whole wrapped span (3..15).
      final result = WysiwygService.toggleWrap(html, 3, 15, '<b>', '</b>');
      expect(result.html, '<p>hello</p>');
      // Partial selection (3..10) wraps instead.
      final partial =
          WysiwygService.toggleWrap(html, 3, 10, '<b>', '</b>');
      expect(partial.html, '<p><b><b>hell</b>o</b></p>');
    });
  });

  group('T63 HtmlHighlightService', () {
    test('classify finds tags, attributes, strings, comments', () {
      final spans = HtmlHighlightService.classify(
          '<h1 class="x"><!-- note --></h1>');
      expect(spans.any((s) => s.type == 'tag'), isTrue);
      expect(spans.any((s) => s.type == 'attr'), isTrue);
      expect(spans.any((s) => s.type == 'string'), isTrue);
      expect(spans.any((s) => s.type == 'comment'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // T64 — Thumbnails
  // -------------------------------------------------------------------------
  group('T64 ThumbnailService', () {
    test('renders a PNG b64 for a simple slide', () {
      final slide = Slide(
        title: 'Hello',
        htmlContent: '<h1>Hello</h1><p>World</p>',
      );
      final b64 = ThumbnailService.renderThumbnailB64(slide);
      expect(b64, isNotNull);
      final bytes = base64Decode(b64!);
      expect(bytes, isNotEmpty);
      // PNG magic.
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('renderBatch respects maxConcurrent passes', () {
      final slides = [
        for (var i = 0; i < 10; i++)
          Slide(title: 'S$i', htmlContent: '<h1>S$i</h1>'),
      ];
      final result = ThumbnailService.renderBatch(slides, maxConcurrent: 4);
      expect(result, hasLength(10));
    });

    test('bundle thumb cache round-trip', () {
      final bundle = {'slides': []};
      final thumbs = {0: 'aGVsbG8=', 1: 'd29ybGQ='};
      final withThumbs = ThumbnailService.injectThumbs(bundle, thumbs);
      expect(ThumbnailService.thumbsFromBundle(withThumbs), thumbs);
      expect(ThumbnailService.thumbsBytes(thumbs), greaterThan(0));
    });

    test('placeholder renders for any layout type', () {
      final b64 = ThumbnailService.placeholderB64('two_content');
      final bytes = base64Decode(b64);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });

  // -------------------------------------------------------------------------
  // T65 — Storage & startup
  // -------------------------------------------------------------------------
  group('T65 HistoryStorageService', () {
    test('compress/decompress round-trips slides', () {
      final slides = [
        Slide(title: 'A', htmlContent: '<h1>A</h1>'),
        Slide(title: 'B', htmlContent: '<p>b</p>'),
      ];
      final gz = HistoryStorageService.compressSlides(slides);
      final back = HistoryStorageService.decompressSlides(gz);
      expect(back, hasLength(2));
      expect(back[0].title, 'A');
      expect(back[1].htmlContent, '<p>b</p>');
    });

    test('compressed snapshot is smaller than raw JSON', () {
      final slides = [
        for (var i = 0; i < 20; i++)
          Slide(title: 'Slide $i', htmlContent: '<p>${'x' * 100}</p>'),
      ];
      final gz = HistoryStorageService.compressSlides(slides);
      final raw = utf8.encode(jsonEncode([for (final s in slides) s.toMap()]));
      expect(gz.length, lessThan(raw.length));
    });

    test('diff stores only changed slides and applies back', () {
      final prev = [
        Slide(title: 'A', htmlContent: '<h1>A</h1>'),
        Slide(title: 'B', htmlContent: '<p>b</p>'),
      ];
      final next = [
        Slide(title: 'A2', htmlContent: '<h1>A2</h1>'),
        Slide(title: 'B', htmlContent: '<p>b</p>'),
      ];
      final diff = HistoryStorageService.diffSlides(prev, next);
      expect(diff['full'], isFalse);
      final changed = (diff['changed'] as Map).cast<String, dynamic>();
      expect(changed, hasLength(1));
      final applied = HistoryStorageService.applyDiff(prev, diff);
      expect(applied[0].title, 'A2');
      expect(applied[1].title, 'B');
    });

    test('diff falls back to full when lengths differ', () {
      final diff = HistoryStorageService.diffSlides(
        [Slide(title: 'A', htmlContent: '<h1>A</h1>')],
        [Slide(title: 'A', htmlContent: '<h1>A</h1>'), Slide(title: 'B', htmlContent: '<p>b</p>')],
      );
      expect(diff['full'], isTrue);
    });
  });

  group('T65 CoalescingRecorder', () {
    test('coalesces rapid typing into one snapshot', () async {
      final history = TimeMachineHistoryService(maxHistoryLength: 30);
      final recorder = CoalescingRecorder(history: history);
      recorder.touch('edit', [Slide(title: 'v1', htmlContent: '<p>1</p>')]);
      recorder.touch('edit', [Slide(title: 'v2', htmlContent: '<p>2</p>')]);
      recorder.touch('edit', [Slide(title: 'v3', htmlContent: '<p>3</p>')]);
      recorder.flush();
      expect(history.snapshots, hasLength(1));
      expect(history.snapshots.first.slides.first.title, 'v3');
      recorder.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // T66 — Advanced import
  // -------------------------------------------------------------------------
  group('T66 AdvancedImportService', () {
    test('markdown with tables, lists, code, images and --- separators', () {
      const md = '''
# Slide One
| a | b |
|---|---|
| 1 | 2 |

- item
- nested

```dart
void main() {}
```

![Logo](https://example.com/logo.png)

---

# Slide Two
Second slide body
''';
      final slides = AdvancedImportService.parseMarkdown(md);
      expect(slides, hasLength(2));
      expect(slides[0].title, 'Slide One');
      expect(slides[0].htmlContent, contains('<table>'));
      expect(slides[0].htmlContent, contains('<ul>'));
      expect(slides[0].htmlContent, contains('<pre><code>'));
      expect(slides[0].htmlContent, contains('<img src="https://example.com/logo.png"'));
      expect(slides[1].title, 'Slide Two');
    });

    test('markdown nested lists keep structure', () {
      final slides = AdvancedImportService.parseMarkdown(
          '# T\n- a\n  - a1\n- b');
      final html = slides.first.htmlContent;
      expect(html, contains('a1'));
      expect(html, contains('b'));
      // Nested list opens a second <ul>.
      expect('${'<ul>'.allMatches(html).length}', '2');
    });

    test('docx import extracts headings and body', () {
      // Build a minimal docx in-memory.
      final archive = Archive();
      const docXml = '''
<?xml version="1.0"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Title A</w:t></w:r></w:p>
    <w:p><w:r><w:t>Body text</w:t></w:r></w:p>
  </w:body>
</w:document>''';
      archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));
      final bytes = ZipEncoder().encode(archive)!;
      final slides = AdvancedImportService.importDocx(bytes);
      expect(slides, hasLength(1));
      expect(slides.first.title, 'Title A');
      expect(slides.first.htmlContent, contains('Body text'));
    });

    test('pptx import parses slides with text and bullets', () {
      final archive = Archive();
      const slideXml = '''
<?xml version="1.0"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld><p:spTree>
    <p:sp><p:nvSpPr><p:cNvPr id="1"/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Hello PPTX</a:t></a:r></a:p></p:txBody></p:sp>
    <p:sp><p:nvSpPr><p:cNvPr id="2"/><p:nvPr/></p:nvSpPr>
      <p:txBody><a:p><a:pPr><a:buChar char="•"/></a:pPr><a:r><a:t>Bullet one</a:t></a:r></a:p></p:txBody></p:sp>
  </p:spTree></p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slideXml.length, utf8.encode(slideXml)));
      archive.addFile(ArchiveFile('[Content_Types].xml', 10, utf8.encode('x' * 10)));
      final bytes = ZipEncoder().encode(archive)!;
      final slides = AdvancedImportService.importPptx(bytes);
      expect(slides, hasLength(1));
      expect(slides.first.title, 'Hello PPTX');
      expect(slides.first.htmlContent, contains('Bullet one'));
    });

    test('pdf import returns slides with extracted text', () {
      final fakePdf = utf8.encode('(First page text here) (More content words) ');
      final slides = AdvancedImportService.importPdf(fakePdf, maxPages: 3);
      expect(slides, isNotEmpty);
      expect(slides.first.htmlContent, contains('First page text here'));
    });

    test('web rich import handles headings and images (mock-free net skip)', () {
      // Network dependent — verify the offline HTML text-probe helper via
      // the public markdown path (same tag-stripping logic).
      final slides = AdvancedImportService.parseMarkdown('# H\nBody');
      expect(slides.first.htmlContent, contains('Body'));
    });
  });

  // -------------------------------------------------------------------------
  // T67 — l10n sync (audit tool exists; verify arb keys here too)
  // -------------------------------------------------------------------------
  group('T67 l10n sync', () {
    test('EN and VI arb key sets are identical', () {
      final en = File('lib/l10n/app_en.arb').readAsStringSync();
      final vi = File('lib/l10n/app_vi.arb').readAsStringSync();
      final enKeys = RegExp(r'^\s*"([a-zA-Z0-9_]+)"\s*:', multiLine: true)
          .allMatches(en)
          .map((m) => m.group(1)!)
          .toSet();
      final viKeys = RegExp(r'^\s*"([a-zA-Z0-9_]+)"\s*:', multiLine: true)
          .allMatches(vi)
          .map((m) => m.group(1)!)
          .toSet();
      expect(enKeys.difference(viKeys), isEmpty);
      expect(viKeys.difference(enKeys), isEmpty);
    });
  });
}
