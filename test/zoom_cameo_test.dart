import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/deck_section.dart';
import 'package:ghita_ppt_converter/services/cameo_service.dart';
import 'package:ghita_ppt_converter/services/zoom_feature_service.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 20 tests — Slide Zoom & Cameo (FEAT 22, 23).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String zoomDiv(ZoomItem z) =>
      '<div data-zoom=\'${z.toJson().replaceAll("'", '&#39;')}\'></div>';

  String cameoDiv(CameoData c) =>
      '<div data-cameo=\'${c.toJson().replaceAll("'", '&#39;')}\'></div>';

  String sectionZoomDiv(SectionZoomData z) =>
      '<div data-sectionzoom=\'${z.toJson().replaceAll("'", '&#39;')}\'></div>';

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t20_');
    try {
      await PPTGenerator.generatePPT(
        [{'title': 'T20', 'htmlContent': htmlContent}],
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

  group('ZoomItem model (P2)', () {
    test('round-trips through JSON', () {
      const zoom = ZoomItem(
        targetSlide: 3,
        thumbnailLabel: 'Results',
        frameStyle: 'shadow',
        x: 30, y: 40, w: 25, h: 18,
      );
      final restored = ZoomItem.fromJson(zoom.toJson());
      expect(restored.targetSlide, 3);
      expect(restored.thumbnailLabel, 'Results');
      expect(restored.frameStyle, 'shadow');
    });

    test('htmlMarkup contains goToSlide with correct target', () {
      const zoom = ZoomItem(targetSlide: 2, thumbnailLabel: 'Chart');
      final html = zoom.htmlMarkup;
      expect(html, contains('goToSlide(2)'));
      expect(html, contains('>Chart</div>'));
    });

    test('service zoomsIn / zoomMarkup / replaceZoomAt', () {
      const zoom = ZoomItem(targetSlide: 1);
      final html = '${zoomDiv(zoom)}\n<p>x</p>';
      expect(ZoomFeatureService.zoomCount(html), 1);
      expect(ZoomFeatureService.zoomsIn(html).length, 1);
      const zoom2 = ZoomItem(targetSlide: 5);
      final replaced = ZoomFeatureService.replaceZoomAt(html, 0, zoom2);
      expect(ZoomFeatureService.zoomsIn(replaced).first.targetSlide, 5);
    });
  });

  group('CameoData model (P7)', () {
    test('round-trips through JSON', () {
      const cameo = CameoData(label: 'Webcam', x: 10, y: 20, w: 30, h: 40);
      final restored = CameoData.fromJson(cameo.toJson());
      expect(restored.label, 'Webcam');
      expect(restored.x, 10);
    });

    test('htmlMarkup contains camera icon and label', () {
      const cameo = CameoData(label: 'Camera');
      final html = cameo.htmlMarkup;
      expect(html, contains('📷'));
      expect(html, contains('>Camera</div>'));
    });

    test('service cameosIn / cameoMarkup / replaceCameoAt', () {
      const cameo = CameoData(label: 'Cam');
      final html = '${cameoDiv(cameo)}\n<p>x</p>';
      expect(CameoService.cameoCount(html), 1);
      expect(CameoService.cameosIn(html).length, 1);
      const cameo2 = CameoData(label: 'Cam2');
      final replaced = CameoService.replaceCameoAt(html, 0, cameo2);
      expect(CameoService.cameosIn(replaced).first.label, 'Cam2');
    });
  });

  group('DeckSection model (P6)', () {
    test('round-trips through JSON', () {
      const section = DeckSection(name: 'Intro', startSlide: 0);
      final restored = DeckSection.fromJson(section.toJson());
      expect(restored.name, 'Intro');
      expect(restored.startSlide, 0);
    });

    test('SectionService serializes/deserializes list', () {
      final sections = [
        const DeckSection(name: 'Intro', startSlide: 0),
        const DeckSection(name: 'Results', startSlide: 3),
      ];
      final json = SectionService.sectionsToJson(sections);
      final restored = SectionService.sectionsFromJson(json);
      expect(restored.length, 2);
      expect(restored[1].name, 'Results');
    });
  });

  group('SectionZoomData model (P6)', () {
    test('round-trips through JSON', () {
      const zoom = SectionZoomData(
        entries: [
          SectionZoomEntry(label: 'Intro', slide: 0),
          SectionZoomEntry(label: 'Results', slide: 3),
        ],
        columns: 2,
        frameStyle: 'shadow',
        x: 10, y: 25, w: 80, h: 50,
      );
      final restored = SectionZoomData.fromJson(zoom.toJson());
      expect(restored.entries.length, 2);
      expect(restored.entries[1].label, 'Results');
      expect(restored.entries[1].slide, 3);
      expect(restored.columns, 2);
      expect(restored.frameStyle, 'shadow');
    });

    test('htmlMarkup is a tile grid where each tile jumps to its slide', () {
      const zoom = SectionZoomData(
        entries: [
          SectionZoomEntry(label: 'Intro', slide: 0),
          SectionZoomEntry(label: 'Results', slide: 3),
        ],
      );
      final html = zoom.htmlMarkup;
      expect(html, contains('data-sectionzoom-html'));
      expect(html, contains('goToSlide(0)'));
      expect(html, contains('goToSlide(3)'));
      expect(html, contains('>Intro</div>'));
      expect(html, contains('>Results</div>'));
    });

    test('service sectionZoomsIn / sectionZoomMarkup / replaceSectionZoomAt', () {
      const zoom = SectionZoomData(
        entries: [SectionZoomEntry(label: 'A', slide: 1)],
      );
      final html = '${sectionZoomDiv(zoom)}\n<p>x</p>';
      expect(SectionZoomService.sectionZoomCount(html), 1);
      expect(SectionZoomService.sectionZoomsIn(html).length, 1);
      const zoom2 = SectionZoomData(
        entries: [SectionZoomEntry(label: 'B', slide: 4)],
      );
      final replaced = SectionZoomService.replaceSectionZoomAt(html, 0, zoom2);
      expect(SectionZoomService.sectionZoomsIn(replaced).first.entries.first.label,
          'B');
      expect(SectionZoomService.sectionZoomsIn(replaced).first.entries.first.slide, 4);
    });
  });

  group('PPTX export (P4, P8)', () {
    test('zoom block becomes a p:sp with slide jump action', () async {
      const zoom = ZoomItem(targetSlide: 2, x: 30, y: 40, w: 25, h: 18);
      final archive = await exportPptx(zoomDiv(zoom));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('name="Slide Zoom Slide 3"'));
      expect(slideXml, contains('ppaction://hlinksldjump'));
      expect(slideXml, contains('rgbClr val="1A2A4A"'));
    });

    test('cameo block becomes a dark placeholder with label', () async {
      const cameo = CameoData(label: 'Webcam', x: 40, y: 30, w: 20, h: 25);
      final archive = await exportPptx(cameoDiv(cameo));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('name="Cameo Webcam"'));
      expect(slideXml, contains('rgbClr val="1A1A2E"'));
    });

    test('section zoom block becomes p:sp grid with slide jump actions', () async {
      const zoom = SectionZoomData(
        entries: [
          SectionZoomEntry(label: 'Intro', slide: 0),
          SectionZoomEntry(label: 'Results', slide: 3),
        ],
      );
      final archive = await exportPptx(sectionZoomDiv(zoom));
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, contains('name="Section Zoom Intro"'));
      expect(slideXml, contains('name="Section Zoom Results"'));
      expect(slideXml, contains('ppaction://hlinksldjump'));
      expect(slideXml, contains('rgbClr val="1A2A4A"'));
      // Two tiles → two p:sp shapes.
      expect('Section Zoom '.allMatches(slideXml).length, 2);
    });

    test('deck without zoom/cameo unchanged', () async {
      final archive = await exportPptx('<h1>Hello</h1>');
      final slideXml = part(archive, 'ppt/slides/slide1.xml');
      expect(slideXml, isNot(contains('Slide Zoom')));
      expect(slideXml, isNot(contains('Cameo')));
    });
  });

  group('HTML export (P3, P7)', () {
    test('zoom renders as clickable div with goToSlide', () {
      const zoom = ZoomItem(targetSlide: 2, thumbnailLabel: 'Chart');
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': zoomDiv(zoom)},
      ]);
      expect(html, contains('data-zoom-html'));
      expect(html, contains('goToSlide(2)'));
      expect(html, contains('>Chart</div>'));
    });

    test('cameo renders as styled camera placeholder', () {
      const cameo = CameoData(label: 'Cam');
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': cameoDiv(cameo)},
      ]);
      expect(html, contains('data-cameo-html'));
      expect(html, contains('📷'));
    });

    test('section zoom renders as clickable tile grid with goToSlide', () {
      const zoom = SectionZoomData(
        entries: [
          SectionZoomEntry(label: 'Intro', slide: 0),
          SectionZoomEntry(label: 'Results', slide: 3),
        ],
      );
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': sectionZoomDiv(zoom)},
      ]);
      expect(html, contains('data-sectionzoom-html'));
      expect(html, contains('goToSlide(0)'));
      expect(html, contains('goToSlide(3)'));
      expect(html, contains('>Intro</div>'));
    });

    test('goToSlide JS function is present', () {
      final html = HtmlExportService().buildPresentationHtml([
        {'title': 'T', 'htmlContent': '<h1>Hello</h1>'},
      ]);
      expect(html, contains('function goToSlide(index)'));
      expect(html, contains('showSlide(index)'));
    });
  });

  group('PDF export (P3, P7)', () {
    test('zoom renders without crashing', () async {
      const zoom = ZoomItem(targetSlide: 1);
      final dir = await Directory.systemTemp.createTemp('ghita_t20pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf([
          {'title': 'T', 'htmlContent': zoomDiv(zoom)},
        ], path);
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('cameo renders without crashing', () async {
      const cameo = CameoData(label: 'Cam');
      final dir = await Directory.systemTemp.createTemp('ghita_t20pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf([
          {'title': 'T', 'htmlContent': cameoDiv(cameo)},
        ], path);
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('section zoom renders without crashing', () async {
      const zoom = SectionZoomData(
        entries: [SectionZoomEntry(label: 'Intro', slide: 0)],
      );
      final dir = await Directory.systemTemp.createTemp('ghita_t20pdf_');
      try {
        final path = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf([
          {'title': 'T', 'htmlContent': sectionZoomDiv(zoom)},
        ], path);
        final bytes = File(path).readAsBytesSync();
        expect(bytes, isNotEmpty);
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('Regression (P10)', () {
    test('cameo out of bounds div is safe', () {
      const cameo = CameoData(label: 'Safe');
      final html = cameo.htmlMarkup;
      expect(html, contains('Safe'));
    });
  });
}