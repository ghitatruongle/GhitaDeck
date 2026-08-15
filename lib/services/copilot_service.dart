import 'package:http/http.dart' as http;

/// Copilot Creator (Track 55, FEAT 88/89).
///
/// Pure helpers for building decks from documents / URLs / outlines, plus a
/// deck Q&A index — no AI calls here; the caller (chat screen) feeds prompts
/// to the AI provider. Keeping the parsing/indexing local makes it testable.
class CopilotService {
  CopilotService._();

  /// Split a long document body into slides by headings, preserving the main
  /// ideas (PDF/Word text extraction feeds this; chunking keeps ~80 words per
  /// slide). Returns slide maps: {title, htmlContent}.
  static List<Map<String, dynamic>> slidesFromDocument(String text,
      {int maxSlides = 20}) {
    final cleaned = text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];

    // Prefer heading-based splitting; fall back to paragraph chunks.
    final headingRe = RegExp(r'^(#{1,4})\s+(.+)$', multiLine: true);
    final matches = headingRe.allMatches(cleaned).toList();
    if (matches.isNotEmpty) {
      final slides = <Map<String, dynamic>>[];
      for (var i = 0; i < matches.length && slides.length < maxSlides; i++) {
        final title = matches[i].group(2)!.trim();
        final start = matches[i].end;
        final end =
            i + 1 < matches.length ? matches[i + 1].start : cleaned.length;
        final body = cleaned.substring(start, end).trim();
        slides.add({
          'title': title,
          'htmlContent': _htmlSlide(title, body),
        });
      }
      return slides;
    }

    // No headings: chunk into ~6-sentence slides.
    final sentences =
        cleaned.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.isNotEmpty).toList();
    final slides = <Map<String, dynamic>>[];
    var i = 0;
    while (i < sentences.length && slides.length < maxSlides) {
      final chunk = <String>[];
      var words = 0;
      while (i < sentences.length && words < 80) {
        chunk.add(sentences[i]);
        words += sentences[i].split(' ').length;
        i++;
      }
      final joined = chunk.join(' ');
      final title = _firstWords(joined, 6);
      slides.add({
        'title': title,
        'htmlContent': _htmlSlide(title, joined),
      });
    }
    return slides;
  }

  /// Fetch a URL and extract meaningful text (title + paragraphs) for deck
  /// creation. Lightweight scrape; heavy extraction is Track 66.
  static Future<({String title, String text})> fetchUrlText(String url) async {
    final client = http.Client();
    try {
      final response =
          await client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (title: url, text: '');
      }
      final html = response.body;
      final titleMatch =
          RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
              .firstMatch(html);
      final title = titleMatch?.group(1)?.trim() ?? url;
      // Strip scripts/styles, then tags → text.
      var body = html.replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true,
          caseSensitive: false), ' ');
      body = body
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'&nbsp;'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return (title: title, text: body);
    } catch (_) {
      return (title: url, text: '');
    } finally {
      client.close();
    }
  }

  /// Build a per-slide text index for Q&A ("slide nào nói về X"). Maps the
  /// slide index → {title, text}.
  static List<Map<String, dynamic>> buildDeckIndex(
      List<Map<String, dynamic>> slides) {
    return [
      for (var i = 0; i < slides.length; i++)
        {
          'index': i,
          'title': (slides[i]['title'] ?? '').toString(),
          'text': _slideText(slides[i]),
        }
    ];
  }

  /// Find slides whose text matches the query (case-insensitive substring,
  /// plus simple token overlap). Returns slide indexes, best first.
  static List<int> searchDeckIndex(
      List<Map<String, dynamic>> index, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final qTokens = q.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    final scored = <({int index, int score})>[];
    for (final entry in index) {
      final text = '${entry['title']} ${entry['text']}'.toLowerCase();
      var score = 0;
      if (text.contains(q)) score += 5;
      for (final t in qTokens) {
        if (text.contains(t)) score++;
      }
      if (score > 0) {
        scored.add((index: entry['index'] as int, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final s in scored) s.index];
  }

  /// 5-line summary prompt input builder for the current deck.
  static String buildDeckSummaryPrompt(List<Map<String, dynamic>> slides) {
    final buf = StringBuffer('Summarize this presentation in 5 lines:\n');
    for (var i = 0; i < slides.length && i < 30; i++) {
      final title = (slides[i]['title'] ?? 'Slide ${i + 1}').toString();
      final text = _slideText(slides[i]);
      final snippet = text.length > 120 ? text.substring(0, 120) : text;
      buf.writeln('$i. $title — $snippet');
    }
    return buf.toString();
  }

  /// Suggest 3 expansion directions for one slide.
  static String buildExpandPrompt(Map<String, dynamic> slide) {
    final title = (slide['title'] ?? '').toString();
    final text = _slideText(slide);
    return 'The slide "$title" contains: ${text.isEmpty ? '(empty)' : text}\n'
        'Suggest 3 ways to expand this slide into a richer section. '
        'Return as a numbered list with a short description each.';
  }

  // ---------------------------------------------------------------------------

  static String _htmlSlide(String title, String body) {
    final escTitle = _esc(title);
    final buf = StringBuffer('<h1>$escTitle</h1>');
    // Chunk body into bullet-ish lines (split on semicolons or sentence ends).
    final sentences =
        body.split(RegExp(r'(?<=[.;!?])\s+')).where((s) => s.trim().isNotEmpty);
    var count = 0;
    for (final s in sentences) {
      if (count >= 5) break;
      final t = s.trim();
      if (t.length < 12) continue;
      buf.writeln('<ul><li>${_esc(t)}</li></ul>');
      count++;
    }
    return buf.toString();
  }

  static String _slideText(Map<String, dynamic> slide) {
    final html = (slide['htmlContent'] ?? '').toString();
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _firstWords(String s, int n) {
    final words = s.split(' ').where((w) => w.isNotEmpty).toList();
    final take = words.take(n).join(' ');
    return take.length > 60 ? '${take.substring(0, 60)}…' : take;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
