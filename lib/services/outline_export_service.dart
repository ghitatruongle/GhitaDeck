/// Outline export (Track 43, FEAT 71).
///
/// Extracts the outline of a deck — every slide's title plus its body
/// paragraphs/lists — and writes a Word-compatible **RTF** file. RTF is a
/// plain-text format, so the export is fully deterministic and testable,
/// and opens directly in Word/WordPad/WPS.
library;

import 'dart:io';

import 'ppt_generator.dart';

class OutlineExportService {
  OutlineExportService._();

  /// Outline level of a slide (1 = highest).
  static int slideLevel(Map<String, dynamic> slide) {
    final lvl = (slide['outlineLevel'] as num?)?.toInt() ?? 1;
    return lvl.clamp(1, 3);
  }

  /// Collect the outline entries of [slides]: title + body text blocks.
  static List<OutlineEntry> buildOutline(List<Map<String, dynamic>> slides) {
    final entries = <OutlineEntry>[];
    for (final slide in slides) {
      final title =
          (slide['title'] ?? 'Slide ${entries.length + 1}').toString().trim();
      final body = <String>[];
      final html = (slide['htmlContent'] ?? '').toString();
      if (html.trim().isNotEmpty) {
        for (final block in PPTGenerator.parseHtmlContentFull(html)) {
          final type = block['type'];
          if (type == 'text') {
            for (final run in (block['paragraphs'] as List? ?? const [])
                .cast<Map<String, String>>()) {
              final t = (run['text'] ?? '').trim();
              if (t.isNotEmpty) body.add(t);
            }
          } else if (type == 'list') {
            for (final run in (block['items'] as List? ?? const [])
                .cast<Map<String, String>>()) {
              final t = (run['text'] ?? '').trim();
              if (t.isNotEmpty) body.add(t);
            }
          }
        }
      }
      entries.add(OutlineEntry(
        level: slideLevel(slide),
        title: title,
        body: body,
      ));
    }
    return entries;
  }

  /// RTF document for [entries].
  static String toRtf(List<OutlineEntry> entries) {
    final b = StringBuffer();
    b.writeln(r'{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}');
    b.writeln(r'\viewkind4\uc1\pard\f0\fs24');
    for (final e in entries) {
      // Title: bold, sized by outline level.
      switch (e.level) {
        case 1:
          b.writeln(r'{\b\fs40 ' + _rtfText(e.title) + r'}' + r'\par');
        case 2:
          b.writeln(r'{\b\fs32 ' + _rtfText(e.title) + r'}' + r'\par');
        default:
          b.writeln(r'{\b\fs28 ' + _rtfText(e.title) + r'}' + r'\par');
      }
      for (final line in e.body) {
        b.writeln(r'\li360\fs24 ' + _rtfText(line) + r'\par');
      }
    }
    b.write('}');
    return b.toString();
  }

  /// Escape text for RTF: backslash, braces, and non-ASCII → \uN? escapes
  /// (so Vietnamese survives in Word).
  static String _rtfText(String text) {
    final b = StringBuffer();
    for (final unit in text.runes) {
      if (unit == 0x5C) {
        b.write(r'\\');
      } else if (unit == 0x7B) {
        b.write(r'\{');
      } else if (unit == 0x7D) {
        b.write(r'\}');
      } else if (unit < 0x80) {
        b.writeCharCode(unit);
      } else {
        // \uN? with the low surrogate count suffix (single 16-bit unit).
        b.write('\\u$unit?');
      }
    }
    return b.toString();
  }

  /// Write [entries] as an .rtf file at [path].
  static Future<String> writeRtf(
    List<Map<String, dynamic>> slides,
    String path,
  ) async {
    final entries = buildOutline(slides);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(toRtf(entries), flush: true);
    return file.path;
  }
}

/// One outline entry (a slide's title + body lines).
class OutlineEntry {
  final int level;
  final String title;
  final List<String> body;

  const OutlineEntry({
    required this.level,
    required this.title,
    required this.body,
  });
}
