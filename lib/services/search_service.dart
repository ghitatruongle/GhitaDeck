/// Find & Replace across the deck (Track 57, FEAT 94).
///
/// Searches slide titles + HTML text; supports whole-word and
/// case-sensitive matching; replace-all across the deck returns the count
/// replaced and rewrites only the affected slides.
class SearchService {
  SearchService._();

  /// Find all occurrences of [query] in [slides]. Matches are reported
  /// against the concatenated searchable text of each slide (title + text
  /// content) so the UI can highlight and jump to the slide.
  static List<SearchMatch> findAll(
    List<Map<String, dynamic>> slides,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    if (query.isEmpty) return const [];
    final results = <SearchMatch>[];
    for (var i = 0; i < slides.length; i++) {
      final haystack = searchableText(slides[i]);
      final needle = caseSensitive ? query : query.toLowerCase();
      final src = caseSensitive ? haystack : haystack.toLowerCase();
      final re = RegExp(
        wholeWord ? r'\b' + RegExp.escape(needle) + r'\b' : RegExp.escape(needle),
      );
      for (final m in re.allMatches(src)) {
        results.add(SearchMatch(i, m.start, m.end));
      }
    }
    return results;
  }

  /// Text used for searching: title + stripped HTML.
  static String searchableText(Map<String, dynamic> slide) {
    final title = (slide['title'] ?? '').toString();
    final html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
    final text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return '$title $text';
  }

  /// Replace all occurrences in [slides]; returns (newSlides, count).
  static ({List<Map<String, dynamic>> slides, int count}) replaceAll(
    List<Map<String, dynamic>> slides,
    String query,
    String replacement, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    if (query.isEmpty) return (slides: slides, count: 0);
    var count = 0;
    final out = <Map<String, dynamic>>[];
    for (final slide in slides) {
      var html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
      var title = (slide['title'] ?? '').toString();
      var slideChanged = false;

      // Replace in title.
      final titleResult = _replaceIn(title, query, replacement,
          caseSensitive: caseSensitive, wholeWord: wholeWord);
      if (titleResult.$2 > 0) {
        title = titleResult.$1;
        count += titleResult.$2;
        slideChanged = true;
      }

      // Replace in text content only (not in tags/attributes).
      final textResult = _replaceInText(html, query, replacement,
          caseSensitive: caseSensitive, wholeWord: wholeWord);
      if (textResult.$2 > 0) {
        html = textResult.$1;
        count += textResult.$2;
        slideChanged = true;
      }

      out.add({
        ...slide,
        if (slideChanged) 'title': title,
        if (slideChanged) 'htmlContent': html,
      });
    }
    return (slides: out, count: count);
  }

  /// Replace inside plain text (title) — simple find/replace.
  static (String, int) _replaceIn(
    String text,
    String query,
    String replacement, {
    required bool caseSensitive,
    required bool wholeWord,
  }) {
    final needle = caseSensitive ? query : query.toLowerCase();
    final re = RegExp(
      wholeWord ? r'\b' + RegExp.escape(needle) + r'\b' : RegExp.escape(needle),
      caseSensitive: caseSensitive,
    );
    var count = 0;
    final out = text.replaceAllMapped(re, (m) {
      count++;
      return replacement;
    });
    return (out, count);
  }

  /// Replace only inside text nodes of HTML (between tags), never touching
  /// tags/attributes.
  static (String, int) _replaceInText(
    String html,
    String query,
    String replacement, {
    required bool caseSensitive,
    required bool wholeWord,
  }) {
    final tagRe = RegExp(r'<[^>]+>');
    final parts = <String>[];
    var last = 0;
    var count = 0;
    for (final m in tagRe.allMatches(html)) {
      parts.add(html.substring(last, m.start));
      parts.add(m.group(0)!);
      last = m.end;
    }
    parts.add(html.substring(last));
    // Odd indexes are tags (keep), even indexes are text (replace).
    for (var i = 0; i < parts.length; i += 2) {
      final result = _replaceIn(parts[i], query, replacement,
          caseSensitive: caseSensitive, wholeWord: wholeWord);
      parts[i] = result.$1;
      count += result.$2;
    }
    return (parts.join(), count);
  }
}

/// A match location inside one slide.
class SearchMatch {
  final int slideIndex;
  final int start;
  final int end;

  const SearchMatch(this.slideIndex, this.start, this.end);
}

