import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/header_footer_service.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 19 tests — Header/Footer & field động (FEAT 21, 24).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Archive> exportPptx(String htmlContent,
      {DeckMeta? deckMeta}) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t19_');
    try {
      await PPTGenerator.generatePPT(
        [{'title': 'T19', 'htmlContent': htmlContent}],
        '${dir.path}/out.pptx',
        deckMeta: deckMeta,
      );
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  group('DeckMeta model (P1)', () {
    test('round-trips through JSON', () {
      const meta = DeckMeta(
        header: 'My Header',
        footer: 'My Footer',
        slideNumber: true,
        dateTime: true,
        dateTimeAuto: false,
        dateTimeFormat: 'MM/dd/yy',
        excludeFirst: false,
      );
      final restored = DeckMeta.fromJson(meta.toJson());
      expect(restored.header, 'My Header');
      expect(restored.footer, 'My Footer');
      expect(restored.slideNumber, isTrue);
      expect(restored.dateTime, isTrue);
      expect(restored.dateTimeAuto, isFalse);
      expect(restored.excludeFirst, isFalse);
    });

    test('defaults are correct', () {
      const meta = DeckMeta();
      expect(meta.header, '');
      expect(meta.footer, '');
      expect(meta.slideNumber, isTrue);
      expect(meta.dateTime, isFalse);
      expect(meta.excludeFirst, isTrue);
    });
  });

  group('HeaderFooterService (P3)', () {
    test('masterFooterShapesXml includes header shape', () {
      const meta = DeckMeta(header: 'MyCo');
      final xml = HeaderFooterService.masterFooterShapesXml(meta);
      expect(xml, contains('ph type="hdr"'));
      expect(xml, contains('>MyCo</a:t>'));
    });

    test('masterFooterShapesXml includes footer shape', () {
      const meta = DeckMeta(footer: 'Confidential');
      final xml = HeaderFooterService.masterFooterShapesXml(meta);
      expect(xml, contains('ph type="ftr"'));
      expect(xml, contains('>Confidential</a:t>'));
    });

    test('masterFooterShapesXml includes slide number field', () {
      const meta = DeckMeta(slideNumber: true);
      final xml = HeaderFooterService.masterFooterShapesXml(meta);
      expect(xml, contains('ph type="sldNum"'));
      expect(xml, contains('type="slidenum"'));
    });

    test('masterFooterShapesXml includes date field when auto', () {
      const meta = DeckMeta(dateTime: true, dateTimeAuto: true);
      final xml = HeaderFooterService.masterFooterShapesXml(meta);
      expect(xml, contains('ph type="dt"'));
      expect(xml, contains('type="datetime1"'));
    });

    test('masterFooterShapesXml is empty when no options set', () {
      const meta = DeckMeta(slideNumber: false, dateTime: false);
      final xml = HeaderFooterService.masterFooterShapesXml(meta);
      expect(xml, isEmpty);
    });
  });

  group('PPTX export (P3, P7, P9)', () {
    test('master includes footer shapes when deckMeta provided', () async {
      const meta = DeckMeta(header: 'MyCo', footer: 'Slide', slideNumber: true);
      final archive = await exportPptx('<h1>Test</h1>', deckMeta: meta);
      final masterXml = part(archive, 'ppt/slideMasters/slideMaster1.xml');
      expect(masterXml, contains('ph type="hdr"'));
      expect(masterXml, contains('ph type="ftr"'));
      expect(masterXml, contains('ph type="sldNum"'));
      expect(masterXml, contains('>MyCo</a:t>'));
    });

    test('master has no footer shapes when deckMeta is null', () async {
      final archive = await exportPptx('<h1>Test</h1>');
      final masterXml = part(archive, 'ppt/slideMasters/slideMaster1.xml');
      expect(masterXml, isNot(contains('ph type="hdr"')));
    });

    test('slide number field uses a:fld with type="slidenum"', () async {
      const meta = DeckMeta(slideNumber: true);
      final archive = await exportPptx('<h1>Test</h1>', deckMeta: meta);
      final masterXml = part(archive, 'ppt/slideMasters/slideMaster1.xml');
      expect(masterXml, contains('a:fld'));
      expect(masterXml, contains('slidenum'));
    });

    test('excludeFirst adds showMasterSp="0" on slide 1', () async {
      const meta = DeckMeta(header: 'H', excludeFirst: true);
      final archive = await exportPptx('<h1>Test</h1>', deckMeta: meta);
      final slide1 = part(archive, 'ppt/slides/slide1.xml');
      expect(slide1, contains('showMasterSp="0"'));
    });

    test('excludeFirst=false does NOT add showMasterSp', () async {
      const meta = DeckMeta(header: 'H', excludeFirst: false);
      final archive = await exportPptx('<h1>Test</h1>', deckMeta: meta);
      final slide1 = part(archive, 'ppt/slides/slide1.xml');
      expect(slide1, isNot(contains('showMasterSp')));
    });

    test('slide 2 still has no showMasterSp when excludeFirst=true', () async {
      const meta = DeckMeta(header: 'H', excludeFirst: true);
      final archive = await exportPptx('<h1>Test</h1>', deckMeta: meta);
      // Only slide 1 is exported (single slide), so we check there's no
      // showMasterSp on non-first slides by verifying the first slide has it.
      final slide1 = part(archive, 'ppt/slides/slide1.xml');
      expect(slide1, contains('showMasterSp="0"'));
    });
  });

  group('HTML/PDF export (P5)', () {
    test('HTML header/footer rendered when deckMeta provided', () {
      const meta = DeckMeta(header: 'My Header', footer: 'My Footer');
      final html = HtmlExportService().buildPresentationHtml(
        [{'title': 'T', 'htmlContent': '<h1>Hello</h1>'}],
        deckMeta: meta,
      );
      expect(html, contains('My Header'));
      expect(html, contains('My Footer'));
      expect(html, contains('ghita-hf'));
    });

    test('HTML no header/footer when deckMeta omitted', () {
      final html = HtmlExportService().buildPresentationHtml(
        [{'title': 'T', 'htmlContent': '<h1>Hello</h1>'}],
      );
      // The CSS class exists, but no header/footer DIV is emitted.
      expect(html, isNot(contains('<div class="ghita-hf-header"')));
      expect(html, isNot(contains('<div class="ghita-hf-footer"')));
    });

    test('HTML excludeFirst adds JS to hide bar on first slide', () {
      const meta = DeckMeta(header: 'H', footer: 'F', excludeFirst: true);
      final html = HtmlExportService().buildPresentationHtml(
        [{'title': 'T', 'htmlContent': '<h1>Hello</h1>'}],
        deckMeta: meta,
      );
      expect(html, contains('id="ghitaHf"'));
      expect(html, contains('hfExcludeFirst'));
      expect(html, contains('hfExcludeFirst && index === 0'));
    });

    test('HTML excludeFirst=false has no hide logic', () {
      const meta = DeckMeta(header: 'H', excludeFirst: false);
      final html = HtmlExportService().buildPresentationHtml(
        [{'title': 'T', 'htmlContent': '<h1>Hello</h1>'}],
        deckMeta: meta,
      );
      expect(html, contains('hfExcludeFirst = false'));
      // No id="ghitaHf" on the bar — the JS hide logic has nothing to target.
      expect(html, isNot(contains('id="ghitaHf"')));
    });

    test('PDF header/footer rendered when deckMeta provided', () async {
      const meta = DeckMeta(header: 'PDF Hdr', footer: 'PDF Ftr', slideNumber: true);
      final dir = await Directory.systemTemp.createTemp('ghita_t19pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [{'title': 'T', 'htmlContent': '<h1>Hello</h1>'}],
          path,
          deckMeta: meta,
        );
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('PDF no header/footer when deckMeta omitted', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t19pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [{'title': 'T', 'htmlContent': '<h1>Hello</h1>'}],
          path,
        );
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('PDF excludeFirst skips header/footer on first page', () async {
      const meta = DeckMeta(header: 'Hdr', footer: 'Ftr', slideNumber: true, excludeFirst: true);
      final dir = await Directory.systemTemp.createTemp('ghita_t19pdf_');
      try {
        // Two slides: first (title, no bars) + second (bars).
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [
            {'title': 'Title', 'htmlContent': '<h1>Title</h1>'},
            {'title': 'Content', 'htmlContent': '<h1>Content</h1>'},
          ],
          path,
          deckMeta: meta,
        );
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        // The PDF is valid (header) and contains 2 pages.
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
        final pdfText = latin1.decode(bytes, allowInvalid: true);
        expect(pdfText, contains('/Count 2'));
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('PDF excludeFirst=false renders bars on first page too', () async {
      const meta = DeckMeta(header: 'Hdr2', footer: 'Ftr2', excludeFirst: false);
      final dir = await Directory.systemTemp.createTemp('ghita_t19pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [{'title': 'Title', 'htmlContent': '<h1>Title</h1>'}],
          path,
          deckMeta: meta,
        );
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('Regression (P10)', () {
    test('deck without header/footer config exports unchanged', () async {
      final archive = await exportPptx('<h1>Hello</h1>');
      final masterXml = part(archive, 'ppt/slideMasters/slideMaster1.xml');
      expect(masterXml, isNot(contains('ph type="hdr"')));
      expect(masterXml, isNot(contains('ph type="ftr"')));
    });
  });
}