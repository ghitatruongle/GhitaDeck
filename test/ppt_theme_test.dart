import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/ppt_theme_setting.dart';
import 'package:ghita_ppt_converter/services/export_isolate.dart';
import 'package:ghita_ppt_converter/services/export_job.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:xml/xml.dart' as xml;

/// Track 04 tests — user theme & font of the exported PPTX.
///
///  * the default export reproduces the v1.6.3 hardcoded Office theme
///    byte-for-byte (regression gate),
///  * a custom theme lands in the OOXML clrScheme + fontScheme of both
///    theme parts, with a well-formed XML payload (no repair prompt),
///  * hostile values (bad hex, XML metacharacters in font names) fall back
///    to safe Office defaults instead of corrupting the package,
///  * the theme flows through the worker isolate and the ExportJob.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The exact v1.6.3 hardcoded theme part (regression baseline).
  String v163Baseline() {
    const fill = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
    const ln =
        '<a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Ghita Theme">'
        '<a:themeElements>'
        '<a:clrScheme name="Ghita">'
        '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
        '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
        '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
        '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
        '<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
        '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
        '<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>'
        '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
        '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
        '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
        '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
        '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
        '</a:clrScheme>'
        '<a:fontScheme name="Ghita">'
        '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
        '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>'
        '</a:fontScheme>'
        '<a:fmtScheme name="Ghita">'
        '<a:fillStyleLst>$fill$fill$fill</a:fillStyleLst>'
        '<a:lnStyleLst>$ln$ln$ln</a:lnStyleLst>'
        '<a:effectStyleLst>'
        '<a:effectStyle><a:effectLst/></a:effectStyle>'
        '<a:effectStyle><a:effectLst/></a:effectStyle>'
        '<a:effectStyle><a:effectLst/></a:effectStyle>'
        '</a:effectStyleLst>'
        '<a:bgFillStyleLst>$fill$fill$fill</a:bgFillStyleLst>'
        '</a:fmtScheme>'
        '</a:themeElements>'
        '</a:theme>';
  }

  final slides = [
    {
      'title': 'Theme',
      'htmlContent': '<p>Nội dung</p>',
    }
  ];

  Future<Archive> exportPptx({
    PptThemeSetting? theme,
    bool viaIsolate = false,
    bool withNotes = false,
  }) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t04_');
    final out = '${dir.path}/theme.pptx';
    try {
      final deck = withNotes
          ? [
              {
                'title': 'Theme',
                'htmlContent': '<p>Nội dung</p>',
                'notes': 'Ghi chú',
              }
            ]
          : slides;
      if (viaIsolate) {
        await runPptExportInIsolate(deck, out, theme: theme);
      } else {
        await PPTGenerator.generatePPT(deck, out, theme: theme);
      }
      return ZipDecoder().decodeBytes(File(out).readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  test('default export reproduces the v1.6.3 theme byte-for-byte', () async {
    final archive = await exportPptx();
    final theme = utf8.decode(archive.files
        .firstWhere((e) => e.name == 'ppt/theme/theme1.xml')
        .content as List<int>);
    expect(theme, v163Baseline(),
        reason: 'no theme option must not change the default output');
  });

  test('custom theme lands in clrScheme + fontScheme (both theme parts)',
      () async {
    const custom = PptThemeSetting(
      accent1: '12AB34',
      accent2: 'FAFAFA',
      accent3: '111111',
      hlink: '0000FF',
      folHlink: 'FF00FF',
      fontMajor: 'Arial Black',
      fontMinor: 'Arial',
    );
    final archive = await exportPptx(theme: custom, withNotes: true);

    String part(String name) => utf8.decode(archive.files
        .firstWhere((e) => e.name == name)
        .content as List<int>);

    final theme1 = part('ppt/theme/theme1.xml');
    expect(theme1, contains('<a:accent1><a:srgbClr val="12AB34"/></a:accent1>'));
    expect(theme1, contains('<a:accent2><a:srgbClr val="FAFAFA"/></a:accent2>'));
    expect(theme1, contains('<a:hlink><a:srgbClr val="0000FF"/></a:hlink>'));
    expect(theme1, contains('<a:folHlink><a:srgbClr val="FF00FF"/></a:folHlink>'));
    expect(theme1, contains('typeface="Arial Black"'));
    expect(theme1, contains('typeface="Arial"'));
    // The notes master carries its own theme copy with the same values.
    final theme2 = part('ppt/theme/theme2.xml');
    expect(theme2, contains('<a:accent1><a:srgbClr val="12AB34"/></a:accent1>'));
    expect(theme2, contains('typeface="Arial"'));
    // Well-formed XML → PowerPoint will not show a repair prompt.
    expect(() => xml.XmlDocument.parse(theme1), returnsNormally);
    expect(() => xml.XmlDocument.parse(theme2), returnsNormally);
  });

  test('hostile values fall back to safe Office defaults', () async {
    final archive = await exportPptx(
      theme: const PptThemeSetting(
        accent1: 'ZZZZZZ', // invalid hex
        dk2: '#RRGGBB',
        fontMinor: 'Bad <Font> & "Quotes"',
      ),
    );
    final theme1 = utf8.decode(archive.files
        .firstWhere((e) => e.name == 'ppt/theme/theme1.xml')
        .content as List<int>);
    // Invalid hex → Office accent fallback, never an invalid srgbClr.
    expect(theme1, isNot(contains('ZZZZZZ')));
    expect(theme1, contains('<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'));
    expect(theme1, contains('<a:dk2><a:srgbClr val="4472C4"/></a:dk2>'));
    // Font metacharacters are XML-escaped so the part stays well-formed.
    expect(theme1, contains('typeface="Bad &lt;Font&gt; &amp; &quot;Quotes&quot;"'));
    expect(() => xml.XmlDocument.parse(theme1), returnsNormally);
  });

  test('theme flows through the worker isolate', () async {
    const custom = PptThemeSetting(accent1: 'ABCDEF', fontMinor: 'Roboto');
    final archive = await exportPptx(theme: custom, viaIsolate: true);
    final theme1 = utf8.decode(archive.files
        .firstWhere((e) => e.name == 'ppt/theme/theme1.xml')
        .content as List<int>);
    expect(theme1, contains('<a:accent1><a:srgbClr val="ABCDEF"/></a:accent1>'));
    expect(theme1, contains('typeface="Roboto"'));
  });

  test('theme flows through ExportJob options', () async {
    final dir = await Directory.systemTemp.createTemp('ghita_t04_job_');
    try {
      final job = ExportJob(
        slides: slides,
        outputPath: '${dir.path}/out.pptx',
        format: ExportJobFormat.pptx,
        options: const ExportJobOptions(
          theme: PptThemeSetting(accent2: 'CA5010', fontMinor: 'Roboto'),
        ),
      );
      await job.run();
      final archive =
          ZipDecoder().decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
      final theme1 = utf8.decode(archive.files
          .firstWhere((e) => e.name == 'ppt/theme/theme1.xml')
          .content as List<int>);
      expect(theme1,
          contains('<a:accent2><a:srgbClr val="CA5010"/></a:accent2>'));
      expect(theme1, contains('typeface="Roboto"'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('the blank slide layout has no hardcoded palette (P6)', () async {
    final archive = await exportPptx();
    String part(String name) => utf8.decode(archive.files
        .firstWhere((e) => e.name == name)
        .content as List<int>);
    // The layout is a blank placeholder: colors/fonts come only from the
    // master clrMap + theme part, so the user theme applies everywhere.
    final layout = part('ppt/slideLayouts/slideLayout1.xml');
    expect(layout, isNot(contains('srgbClr')));
    expect(layout, isNot(contains('typeface')));
    // The master maps the theme's scheme colours to the slide colour map.
    final master = part('ppt/slideMasters/slideMaster1.xml');
    for (final accent in ['accent1', 'accent3', 'accent6']) {
      expect(master, contains('$accent="$accent"'));
    }
  });

  test('PptThemeSetting survives map round-trips and user mapping', () {
    const theme =
        PptThemeSetting(accent1: 'AA0000', fontMinor: 'Times New Roman');
    final restored = PptThemeSetting.fromMap(theme.toMap());
    expect(restored.accent1, 'AA0000');
    expect(restored.fontMinor, 'Times New Roman');
    expect(restored.accent4, 'FFC000');

    final user = PptThemeSetting.office.withUserColors(
      accent1: '106EBE',
      accent2: 'CA5010',
    );
    expect(user.accent1, '106EBE');
    expect(user.accent2, 'CA5010');
    // Other slots keep Office defaults.
    expect(user.accent3, 'A5A5A5');
    expect(user.hlink, '0563C1');

    // withUserColors normalizes bad input back to the fallback.
    final dirty =
        PptThemeSetting.office.withUserColors(accent1: 'nope', accent2: '#123456');
    expect(dirty.accent1, '4472C4');
    expect(dirty.accent2, '123456');
  });
}