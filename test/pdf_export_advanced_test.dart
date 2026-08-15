import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/export_options.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:image/image.dart' as img;

/// Concatenate the raw PDF text with every (inflated) stream so assertions
/// can search dictionaries that live inside compressed object streams.
String pdfText(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  final buf = StringBuffer(text);
  for (final m in RegExp(r'stream\r?\n').allMatches(text)) {
    final end = text.indexOf('endstream', m.end);
    if (end < 0) continue;
    var start = m.end;
    while (start < end && (bytes[start] == 0x0D || bytes[start] == 0x0A)) {
      start++;
    }
    try {
      final inflated = const ZLibDecoder().decodeBytes(bytes.sublist(start, end));
      buf
        ..write('\n')
        ..write(String.fromCharCodes(inflated));
    } catch (_) {
      // Not a deflate stream — skip.
    }
  }
  return buf.toString();
}

/// Track 06 tests — advanced PDF export.
///
///  * page size options (A4/Letter) produce the right MediaBox while the
///    default keeps the v1.6.3 slide-sized pages,
///  * fonts are embedded as glyph subsets, so Vietnamese renders on machines
///    without Segoe UI (embedded font data < the full font file),
///  * image quality settings shrink the PDF (JPEG re-encode),
///  * hidden slides are excluded unless explicitly included,
///  * document metadata (title/author/creation date) is written.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dir = Directory.systemTemp.createTempSync('ghita_t06_');

  tearDownAll(() => dir.deleteSync(recursive: true));

  List<Map<String, dynamic>> deck({bool withImage = false}) {
    final pngBytes = Uint8List.fromList(img.encodePng(img.Image(
      width: 600,
      height: 400,
      numChannels: 3,
    )));
    return [
      {
        'title': 'Deck ABC',
        'htmlContent': '<h2>Phụ đề</h2><p>Tiếng Việt có dấu: '
            'Đà Nẵng, Quảng Ninh, Hà Nội, Thành phố Hồ Chí Minh.</p>'
            '${withImage ? '<img src="data:image/png;base64,${base64Encode(pngBytes)}">' : ''}',
      }
    ];
  }

  RegExp mediaBox() => RegExp(
      r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]');

  Future<Uint8List> exportPdf(
    List<Map<String, dynamic>> slides, {
    PdfPaperSize paperSize = PdfPaperSize.matchSlide,
    PdfMarginPreset margins = PdfMarginPreset.standard,
    bool scaleToFit = true,
    bool includeHiddenSlides = false,
    int? imageMaxWidth,
  }) async {
    final out = '${dir.path}/out.pdf';
    await PdfExportService().exportToPdf(
      slides,
      out,
      includeNotes: true,
      imageMaxWidth: imageMaxWidth,
      paperSize: paperSize,
      marginPreset: margins,
      scaleToFit: scaleToFit,
      includeHiddenSlides: includeHiddenSlides,
    );
    return File(out).readAsBytesSync();
  }

  test('default export keeps the v1.6.3 slide-sized pages (P10)', () async {
    final bytes = await exportPdf(deck());
    final match = mediaBox().firstMatch(String.fromCharCodes(bytes));
    expect(match, isNotNull);
    final w = double.parse(match!.group(1)!);
    final h = double.parse(match.group(2)!);
    // 16:9 slide: 13.3333in × 72 = 960 × 540 pt.
    expect(w, closeTo(960, 0.5));
    expect(h, closeTo(540, 0.5));
  });

  test('A4 and Letter produce the correct page sizes (P2)', () async {
    final a4 = await exportPdf(deck(), paperSize: PdfPaperSize.a4);
    final a4Box = mediaBox().firstMatch(String.fromCharCodes(a4))!;
    expect(double.parse(a4Box.group(1)!), closeTo(842, 0.5));
    expect(double.parse(a4Box.group(2)!), closeTo(595, 0.5));

    final letter =
        await exportPdf(deck(), paperSize: PdfPaperSize.letter);
    final letterBox = mediaBox().firstMatch(String.fromCharCodes(letter))!;
    expect(double.parse(letterBox.group(1)!), closeTo(792, 0.5));
    expect(double.parse(letterBox.group(2)!), closeTo(612, 0.5));
  });

  test('fonts embed as glyph subsets — Vietnamese survives elsewhere (P4/P8)',
      () async {
    final bytes = await exportPdf(deck());
    final text = pdfText(bytes);
    // Embedded font programs are present…
    expect(text, contains('/FontFile2'));
    // …and smaller than the full Segoe UI file — proof of subsetting, so a
    // machine without Segoe UI still renders the Vietnamese text correctly.
    final fullFont = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (fullFont.existsSync()) {
      expect(bytes.length, lessThan(fullFont.lengthSync()),
          reason: 'a subset embedding must be smaller than the full font');
    }
    expect(bytes.length, greaterThan(1000));
  });

  test('image quality compresses the PDF (P5)', () async {
    final low = await exportPdf(deck(withImage: true), imageMaxWidth: 150);
    final high = await exportPdf(deck(withImage: true), imageMaxWidth: 600);
    expect(low.length, lessThan(high.length),
        reason: 'low-quality images must produce a smaller PDF');
    // The 600 px image stays above the PNG→JPEG threshold, so the
    // high-quality export embeds it as JPEG.
    expect(pdfText(high), contains('/DCTDecode'));
    // The 150 px image is downscaled below the threshold — still a PNG.
    expect(pdfText(low), isNot(contains('/DCTDecode')));
  });

  test('hidden slides are skipped unless explicitly included (P6)', () async {
    final slides = [
      {'title': 'A', 'htmlContent': '<p>Một</p>'},
      {'title': 'B', 'htmlContent': '<p>Hai</p>', 'hidden': true},
      {'title': 'C', 'htmlContent': '<p>Ba</p>'},
    ];
    final excluded = await exportPdf(slides);
    final included = await exportPdf(slides, includeHiddenSlides: true);

    int pages(Uint8List bytes) => RegExp(r'/Type\s*/Page[^s]')
        .allMatches(String.fromCharCodes(bytes))
        .length;
    expect(pages(excluded), 2);
    expect(pages(included), 3);
  });

  test('document metadata is written (P7)', () async {
    final bytes = await exportPdf(deck());
    final text = pdfText(bytes);
    // The pdf package writes the Info dict compactly: /Key(value).
    expect(text, contains('/Title(Deck ABC)'));
    expect(text, contains('/Author(Ghita PPT Converter)'));
    expect(text, contains('/Creator(Ghita PPT Converter)'));
    expect(text, contains('/CreationDate(D:'));
  });

  test('Slide.hidden round-trips through save/load', () {
    final slide = Slide(
      title: 'Ẩn',
      htmlContent: '<p>x</p>',
      hidden: true,
    );
    expect(slide.toMap()['hidden'], true);
    expect(Slide.fromMap(slide.toMap()).hidden, isTrue);
    // Default: not hidden (legacy decks stay visible).
    expect(Slide.fromMap({'title': 't', 'htmlContent': '<p>y</p>'}).hidden,
        isFalse);
  });
}