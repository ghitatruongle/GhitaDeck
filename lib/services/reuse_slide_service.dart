import 'dart:convert';

/// Slide reuse (Track 51, FEAT 85).
///
/// Imports slides from another presentation into the current deck. Sources:
///
/// * **.ghita bundle** — a JSON document with a `slides` array of slide maps
///   (the app's own project format).
/// * **Raw HTML / plain text** — split on `---` separators or `<h1>`/`<h2>`
///   headings into slides (a pragmatic stand-in until a full PPTX importer
///   lands in the M9/M10 import tracks — documented dependency).
///
/// "Keep original formatting" keeps the imported slide's HTML/style as-is;
/// "use current theme" rewrites the HTML to the deck's `<h1>`/`<p>`/`<ul>`
/// baseline so the imported content adopts the current theme.
class ReuseSlideService {
  ReuseSlideService._();

  /// Parse a `.ghita` bundle (JSON with a `slides` list). Returns an error
  /// message when the document isn't a valid bundle.
  static ({List<Map<String, dynamic>> slides, String? error})
      parseBundle(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map || decoded['slides'] is! List) {
        return (slides: const [], error: 'Not a .ghita bundle');
      }
      final result = <Map<String, dynamic>>[];
      for (final item in decoded['slides'] as List) {
        if (item is Map) {
          final slide = Map<String, dynamic>.from(item);
          // Normalize: importers may store htmlContent under a different key.
          if (slide['htmlContent'] == null && slide['html'] != null) {
            slide['htmlContent'] = slide['html'];
          }
          result.add(slide);
        }
      }
      return (slides: result, error: result.isEmpty ? 'No slides found' : null);
    } catch (_) {
      return (slides: const [], error: 'Invalid JSON');
    }
  }

  /// Split plain text (or raw HTML) into slides. Separators:
  ///   * `---` on its own line
  ///   * `<h1>` headings (each heading starts a new slide)
  ///   * `<h2>` headings when there is no `<h1>`
  static List<Map<String, dynamic>> slidesFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    final slides = <Map<String, dynamic>>[];

    if (trimmed.contains('<h1') || trimmed.contains('<h2')) {
      final parts = trimmed.split(RegExp(r'(?=<h[12][ >])'));
      for (final part in parts) {
        final cleaned = part.trim();
        if (cleaned.isEmpty) continue;
        final titleMatch =
            RegExp(r'<h[12][^>]*>(.*?)</h[12]>', dotAll: true)
                .firstMatch(cleaned);
        final title = titleMatch?.group(1) == null
            ? 'Slide ${slides.length + 1}'
            : _stripTags(titleMatch!.group(1)!).trim();
        slides.add({'title': title, 'htmlContent': cleaned});
      }
    } else {
      final chunks = trimmed.split(RegExp(r'\n---\s*\n'));
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i].trim();
        if (chunk.isEmpty) continue;
        final lines = chunk.split('\n');
        final title = lines.first.trim().replaceAll(RegExp(r'^#+\s*'), '');
        final body = lines.skip(1).join('\n').trim();
        final html = StringBuffer()
          ..writeln('<h1>${_esc(title)}</h1>');
        for (final line in body.split('\n')) {
          final t = line.trim();
          if (t.startsWith('- ') || t.startsWith('* ')) {
            html.writeln('<ul><li>${_esc(t.substring(2))}</li></ul>');
          } else if (t.isNotEmpty) {
            html.writeln('<p>${_esc(t)}</p>');
          }
        }
        slides.add({'title': title, 'htmlContent': html.toString()});
      }
    }
    return slides;
  }

  /// Keep the imported HTML as-is (original formatting).
  static Map<String, dynamic> keepOriginal(Map<String, dynamic> slide) =>
      Map<String, dynamic>.from(slide);

  /// Rewrite the slide HTML to the current deck's baseline structure
  /// (h1/p/ul) so imported content adopts the active theme.
  static Map<String, dynamic> useCurrentTheme(Map<String, dynamic> slide) {
    final html = (slide['htmlContent'] ?? '').toString();
    final title = (slide['title'] ?? '').toString();
    // Extract the first heading as the title if the title is blank.
    final effectiveTitle =
        title.trim().isEmpty ? _firstHeading(html) ?? '' : title;

    // Walk text nodes in document order, keeping the enclosing tag context so
    // list items stay lists and everything else becomes a paragraph.
    final buffer = StringBuffer()
      ..writeln('<h1>${_esc(effectiveTitle)}</h1>');
    var inList = false;
    void closeList() {
      if (inList) {
        buffer.writeln('</ul>');
        inList = false;
      }
    }

    var index = 0;
    final textNodes = _textNodesWithTag(html);
    for (final node in textNodes) {
      final text = node.text.trim();
      if (text.isEmpty) continue;
      if (node.tag == 'li') {
        if (!inList) {
          buffer.writeln('<ul>');
          inList = true;
        }
        buffer.writeln('  <li>${_esc(text)}</li>');
      } else if (node.tag == 'h1' || node.tag == 'h2' || node.tag == 'h3') {
        closeList();
        if (index > 0) {
          // Only the first heading becomes the title; later headings are
          // demoted to paragraphs so the theme stays consistent.
          buffer.writeln('<p>${_esc(text)}</p>');
        }
      } else {
        closeList();
        buffer.writeln('<p>${_esc(text)}</p>');
      }
      index++;
    }
    closeList();

    return {
      ...slide,
      'title': effectiveTitle.isEmpty ? 'Imported' : effectiveTitle,
      'htmlContent': buffer.toString(),
    };
  }

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  static String? _firstHeading(String html) {
    for (final m in RegExp(r'<h[12][^>]*>(.*?)</h[12]>', dotAll: true)
        .allMatches(html)) {
      final t = _stripTags(m.group(1) ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  /// Text runs with the nearest enclosing tag, in document order.
  static List<({String tag, String text})> _textNodesWithTag(String html) {
    final result = <({String tag, String text})>[];
    final tagRe = RegExp(r'<([a-zA-Z][a-zA-Z0-9]*)[^>]*>|</[a-zA-Z][a-zA-Z0-9]*>');
    final stack = <String>[];
    var last = 0;
    for (final m in tagRe.allMatches(html)) {
      final between = html.substring(last, m.start);
      if (between.trim().isNotEmpty) {
        result.add((tag: stack.isEmpty ? '' : stack.last, text: between));
      }
      final raw = m.group(0)!;
      if (raw.startsWith('</')) {
        if (stack.isNotEmpty) stack.removeLast();
      } else {
        stack.add((m.group(1) ?? '').toLowerCase());
      }
      last = m.end;
    }
    final tail = html.substring(last);
    if (tail.trim().isNotEmpty) {
      result.add((tag: stack.isEmpty ? '' : stack.last, text: tail));
    }
    return result;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
