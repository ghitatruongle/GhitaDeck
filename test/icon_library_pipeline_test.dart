import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/icon_item.dart';
import 'package:ghita_ppt_converter/services/icon_library_service.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 15 tests — Icon Library (FEAT 11).
///
///  * IconItem round-trip + markup/replace helpers (P2),
///  * PPTX package: icon rendered to PNG under ppt/media/ + image rel + a
///    `<p:pic>` shape carrying the raster (P3),
///  * HTML deck: `<span data-icon>` replaced with inline SVG keeping the
///    data-icon attribute (P4), PDF renders the icon PNG (P4),
///  * empty/deck-without-icons regression (P10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String iconSpan(IconItem icon) =>
      '<span data-icon=\'${icon.toJson().replaceAll("'", '&#39;')}\'></span>';

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t15_');
    try {
      await PPTGenerator.generatePPT(
        [
          {'title': 'Icons', 'htmlContent': htmlContent},
        ],
        '${dir.path}/out.pptx',
      );
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  group('icon model + service (P2)', () {
    test('IconItem round-trips through JSON', () {
      const icon = IconItem(
        name: 'Home',
        category: 'UI',
        svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',
        color: '#FF0000',
        size: 48,
      );
      final restored = IconItem.fromJson(icon.toJson());
      expect(restored.name, 'Home');
      expect(restored.color, '#FF0000');
      expect(restored.size, 48);
      expect(restored.svgPath, icon.svgPath);
    });

    test('svgMarkup produces valid SVG with chosen colour/size', () {
      const icon = IconItem(
        name: 'Home',
        category: 'UI',
        svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',
        color: '#3A8FD4',
        size: 32,
      );
      final svg = icon.svgMarkup;
      expect(svg, contains('<svg'));
      expect(svg, contains('width="32"'));
      expect(svg, contains('fill="#3A8FD4"'));
      expect(svg, contains('d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"'));
    });

    test('iconCount / iconsIn / replaceIconAt work on slide HTML', () {
      const icon = IconItem(name: 'Home', category: 'UI', svgPath: 'M10 20z');
      const icon2 = IconItem(name: 'Add', category: 'UI', svgPath: 'M19 13z');
      final html = '${iconSpan(icon)}\n<p>Hello</p>\n${iconSpan(icon2)}';
      expect(IconLibraryService.iconCount(html), 2);
      final icons = IconLibraryService.iconsIn(html);
      expect(icons.length, 2);
      expect(icons[0].name, 'Home');
      expect(icons[1].name, 'Add');
      final replaced = IconLibraryService.replaceIconAt(html, 0, icon2);
      expect(IconLibraryService.iconsIn(replaced).first.name, 'Add');
      // Out-of-range index leaves the HTML untouched.
      expect(IconLibraryService.replaceIconAt(html, 5, icon2), html);
    });

    test('renderPng produces a non-empty PNG', () {
      const icon = IconItem(name: 'Star', category: 'Status', svgPath: 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z');
      final png = IconLibraryService.renderPng(icon, size: 48);
      expect(png, isNotEmpty);
      expect(png.length, greaterThan(100));
      // PNG magic bytes.
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    });
  });

  group('PPTX export (P3)', () {
    test('icon block becomes a <p:pic> with a PNG media part', () async {
      const icon = IconItem(name: 'Home', category: 'UI', svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z', color: '#3A8FD4');
      final archive = await exportPptx('<h1>Icons</h1>${iconSpan(icon)}');

      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('<p:pic>'));
      expect(slideXml, contains('name="Icon Home"'));
      expect(slideXml, contains('r:embed="rId'));
      expect(slideXml, contains('noChangeAspect="1"'));

      // The icon PNG media part exists under ppt/media/.
      final mediaFiles = archive.files
          .where((e) => e.name.startsWith('ppt/media/') && e.name.endsWith('.png'))
          .toList();
      expect(mediaFiles, isNotEmpty);
      final bytes = mediaFiles.first.content as List<int>;
      expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      // The slide rels declare the image relationship.
      final relsXml = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(relsXml, contains('relationships/image'));
    });

    test('same icon twice embeds only one PNG (dedupe)', () async {
      const icon = IconItem(name: 'Star', category: 'Status', svgPath: 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z');
      final archive = await exportPptx(
          '${iconSpan(icon)}\n${iconSpan(icon)}');
      final mediaFiles = archive.files
          .where((e) => e.name.startsWith('ppt/media/') && e.name.endsWith('.png'))
          .toList();
      expect(mediaFiles, hasLength(1));
    });
  });

  group('HTML export (P4)', () {
    test('icon span is replaced with inline SVG', () {
      const icon = IconItem(name: 'Home', category: 'UI', svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z', color: '#FF0000');
      final html = HtmlExportService().buildPresentationHtml(
        [
          {'title': 'Icons', 'htmlContent': '<h1>Icons</h1>${iconSpan(icon)}'},
        ],
      );
      expect(html, contains('<svg'));
      expect(html, contains('fill="#FF0000"'));
      expect(html, contains('d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"'));
      // The data-icon attribute stays for re-editing.
      expect(html, contains('data-icon'));
    });
  });

  group('PDF export (P4)', () {
    test('icon block renders as an image in the PDF', () async {
      const icon = IconItem(name: 'Home', category: 'UI', svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z');
      final dir = await Directory.systemTemp.createTemp('ghita_t15pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [
            {'title': 'Icons', 'htmlContent': iconSpan(icon)},
          ],
          path,
        );
        final pdfBytes = File(path).readAsBytesSync();
        expect(pdfBytes, isNotEmpty);
        // PDF header + contains an XObject image stream (icon rasterised).
        expect(utf8.decode(pdfBytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('regression (P10)', () {
    test('deck without icons exports unchanged', () {
      final html = HtmlExportService().buildPresentationHtml(
        [
          {'title': 'Plain', 'htmlContent': '<h1>Hello</h1><p>World</p>'},
        ],
      );
      expect(html, contains('<h1>Hello</h1>'));
      expect(html, isNot(contains('data-icon')));
    });

    test('empty icon payload is skipped in PPTX', () async {
      final archive = await exportPptx('<p>No icons</p>');
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, isNot(contains('Icon ')));
    });
  });
}
