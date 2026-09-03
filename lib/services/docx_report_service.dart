import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'export_primitives.dart';
import 'outline_export_service.dart';

/// DOCX report export (N1, Track 03 v2.0.5) — a Word report built from the
/// deck outline: title + body paragraphs per slide, optional speaker notes
/// and an optional numbered slide list.
///
/// The package is a minimal, strictly-valid WordprocessingML document
/// (ECMA-376): `[Content_Types].xml` + `_rels/.rels` + `word/document.xml` +
/// `docProps/core.xml`. No styles/theme parts are referenced, so nothing
/// external can break the open — formatting is direct (bold/size runs), which
/// Word and LibreOffice both accept without a repair prompt. XML is built
/// with [XmlBuilder] so Vietnamese text and ampersands/angle brackets are
/// escaped correctly.
class DocxReportService {
  DocxReportService._();

  /// Build the in-memory DOCX package bytes for [slides].
  ///
  /// [slides] are `Slide.toMap()` maps (title/htmlContent/notes/outlineLevel).
  /// [onProgress] receives per-slide fractions and [cancelToken] interrupts
  /// between slides — DOCX export runs on the worker isolate (B10).
  static Uint8List buildDocx(
    List<Map<String, dynamic>> slides, {
    bool includeNotes = true,
    bool includeSlideList = true,
    String? documentTitle,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) {
    if (slides.isEmpty) {
      throw ArgumentError.value(slides, 'slides', 'No slides to report');
    }
    final outline = OutlineExportService.buildOutline(slides);
    final title = documentTitle ?? outline.first.title;

    final docBody = XmlBuilder();
    docBody.element('w:document', nest: () {
      docBody.attribute('xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
      docBody.element('w:body', nest: () {
        // Document title.
        _paragraph(docBody, title, bold: true, size: 36, center: true);
        _spacer(docBody);
        for (var i = 0; i < outline.length; i++) {
          cancelToken?.throwIfCancelled();
          onProgress?.call(ExportProgressBudget.forSlide(i, outline.length));
          final entry = outline[i];
          // Slide heading — size follows the deck outline level (B12:
          // level 1 is the largest, deeper levels smaller).
          final headingSize = switch (entry.level) {
            1 => 30,
            2 => 28,
            _ => 26,
          };
          _paragraph(docBody, entry.title, bold: true, size: headingSize);
          for (final line in entry.body) {
            _paragraph(docBody, line, size: 22);
          }
          if (includeNotes) {
            final notes = (slides[i]['notes'] ?? '').toString().trim();
            if (notes.isNotEmpty) {
              _paragraph(docBody, notes, italic: true, size: 20);
            }
          }
          _spacer(docBody);
        }
        if (includeSlideList) {
          _paragraph(docBody, '\u00A0', size: 22);
          _paragraph(docBody, '—', size: 22);
          _spacer(docBody);
          for (var i = 0; i < outline.length; i++) {
            _paragraph(
                docBody, '${i + 1}. ${outline[i].title}', size: 22);
          }
        }
        // Default A4 section — no sectPr means Word applies the template's
        // own defaults; an explicit one keeps the report deterministic.
        docBody.element('w:sectPr', nest: () {
          docBody.element('w:pgSz', nest: () {
            docBody.attribute('w:w', '11906');
            docBody.attribute('w:h', '16838');
          });
        });
      });
    });

    final coreXml = XmlBuilder();
    coreXml.element('cp:coreProperties', nest: () {
      coreXml.attribute('xmlns:cp',
          'http://schemas.openxmlformats.org/package/2006/metadata/core-properties');
      coreXml.attribute('xmlns:dc', 'http://purl.org/dc/elements/1.1/');
      coreXml.element('dc:title', nest: () {
        // B11: the title must pass the same control-char strip as every
        // other run text — a control char here makes Word claim the whole
        // document is "unreadable content".
        coreXml.text(_cleanText(title));
      });
      coreXml.element('dc:creator', nest: () {
        coreXml.text('Ghita PPT Converter');
      });
    });

    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    add('[Content_Types].xml', _contentTypesXml());
    add('_rels/.rels', _dotRelsXml());
    add('word/document.xml', docBody.buildDocument().toXmlString());
    add('docProps/core.xml', coreXml.buildDocument().toXmlString());
    final encoded = ZipEncoder().encode(archive, level: 9);
    return Uint8List.fromList(encoded ?? const []);
  }

  /// Writes the report to [outputPath] (creating parent directories) and
  /// returns the path.
  static Future<String> exportReport(
    List<Map<String, dynamic>> slides,
    String outputPath, {
    bool includeNotes = true,
    bool includeSlideList = true,
    String? documentTitle,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final bytes = buildDocx(
      slides,
      includeNotes: includeNotes,
      includeSlideList: includeSlideList,
      documentTitle: documentTitle,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    cancelToken?.throwIfCancelled();
    onProgress?.call(ExportProgressBudget.finalizing(slides.length));
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return outputPath;
  }

  static String _contentTypesXml() => '<?xml version="1.0" encoding="UTF-8" '
      'standalone="yes"?>\n'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
      'package.relationships+xml"/><Default Extension="xml" ContentType='
      '"application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.'
      'openxmlformats-package.core-properties+xml"/></Types>';

  static String _dotRelsXml() => '<?xml version="1.0" encoding="UTF-8" '
      'standalone="yes"?>\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/'
      '2006/relationships/officeDocument" Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/'
      'package/2006/relationships/metadata/core-properties" '
      'Target="docProps/core.xml"/></Relationships>';

  static void _paragraph(
    XmlBuilder b,
    String text, {
    bool bold = false,
    bool italic = false,
    int size = 22,
    bool center = false,
  }) {
    final clean = _cleanText(text);
    if (clean.isEmpty) {
      // Keep the paragraph as an empty line so spacing stays stable.
      b.element('w:p', nest: () => b.element('w:r', nest: () {}));
      return;
    }
    b.element('w:p', nest: () {
      if (center) {
        b.element('w:pPr', nest: () {
          b.element('w:jc', nest: () => b.attribute('w:val', 'center'));
        });
      }
      b.element('w:r', nest: () {
        if (bold || italic) {
          b.element('w:rPr', nest: () {
            if (bold) b.element('w:b', nest: () {});
            if (italic) b.element('w:i', nest: () {});
            b.element('w:sz', nest: () => b.attribute('w:val', '$size'));
          });
        }
        b.element('w:t', nest: () {
          b.attribute('xml:space', 'preserve');
          b.text(clean);
        });
      });
    });
  }

  static void _spacer(XmlBuilder b) => b.element('w:p', nest: () {});

  /// Strips XML-1.0-forbidden control characters and collapses newlines to
  /// spaces inside a paragraph so Word never refuses the run text.
  static String _cleanText(String raw) {
    final out = StringBuffer();
    final sanitized = raw.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    for (final unit in sanitized.codeUnits) {
      if (unit == 0x09 || unit == 0x0A || unit == 0x0D || unit >= 0x20) {
        out.writeCharCode(unit);
      }
    }
    return out.toString().trimRight();
  }
}
