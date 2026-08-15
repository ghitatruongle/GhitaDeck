/// OpenDocument Presentation (.odp) export (Track 44, FEAT 72).
///
/// Builds a standards-shaped ODF package from slide maps: title + text
/// blocks + tables + images on per-slide `draw:page` frames. The ZIP is
/// assembled with the `archive` package, so the whole pipeline is pure Dart
/// and testable (the produced XML is asserted in tests; the file opens in
/// LibreOffice / PowerPoint).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import 'html_image_loader.dart';
import 'ppt_generator.dart';

class OdpExportService {
  OdpExportService._();

  static const String _nsOffice =
      'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const String _nsDraw =
      'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0';
  static const String _nsText =
      'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const String _nsTable =
      'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  static const String _nsSvg =
      'urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0';
  static const String _nsXlink = 'http://www.w3.org/1999/xlink';

  /// Content.xml for [slides]. Images are registered in [images] as
  /// (path, bytes) pairs so the caller can put them in the package.
  static String buildContentXml(
    List<Map<String, dynamic>> slides, {
    List<(String, Uint8List)>? images,
  }) {
    final imgs = images ?? [];
    var imgCounter = 0;
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<office:document-content '
          'xmlns:office="$_nsOffice" xmlns:draw="$_nsDraw" '
          'xmlns:text="$_nsText" xmlns:table="$_nsTable" '
          'xmlns:svg="$_nsSvg" xmlns:xlink="$_nsXlink" '
          'office:version="1.2">')
      ..writeln('  <office:body><office:presentation>');

    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final title = (slide['title'] ?? 'Slide ${i + 1}').toString();
      b.writeln(
          '    <draw:page draw:name="${_xml(title)}" draw:style-name="dp1">');
      // Title frame.
      b.writeln('      <draw:frame draw:name="Title${i + 1}" '
          'presentation:class="title" svg:x="1.25cm" svg:y="0.5cm" '
          'svg:width="25.5cm" svg:height="1.6cm">'
          '<draw:text-box><text:p>${_xml(title)}</text:p></draw:text-box>'
          '</draw:frame>');

      // Body blocks (text/list/table/image).
      var blockTop = 2.4;
      final html = (slide['htmlContent'] ?? '').toString();
      if (html.trim().isNotEmpty) {
        for (final block in PPTGenerator.parseHtmlContentFull(html)) {
          final type = block['type'];
          if (type == 'text') {
            final paras = (block['paragraphs'] as List? ?? const [])
                .cast<Map<String, String>>();
            final lines = paras.map((r) => (r['text'] ?? '').trim()).where((t) => t.isNotEmpty);
            if (lines.isNotEmpty) {
              b.writeln(_frame('Body${i + 1}_$blockTop', '${blockTop}cm',
                  _paras(lines)));
              blockTop += 1.1;
            }
          } else if (type == 'list') {
            final items = (block['items'] as List? ?? const [])
                .cast<Map<String, String>>();
            final lines = items
                .map((r) => (r['text'] ?? '').trim())
                .where((t) => t.isNotEmpty);
            if (lines.isNotEmpty) {
              b.writeln(_frame('List${i + 1}_$blockTop', '${blockTop}cm',
                  _paras(lines, bullet: '• ')));
              blockTop += 1.1 * lines.length;
            }
          } else if (type == 'table') {
            final rowsDynamic = block['rows'] as List? ?? [];
            if (rowsDynamic.isNotEmpty) {
              b.writeln(_tableFrame('Tbl${i + 1}_$blockTop', '${blockTop}cm',
                  rowsDynamic));
              blockTop += 1.2 * rowsDynamic.length;
            }
          } else if (type == 'image') {
            final src = (block['src'] ?? '').toString();
            final loaded = HtmlImageLoader.load(src, maxWidth: 1600);
            if (loaded != null) {
              final path = 'Pictures/${++imgCounter}.${loaded.ext}';
              imgs.add((path, Uint8List.fromList(loaded.bytes)));
              b.writeln('      <draw:frame draw:name="Pic${i + 1}_$blockTop" '
                  'svg:x="1.25cm" svg:y="${blockTop}cm" '
                  'svg:width="8cm" svg:height="4.5cm">'
                  '<draw:image xlink:href="$path" xlink:type="simple" '
                  'xlink:show="embed" xlink:actuate="onLoad"/>'
                  '</draw:frame>');
              blockTop += 4.8;
            }
          }
        }
      }
      b.writeln('    </draw:page>');
    }

    b.writeln('  </office:presentation></office:body>');
    b.writeln('</office:document-content>');
    return b.toString();
  }

  static String _paras(Iterable<String> lines, {String bullet = ''}) {
    final ps = lines.map((l) => '<text:p>${_xml(bullet + l)}</text:p>').join();
    return '<draw:text-box>$ps</draw:text-box>';
  }

  static String _frame(String name, String top, String inner) =>
      '      <draw:frame draw:name="$_xml(name)" presentation:class="outline" '
      'svg:x="1.25cm" svg:y="$top" svg:width="25.5cm" svg:height="8cm">'
      '$inner</draw:frame>';

  static String _tableFrame(String name, String top, List<dynamic> rows) {
    final b = StringBuffer()
      ..write('      <draw:frame draw:name="$_xml(name)" '
          'svg:x="1.25cm" svg:y="$top" svg:width="25.5cm" svg:height="6cm">'
          '<draw:text-box><table:table>');
    for (final row in rows) {
      b.write('<table:table-row>');
      for (final cell in row as List) {
        final text = cell is Map ? (cell['text'] ?? '').toString() : '';
        b.write('<table:table-cell><text:p>${_xml(text)}</text:p>'
            '</table:table-cell>');
      }
      b.write('</table:table-row>');
    }
    b.write('</table:table></draw:text-box></draw:frame>');
    return b.toString();
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Build the full ODP package bytes.
  static Uint8List buildOdpBytes(List<Map<String, dynamic>> slides) {
    final images = <(String, Uint8List)>[];
    final contentXml = buildContentXml(slides, images: images);
    final archive = Archive();
    archive.addFile(ArchiveFile('mimetype', _mime.length, _mime.codeUnits));
    archive.addFile(
        ArchiveFile('content.xml', utf8.encode(contentXml).length, utf8.encode(contentXml)));
    archive.addFile(ArchiveFile('styles.xml', _styles.length, _styles.codeUnits));
    archive.addFile(ArchiveFile('meta.xml', _meta.length, _meta.codeUnits));
    archive.addFile(
        ArchiveFile('settings.xml', _settings.length, _settings.codeUnits));

    final manifest = _manifestXml(images);
    archive.addFile(ArchiveFile(
        'META-INF/manifest.xml', utf8.encode(manifest).length, utf8.encode(manifest)));
    for (final (path, bytes) in images) {
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static const String _mime =
      'application/vnd.oasis.opendocument.presentation';

  static const String _styles = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" office:version="1.2">
 <office:automatic-styles>
  <style:style style:name="dp1" style:family="drawing-page"/>
 </office:automatic-styles>
</office:document-styles>''';

  static const String _meta = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" office:version="1.2">
 <office:meta><meta:generator>Ghita PPT Converter</meta:generator></office:meta>
</office:document-meta>''';

  static const String _settings = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-settings xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" office:version="1.2">
 <office:settings/>
</office:document-settings>''';

  static String _manifestXml(List<(String, Uint8List)> images) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">')
      ..writeln(' <manifest:file-entry manifest:full-path="/" manifest:media-type="$_mime"/>')
      ..writeln(' <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>')
      ..writeln(' <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>')
      ..writeln(' <manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>')
      ..writeln(' <manifest:file-entry manifest:full-path="settings.xml" manifest:media-type="text/xml"/>');
    for (final (path, _) in images) {
      final ext = path.split('.').last.toLowerCase();
      final mime = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
      b.writeln(' <manifest:file-entry manifest:full-path="$path" manifest:media-type="$mime"/>');
    }
    b.write('</manifest:manifest>');
    return b.toString();
  }

  /// Write the .odp file.
  static Future<String> writeOdp(
    List<Map<String, dynamic>> slides,
    String path,
  ) async {
    final bytes = buildOdpBytes(slides);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
