import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/model3d_item.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/model3d_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:xml/xml.dart' as xml;

/// Track 14 tests — 3D Models (FEAT 10).
///
///  * model round-trip + markup/replace helpers (P2),
///  * PPTX package: GLB under ppt/media/ + Default glb before Overrides +
///    `model3d` (2017/06) rel + poster PNG + `mc:AlternateContent`/
///    `am3d:model3d` + a3danim rotation when rotate=true (P3–P5),
///  * HTML deck: poster + "open in PowerPoint" note, never the GLB bytes
///    (P7), PDF placeholder, empty-model skip + untouched decks (P10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A tiny fake GLB payload — the exporters package bytes as-is (real GLB
  // verification happens against PowerPoint, see CHANGELOG P10).
  final fakeGlbBytes = List<int>.generate(64, (i) => i);

  String modelDiv(Model3DData model) =>
      '<div data-model3d=\'${model.toJson().replaceAll("'", '&#39;')}\'></div>';

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t14_');
    try {
      await PPTGenerator.generatePPT(
        [
          {'title': '3D', 'htmlContent': htmlContent},
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

  group('model + service (P2)', () {
    test('Model3DData round-trips through JSON', () {
      const model = Model3DData(
        src: 'data:model/gltf-binary;base64,QUJD',
        posterSvg: '<svg/>',
        rotate: true,
        name: 'Cube',
      );
      final restored = Model3DData.fromJson(model.toJson());
      expect(restored.src, model.src);
      expect(restored.rotate, isTrue);
      expect(restored.name, 'Cube');
    });

    test('modelsIn / markup / replaceModel3dAt', () {
      const a = Model3DData(src: 'data:model/gltf-binary;base64,QUJD');
      const b = Model3DData(src: 'data:model/gltf-binary;base64,REVG', rotate: true);
      final html = '${modelDiv(a)}<p>x</p>${modelDiv(b)}';
      final found = Model3DService.modelsIn(html);
      expect(found.length, 2);
      expect(found[1].rotate, isTrue);
      final replaced = Model3DService.replaceModel3dAt(
          html, 0, a.copyWith(rotate: true));
      expect(Model3DService.modelsIn(replaced).length, 2);
      expect(Model3DService.modelsIn(replaced)[0].rotate, isTrue);
      expect(Model3DService.replaceModel3dAt(html, 5, a), html);
    });

    test('renderPosterSvg / renderPosterPng produce content', () {
      final svg = Model3DService.renderPosterSvg(const Model3DData(name: 'Test'));
      expect(svg, contains('<svg'));
      expect(svg, contains('Test'));
      final png = Model3DService.renderPosterPng(const Model3DData());
      expect(png.length, greaterThan(100));
    });
  });

  group('PPTX am3d package (P3–P5)', () {
    test('model becomes an am3d graphicFrame with glb + poster parts',
        () async {
      final archive = await exportPptx(
          modelDiv(const Model3DData(src: 'data:model/gltf-binary;base64,QUJD')));
      expect(
        archive.files.any((e) => e.name.startsWith('ppt/media/model3d')),
        isTrue,
        reason: 'glb embedded under ppt/media/',
      );
      expect(
        archive.files.any((e) =>
            e.name.startsWith('ppt/media/image') && e.name.endsWith('.png')),
        isTrue,
        reason: 'rasterized poster embedded',
      );
      final ct = part(archive, '[Content_Types].xml');
      expect(ct, contains('Extension="glb" ContentType="model/gltf-binary"'));
      expect(ct.indexOf('<Default'), lessThan(ct.indexOf('<Override')));

      final rels = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(rels, contains('office/2017/06/relationships/model3d'));
      expect(rels, contains('Target="../media/model3d1.glb"'));

      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(() => xml.XmlDocument.parse(slide), returnsNormally);
      expect(slide, contains('mc:AlternateContent'));
      expect(slide, contains('Requires="am3d"'));
      expect(slide, contains(
          'uri="http://schemas.microsoft.com/office/drawing/2017/model3d"'));
      expect(slide, contains('<am3d:model3d'));
      expect(slide, contains('rName="Office3DRenderer"'));
      expect(slide, contains('<mc:Fallback>'));
    });

    test('rotate adds the timeline fragment; without rotate it stays inert',
        () async {
      // rotate=true: the a3danim extension + a timeline fragment that plays
      // the model's embedded animation 0 on slide entry.
      final archive = await exportPptx(
          modelDiv(const Model3DData(
              src: 'data:model/gltf-binary;base64,QUJD', rotate: true)));
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(slide, contains('a3danim:embedAnim'));
      expect(slide, contains('count="indefinite"'));
      expect(slide, contains('<p:timing>'));
      expect(slide, contains('attrName>embedded1</p:attrName>'));
      expect(slide, contains('presetID="100"'));
      // The timeline ids are offset so they never collide with media specs.
      expect(slide, contains('presetID="100" presetClass="emph" presetSubtype="1" repeatCount="indefinite" fill="hold" nodeType="withEffect"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst><p:anim calcmode="lin" valueType="num"><p:cBhvr><p:cTn id="105" dur="1900"'));

      // rotate=false: the extension exists (PowerPoint requires it) but no
      // timeline plays it.
      final plain = await exportPptx(modelDiv(
          const Model3DData(src: 'data:model/gltf-binary;base64,QUJD')));
      final plainSlide = part(plain, 'ppt/slides/slide1.xml');
      expect(plainSlide, contains('a3danim:embedAnim'));
      expect(plainSlide, isNot(contains('<p:timing>')));
    });

    test('identical models share one glb part (dedupe)', () async {
      final archive = await exportPptx(
          '${modelDiv(const Model3DData(src: 'data:model/gltf-binary;base64,QUJD'))}'
          '<p>x</p>'
          '${modelDiv(const Model3DData(src: 'data:model/gltf-binary;base64,QUJD'))}');
      final glbParts = archive.files
          .where((e) => e.name.startsWith('ppt/media/model3d'))
          .toList();
      expect(glbParts.length, 1, reason: 'one glb part for two blocks');
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect('<mc:AlternateContent'.allMatches(slide).length, 2);
    });

    test('models without payload are skipped; plain decks unchanged',
        () async {
      final archive = await exportPptx(
          '<p>ok</p>${modelDiv(const Model3DData())}');
      expect(
        archive.files.any((e) => e.name.startsWith('ppt/media/model3d')),
        isFalse,
      );
      final plain = await exportPptx('<p>không có 3D</p>');
      expect(part(plain, '[Content_Types].xml'), isNot(contains('glb')));
      expect(part(plain, 'ppt/slides/slide1.xml'), isNot(contains('am3d')));
    });
  });

  group('HTML + PDF (P7)', () {
    test('deck shows the poster + note and never the GLB bytes', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t14_html_');
      try {
        final model = Model3DData(
            src: 'data:model/gltf-binary;base64,${base64Encode(fakeGlbBytes)}',
            name: 'Cube');
        final path = await HtmlExportService().exportToHtmlPath(
          [
            {'title': '3D', 'htmlContent': modelDiv(model)},
          ],
          '${dir.path}/deck.html',
        );
        final html = File(path).readAsStringSync();
        expect(html, contains('ghita-model3d'));
        expect(html, contains('mở trong PowerPoint để xem'));
        // The GLB payload must not be in the deck (slimmed attribute JSON).
        expect(html, isNot(contains(base64Encode(fakeGlbBytes))));
        expect(html, isNot(contains('data:model/gltf-binary;base64')));
        // The poster SVG renders inline.
        expect(html, contains('<svg'));
        expect(html, contains('Cube'));
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('PDF export renders a slide with the 3D placeholder', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t14_pdf_');
      try {
        final out = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [
            {
              'title': '3D',
              'htmlContent': modelDiv(
                  const Model3DData(src: 'data:model/gltf-binary;base64,QUJD')),
            },
          ],
          out,
        );
        final bytes = File(out).readAsBytesSync();
        expect(bytes.length, greaterThan(500));
        expect(String.fromCharCodes(bytes.take(5).toList()), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}