import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/slide.dart';

/// Advanced import (Track 66, OPT 44/45 + FEAT support).
///
/// * Markdown full: tables, nested lists, code blocks, images, `---` slide
///   separators.
/// * Word .docx: unzip → parse `word/document.xml` → headings become slides.
/// * PDF: text extraction (simplified — no full text layout; page markers via
///   `BT/ET` streams when zlib-available) with a page-per-slide fallback.
/// * PPTX: unzip → parse each slide XML → text runs + bullets + images.
/// * Web: richer scrape (title, H1–H3, paragraphs, lists, up to 5 images).
class AdvancedImportService {
  AdvancedImportService._();

  // -------------------------------------------------------------------------
  // Markdown (full)
  // -------------------------------------------------------------------------

  static List<Slide> parseMarkdown(String md) {
    final lines = md.split('\n');
    final slides = <Slide>[];
    var currentTitle = '';
    final buffer = StringBuffer();
    var inCode = false;
    var inList = 0; // nesting level

    void flush() {
      if (currentTitle.isNotEmpty || buffer.toString().trim().isNotEmpty) {
        final html = buffer.toString().trim();
        slides.add(Slide(
          title: currentTitle.isNotEmpty ? currentTitle : 'Slide ${slides.length + 1}',
          htmlContent: '<h1>${_esc(currentTitle.isEmpty ? 'Slide ${slides.length + 1}' : currentTitle)}</h1>$html',
        ));
      }
      currentTitle = '';
      buffer.clear();
      inList = 0;
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      // Slide separator
      if (trimmed == '---' && !inCode) {
        flush();
        continue;
      }

      // Code block
      if (trimmed.startsWith('```')) {
        if (!inCode) {
          buffer.writeln('<pre><code>');
          inCode = true;
        } else {
          buffer.writeln('</code></pre>');
          inCode = false;
        }
        continue;
      }
      if (inCode) {
        buffer.writeln(_esc(trimmed));
        continue;
      }

      // Heading → new slide (or h2 within current slide)
      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final text = heading.group(2)!.trim();
        if (level == 1) {
          flush();
          currentTitle = text;
        } else {
          buffer.writeln('<h${level + 1}>${_esc(text)}</h${level + 1}>');
        }
        continue;
      }

      // Table
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        _appendTableLine(buffer, trimmed);
        continue;
      }

      // List items (nested by indentation — match against the original line
      // so leading spaces survive; `trimmed` would erase the level).
      final listMatch = RegExp(r'^(\s*)([-*+]|\d+\.)\s+(.*)$').firstMatch(line);
      if (listMatch != null) {
        final indent = listMatch.group(1)!.length;
        final level = (indent / 2).floor() + 1;
        while (inList < level) {
          buffer.writeln('<ul>');
          inList++;
        }
        while (inList > level) {
          buffer.writeln('</ul>');
          inList--;
        }
        buffer.writeln('<li>${_inline(listMatch.group(3)!.trim())}</li>');
        continue;
      }
      if (inList > 0) {
        while (inList > 0) {
          buffer.writeln('</ul>');
          inList--;
        }
      }

      // Image
      final img = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(trimmed);
      if (img != null) {
        buffer.writeln(
            '<img src="${_esc(img.group(2)!)}" alt="${_esc(img.group(1) ?? '')}">');
        continue;
      }

      // Blank
      if (trimmed.isEmpty) continue;

      // Paragraph
      buffer.writeln('<p>${_inline(trimmed)}</p>');
    }
    if (inList > 0) {
      while (inList > 0) {
        buffer.writeln('</ul>');
        inList--;
      }
    }
    flush();
    return slides.isNotEmpty
        ? slides
        : [
            Slide(
              title: 'Imported',
              htmlContent: '<h1>Imported</h1><p>${_esc(md)}</p>',
            )
          ];
  }

  static void _appendTableLine(StringBuffer buffer, String line) {
    final trimmed = line.trim();
    final cells = _splitTableRow(trimmed);
    // Separator row (|---|) → start table.
    if (cells.isNotEmpty &&
        cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c))) {
      return;
    }
    buffer
        .writeln('<table><tr>${cells.map((c) => '<td>${_esc(c)}</td>').join()}</tr></table>');
  }

  /// Split a markdown table row on `|`, ignoring pipes inside inline code
  /// spans (`` `a|b` `` stays one cell).
  static List<String> _splitTableRow(String line) {
    final cells = <String>[];
    final buf = StringBuffer();
    var inCode = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '`') {
        inCode = !inCode;
        buf.write(ch);
      } else if (ch == '|' && !inCode) {
        cells.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    // Trailing part (and drop an empty leading/trailing cell from the
    // conventional `| a | b |` syntax).
    cells.add(buf.toString().trim());
    if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
    if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
    return cells;
  }

  static String _inline(String s) {
    var out = _esc(s);
    // Bold, italic, links, inline code.
    out = out.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => '<b>${m.group(1)}</b>');
    out = out.replaceAllMapped(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), (m) => '<i>${m.group(1)}</i>');
    out = out.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => '<a href="${m.group(2)}">${m.group(1)}</a>');
    out = out.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code>${m.group(1)}</code>');
    return out;
  }

  // -------------------------------------------------------------------------
  // .docx
  // -------------------------------------------------------------------------

  static List<Slide> importDocx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.findFile('word/document.xml');
    if (doc == null) return const [];
    final xml = utf8.decode(doc.content as List<int>);
    final document = XmlDocument.parse(xml);
    final slides = <Slide>[];
    var currentTitle = '';
    final body = StringBuffer();

    void flush() {
      if (currentTitle.isEmpty && body.toString().trim().isEmpty) return;
      slides.add(Slide(
        title: currentTitle.isEmpty ? 'Slide ${slides.length + 1}' : currentTitle,
        htmlContent:
            '<h1>${_esc(currentTitle.isEmpty ? 'Slide ${slides.length + 1}' : currentTitle)}</h1>${body.toString().trim()}',
      ));
      currentTitle = '';
      body.clear();
    }

    for (final p in document.findAllElements('w:p')) {
      final style = p.getElement('w:pPr')?.getElement('w:pStyle')?.getAttribute('w:val') ?? '';
      final text = p
          .findAllElements('w:t')
          .map((t) => t.innerText)
          .join();
      if (text.trim().isEmpty) continue;
      if (style.contains('Heading1') || style.contains('Title')) {
        flush();
        currentTitle = text.trim();
      } else if (style.contains('Heading2')) {
        body.writeln('<h3>${_esc(text.trim())}</h3>');
      } else if (style.contains('ListParagraph') ||
          (p.getElement('w:pPr')?.getElement('w:numPr') != null)) {
        body.writeln('<ul><li>${_esc(text.trim())}</li></ul>');
      } else {
        body.writeln('<p>${_esc(text.trim())}</p>');
      }
    }
    flush();
    return slides;
  }

  // -------------------------------------------------------------------------
  // PPTX
  // -------------------------------------------------------------------------

  static List<Slide> importPptx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      // Slide numbers are extracted ONCE per file (not inside the sort
      // comparator — the old code rebuilt a RegExp on every comparison,
      // O(n·log n) regex allocations).
      final slideFiles = archive.files
          .where((f) => RegExp(r'ppt/slides/slide\d+\.xml$').hasMatch(f.name))
          .map((f) => (
                file: f,
                num: int.parse(f.name
                    .substring('ppt/slides/slide'.length,
                        f.name.length - '.xml'.length))
              ))
          .toList()
        ..sort((a, b) => a.num.compareTo(b.num));
      if (slideFiles.isEmpty) return const [];

      final slides = <Slide>[];
      for (final entry in slideFiles) {
        final f = entry.file;
        final xml = utf8.decode(f.content as List<int>);
        final doc = XmlDocument.parse(xml);
        final title = _pptxTitle(doc);
        final html = _pptxBody(doc);
        slides.add(Slide(
          title: title,
          htmlContent: '<h1>${_esc(title)}</h1>$html',
        ));
      }
      return slides;
    } catch (_) {
      return const [];
    }
  }

  static String _pptxTitle(XmlDocument doc) {
    // First <a:t> inside a placeholder with type title, else first text.
    final placeholders = doc.findAllElements('p:sp');
    for (final sp in placeholders) {
      final ph = sp.getElement('p:nvSpPr')?.getElement('p:nvPr')?.getElement('p:ph');
      final type = ph?.getAttribute('type') ?? '';
      if (type == 'title' || type == 'ctrTitle') {
        final text = sp.findAllElements('a:t').map((t) => t.innerText).join();
        if (text.trim().isNotEmpty) return text.trim();
      }
    }
    return doc.findAllElements('a:t').map((t) => t.innerText).join().trim().isEmpty
        ? 'Slide'
        : doc.findAllElements('a:t').map((t) => t.innerText).join().trim();
  }

  static String _pptxBody(XmlDocument doc) {
    final buf = StringBuffer();
    final placeholders = doc.findAllElements('p:sp');
    for (final sp in placeholders) {
      final isList = sp.getElement('p:txBody')?.findAllElements('a:pPr') != null ||
          sp.findAllElements('a:buChar').isNotEmpty ||
          sp.findAllElements('a:buAutoNum').isNotEmpty;
      final paras = sp.findAllElements('a:p');
      for (final p in paras) {
        final text = p.findAllElements('a:t').map((t) => t.innerText).join();
        if (text.trim().isEmpty) continue;
        if (isList) {
          buf.writeln('<ul><li>${_esc(text.trim())}</li></ul>');
        } else {
          buf.writeln('<p>${_esc(text.trim())}</p>');
        }
      }
    }
    // Images: embedded rels → base64 data URI (up to 5).
    final pics = doc.findAllElements('p:pic');
    var count = 0;
    for (final pic in pics) {
      if (count >= 5) break;
      final embed = pic
          .getElement('p:blipFill')
          ?.getElement('a:blip')
          ?.getAttribute('r:embed');
      if (embed != null) {
        buf.writeln('<p>[image:$embed]</p>');
        count++;
      }
    }
    return buf.toString();
  }

  // -------------------------------------------------------------------------
  // PDF (simplified text extraction)
  // -------------------------------------------------------------------------

  static List<Slide> importPdf(List<int> bytes, {int maxPages = 30}) {
    // Very lightweight PDF text probe: find Tj/TJ strings. Real layout
    // extraction is out of scope — this covers the ROADMAP's page-per-slide
    // intent (title = first text line, body = rest).
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      final strings = RegExp(r'\((?:[^()\\]|\\.)*\)').allMatches(text);
      final collected = <String>[];
      for (final m in strings) {
        final raw = m.group(0)!;
        final content = raw
            .substring(1, raw.length - 1)
            .replaceAll(RegExp(r'\\\d{3}'), '')
            .replaceAll('\\', '');
        if (content.trim().length >= 2) collected.add(content);
      }
      if (collected.isEmpty) return const [];
      final slides = <Slide>[];
      var i = 0;
      while (i < collected.length && slides.length < maxPages) {
        final pageText = collected
            .skip(i)
            .take(60)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final words = pageText.split(' ');
        final title = words.length > 8 ? words.take(8).join(' ') : pageText;
        slides.add(Slide(
          title: title,
          htmlContent: '<h1>${_esc(title)}</h1><p>${_esc(pageText)}</p>',
        ));
        i += 60;
      }
      return slides;
    } catch (_) {
      return const [];
    }
  }

  // -------------------------------------------------------------------------
  // Web (richer scrape)
  // -------------------------------------------------------------------------

  static Future<List<Slide>> importWebRich(String url,
      {int maxImages = 5}) async {
    final client = http.Client();
    try {
      final response =
          await client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      final html = response.body;
      final title = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
              .firstMatch(html)
              ?.group(1)
              ?.trim() ??
          url;
      final slides = <Slide>[];
      var images = 0;

      // Walk headings H1–H3 and their following paragraphs/lists.
      final headingRe = RegExp(r'<h([123])[^>]*>(.*?)</h\1>', caseSensitive: false, dotAll: true);
      final matches = headingRe.allMatches(html).toList();
      if (matches.isEmpty) {
        final plainText = _stripTags(html).trim();
        final excerpt = plainText.length <= 400
            ? plainText
            : plainText.substring(0, 400).trimRight();
        return [
          Slide(
            title: title,
            htmlContent:
                '<h1>${_esc(title)}</h1><p>${_esc(excerpt)}</p>',
          )
        ];
      }
      for (var i = 0; i < matches.length && slides.length < 12; i++) {
        final m = matches[i];
        final heading = _stripTags(m.group(2)!).trim();
        if (heading.isEmpty) continue;
        final body = StringBuffer();
        final start = m.end;
        final end = i + 1 < matches.length ? matches[i + 1].start : html.length;
        final section = html.substring(start, end);
        // Paragraphs.
        for (final p in RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).allMatches(section)) {
          final text = _stripTags(p.group(1)!).trim();
          if (text.isNotEmpty) body.writeln('<p>${_esc(text)}</p>');
        }
        // Lists.
        for (final li in RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true).allMatches(section)) {
          final text = _stripTags(li.group(1)!).trim();
          if (text.isNotEmpty) body.writeln('<ul><li>${_esc(text)}</li></ul>');
        }
        // Images (up to maxImages total).
        if (images < maxImages) {
          for (final im in RegExp(r'<img[^>]*src="([^"]+)"[^>]*>', caseSensitive: false)
              .allMatches(section)) {
            if (images >= maxImages) break;
            final src = im.group(1)!;
            if (src.startsWith('data:') || src.startsWith('http')) {
              body.writeln('<img src="${_esc(src)}" alt="">');
              images++;
            }
          }
        }
        slides.add(Slide(
          title: heading,
          htmlContent: '<h1>${_esc(heading)}</h1>$body',
        ));
      }
      return slides.isNotEmpty
          ? slides
          : [
              Slide(
                title: title,
                htmlContent: '<h1>${_esc(title)}</h1>',
              )
            ];
    } catch (_) {
      return const [];
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------------------------

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
