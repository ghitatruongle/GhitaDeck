import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/models/slide_layout.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/ppt_layout_registry.dart';
import 'package:xml/xml.dart' as xml;

/// Track 05 tests — Master & SlideLayout đa dạng.
///
///  * all nine registered layouts are generated as real `<p:sldLayout>` parts
///    with correct OOXML placeholders (title/body/pic, type+idx) and
///    `clrMapOvr` — PowerPoint's Slide Layout gallery shows the full set,
///  * slides bind to their layout through their own rels; unknown layout
///    types fall back to Blank (the v1.6.3 default),
///  * legacy decks without a layoutType keep the exact v1.6.3 behavior,
///  * `Slide.layoutType` round-trips through save/load (two-way sync).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final basicSlides = [
    {'title': 'A', 'htmlContent': '<p>Nội dung A</p>'},
  ];

  Future<Archive> exportPptx(List<Map<String, dynamic>> slides) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t05_');
    try {
      await PPTGenerator.generatePPT(slides, '${dir.path}/out.pptx');
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  test('all nine layouts are generated as well-formed sldLayout parts',
      () async {
    final archive = await exportPptx(basicSlides);
    for (var i = 1; i <= 9; i++) {
      final layoutXml = part(archive, 'ppt/slideLayouts/slideLayout$i.xml');
      expect(() => xml.XmlDocument.parse(layoutXml), returnsNormally,
          reason: 'slideLayout$i.xml must be well-formed');
      expect(layoutXml,
          contains('<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'));
      // Every layout part declares its master relationship.
      final rels =
          part(archive, 'ppt/slideLayouts/_rels/slideLayout$i.xml.rels');
      expect(rels, contains('../slideMasters/slideMaster1.xml'));
    }
    // ContentTypes lists every layout override.
    final contentTypes = part(archive, '[Content_Types].xml');
    for (var i = 1; i <= 9; i++) {
      expect(contentTypes,
          contains('PartName="/ppt/slideLayouts/slideLayout$i.xml"'));
    }
  });

  test('layouts carry the real PowerPoint placeholders (P7)', () async {
    final archive = await exportPptx(basicSlides);
    String layout(int n) => part(archive, 'ppt/slideLayouts/slideLayout$n.xml');

    // Title Slide: centered title + subtitle.
    expect(layout(2), contains('<p:ph type="ctrTitle"/>'));
    expect(layout(2), contains('<p:ph type="subTitle"/>'));
    // Title and Content: title + body idx=1.
    expect(layout(3), contains('<p:ph type="title"/>'));
    expect(layout(3), contains('<p:ph type="body" idx="1"/>'));
    // Section Header.
    expect(layout(4), contains('<p:ph type="ctrTitle"/>'));
    expect(layout(4), contains('<p:ph type="subTitle"/>'));
    // Two Content: two body placeholders with distinct indices.
    expect(layout(5), contains('<p:ph type="body" idx="1"/>'));
    expect(layout(5), contains('<p:ph type="body" idx="2"/>'));
    // Picture with Caption: a picture placeholder.
    expect(layout(9), contains('<p:ph type="pic"/>'));
    // Blank has no placeholders at all.
    expect(layout(1), isNot(contains('<p:ph ')));
  });

  test('the single master lists all nine layouts (P6)', () async {
    final archive = await exportPptx(basicSlides);
    final master = part(archive, 'ppt/slideMasters/slideMaster1.xml');
    for (var i = 0; i < 9; i++) {
      expect(master, contains('<p:sldLayoutId id="${2147483649 + i}"'));
    }
    final masterRels = part(archive, 'ppt/slideMasters/_rels/slideMaster1.xml.rels');
    for (var i = 1; i <= 9; i++) {
      expect(masterRels, contains('Target="../slideLayouts/slideLayout$i.xml"'));
    }
    // Theme relationship moved after the layouts.
    expect(masterRels, contains('rId10" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"'));
  });

  test('slides bind to their layout; unknown types fall back to blank (P5)',
      () async {
    final archive = await exportPptx([
      {'title': 'Không đặt layout', 'htmlContent': '<p>x</p>'},
      {
        'title': 'Tiêu đề + Nội dung',
        'htmlContent': '<p>y</p>',
        'layoutType': 'titleAndContent',
      },
      {
        'title': 'Layout lạ',
        'htmlContent': '<p>z</p>',
        'layoutType': 'không_tồn_tại',
      },
      {
        'title': 'Legacy standard',
        'htmlContent': '<p>w</p>',
        'layoutType': 'standard',
      },
    ]);
    String relsOf(int slide) => part(archive, 'ppt/slides/_rels/slide$slide.xml.rels');

    // Default (no layoutType) → blank layout part 1, exactly like v1.6.3.
    expect(relsOf(1), contains('Target="../slideLayouts/slideLayout1.xml"'));
    // Explicit layout → its part (titleAndContent = part 3).
    expect(relsOf(2), contains('Target="../slideLayouts/slideLayout3.xml"'));
    // Unknown + legacy 'standard' → blank fallback.
    expect(relsOf(3), contains('Target="../slideLayouts/slideLayout1.xml"'));
    expect(relsOf(4), contains('Target="../slideLayouts/slideLayout1.xml"'));
  });

  test('legacy decks without layoutType keep the v1.6.3 structure (P10)',
      () async {
    final archive = await exportPptx(basicSlides);
    // Slide content unchanged: explicit shapes still present.
    final slide = part(archive, 'ppt/slides/slide1.xml');
    expect(slide, contains('<p:sp>'));
    expect(slide, contains('<a:prstGeom prst="rect">'));
    // All parts well-formed → the package opens without a repair prompt.
    for (final entry in archive.files) {
      if (entry.name.endsWith('.xml') || entry.name.endsWith('.rels')) {
        expect(() => xml.XmlDocument.parse(utf8.decode(entry.content as List<int>)),
            returnsNormally, reason: entry.name);
      }
    }
    // The theme part is untouched by the layout work.
    final theme = part(archive, 'ppt/theme/theme1.xml');
    expect(theme, contains('typeface="Calibri"'));
  });

  test('layoutTypeOf / layoutPartNumber resolution', () {
    expect(layoutTypeOf({'title': 'x'}), SlideLayoutType.blank);
    expect(layoutTypeOf({'layoutType': 'standard'}), SlideLayoutType.blank);
    expect(layoutTypeOf({'layoutType': 'twoContent'}),
        SlideLayoutType.twoContent);
    expect(layoutTypeOf({'layoutType': 'nope'}), SlideLayoutType.blank);

    expect(layoutPartNumber(SlideLayoutType.blank), 1);
    expect(layoutPartNumber(SlideLayoutType.titleAndContent), 3);
    expect(layoutPartNumber(SlideLayoutType.pictureAndCaption), 9);
  });

  test('Slide.layoutType round-trips through save/load (P8 data layer)', () {
    final slide = Slide(
      title: 'Two cột',
      htmlContent: '<p>Nội dung</p>',
      layoutType: 'twoContent',
    );
    final restored = Slide.fromMap(slide.toMap());
    expect(restored.layoutType, 'twoContent');
    // The registry understands the round-tripped value.
    expect(layoutTypeOf(restored.toMap()), SlideLayoutType.twoContent);

    final changed = slide.copyWith(layoutType: 'sectionHeader');
    expect(layoutTypeOf(changed.toMap()), SlideLayoutType.sectionHeader);
  });
}