import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/export_options.dart';
import 'package:ghita_deck/services/pdf_export_service.dart';

const String kOnePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  final tmpDir = Directory.systemTemp.path;
  final service = PdfExportService();

  group('PdfExportService', () {
    test('throws on empty slides', () async {
      expect(
        () => service.exportToPdf([], '$tmpDir/empty.pdf'),
        throwsA(isA<Exception>()),
      );
    });

    test('creates a valid PDF with one page per slide', () async {
      final path = '$tmpDir/test_export.pdf';
      final slides = [
        {'title': 'Slide 1', 'htmlContent': '<p>Hello</p>'},
        {'title': 'Slide 2', 'htmlContent': '<ul><li>A</li><li>B</li></ul>'},
        {'title': 'Slide 3', 'htmlContent': '<p><b>Bold</b> text</p>'},
      ];

      final exported = await service.exportToPdf(slides, path);
      final file = File(exported);
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true),
          startsWith('%PDF'));

      // Page objects are written uncompressed by the pdf package.
      final content = latin1.decode(bytes);
      final pageMatches =
          RegExp(r'/Type\s*/Page[^s]').allMatches(content).length;
      expect(pageMatches, slides.length);
      file.deleteSync();
    });

    test('handles tables, lists, images and background color', () async {
      final path = '$tmpDir/test_export_rich.pdf';
      final slides = [
        {
          'title': 'Rich',
          'htmlContent': '<div data-bg-color="#123456">'
              '<table><tr><th>H</th></tr><tr><td>C</td></tr></table>'
              '<ol><li>One</li></ol>'
              '<img src="data:image/png;base64,$kOnePixelPngBase64">'
              '</div>',
        },
      ];

      final exported = await service.exportToPdf(slides, path);
      final file = File(exported);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      file.deleteSync();
    });

    test('supports 4:3 page format', () async {
      final path = '$tmpDir/test_export_43.pdf';
      final slides = [
        {'title': 'Classic', 'htmlContent': '<p>4:3</p>'},
      ];
      final exported =
          await service.exportToPdf(slides, path, widescreen: false);
      expect(File(exported).existsSync(), isTrue);
      File(exported).deleteSync();
    });

    test('supports square and portrait advanced dimensions with notes',
        () async {
      final path = '$tmpDir/test_export_portrait.pdf';
      final exported = await service.exportToPdf(
        [
          {
            'title': 'Portrait',
            'notes': 'Speaker note',
            'htmlContent': '<div data-bg-color="#123456"><p>Content</p></div>',
          }
        ],
        path,
        aspectRatio: ExportAspectRatio.portrait9x16,
        includeNotes: true,
        includeBackgrounds: false,
        imageMaxWidth: ExportQuality.low.imageMaxWidth,
      );
      final content = latin1.decode(File(exported).readAsBytesSync());

      expect(
        RegExp(r'/MediaBox\s*\[\s*0\s+0\s+405(?:\.0+)?\s+720')
            .hasMatch(content),
        isTrue,
      );
      File(exported).deleteSync();
    });

    test('loads a Unicode system font theme on Windows', () async {
      final theme = await PdfExportService.loadSystemTheme();
      if (Platform.isWindows) {
        expect(theme, isNotNull,
            reason: 'Segoe UI/Arial/Tahoma should exist on Windows');
      }
    }, testOn: 'windows');

    test('renders Vietnamese text with embedded TrueType font', () async {
      final path = '$tmpDir/test_export_vi.pdf';
      final slides = [
        {
          'title': 'Xin chào Việt Nam — báo cáo quý',
          'htmlContent': '<p>Nội dung <b>đậm</b> và <i>nghiêng</i> '
              'với đầy đủ dấu tiếng Việt: ăâêôơưđ</p>'
              '<ul><li>Gạch đầu dòng tiếng Việt</li></ul>',
        },
      ];
      final exported = await service.exportToPdf(slides, path);
      final file = File(exported);
      expect(file.existsSync(), isTrue);
      // An embedded TrueType program must be present (the pdf package
      // writes Unicode TTFs as Type0/CIDFontType2 with a FontFile2 stream;
      // the default Helvetica is Type1 and cannot encode Vietnamese).
      final content = latin1.decode(file.readAsBytesSync());
      expect(
        content.contains('/FontFile2') || content.contains('/CIDFontType2'),
        isTrue,
        reason: 'PDF must embed a TrueType font program for Vietnamese text',
      );
      file.deleteSync();
    }, testOn: 'windows');
  });
}
