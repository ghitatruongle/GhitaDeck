/// Deck translation (Track 56, FEAT 91).
///
/// Translates a whole deck through an AI callback while preserving the HTML
/// structure: only the text *nodes* are translated, tags/classes/attributes
/// stay untouched. Supports preview-then-apply per slide or batch.
class DeckTranslationService {
  DeckTranslationService._();

  static const List<String> supportedLanguages = [
    'vi', 'en', 'fr', 'de', 'es', 'pt', 'zh', 'ja',
  ];

  static const Map<String, String> languageNames = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'pt': 'Português',
    'zh': '中文',
    'ja': '日本語',
  };

  /// Extract text nodes from HTML preserving their positions.
  static List<({int start, int end, String text})> textNodes(String html) {
    final result = <({int start, int end, String text})>[];
    final tagRe = RegExp(r'<[^>]+>');
    var last = 0;
    for (final m in tagRe.allMatches(html)) {
      final between = html.substring(last, m.start);
      if (between.trim().isNotEmpty) {
        result.add((start: last, end: m.start, text: between));
      }
      last = m.end;
    }
    if (last < html.length) {
      final tail = html.substring(last);
      if (tail.trim().isNotEmpty) {
        result.add((start: last, end: html.length, text: tail));
      }
    }
    return result;
  }

  /// Rebuild the HTML with translated text nodes. [translations] must be the
  /// same length as [textNodes]; each entry is the translated text (or null
  /// to keep the original).
  static String applyTranslations(
      String html, List<String?> translations) {
    final nodes = textNodes(html);
    if (nodes.length != translations.length) return html;
    final buf = StringBuffer();
    var pos = 0;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      buf.write(html.substring(pos, node.start));
      buf.write(translations[i] ?? node.text);
      pos = node.end;
    }
    buf.write(html.substring(pos));
    return buf.toString();
  }

  /// Build the AI prompt for one slide: instruct to translate only text,
  /// keep tags/classes.
  static String buildTranslationPrompt(String html, String targetLang) {
    final name = languageNames[targetLang] ?? targetLang;
    return 'Translate the following slide HTML into $name. '
        'Translate ONLY the visible text; keep every tag, attribute and '
        'class name exactly as-is. Return ONLY the translated HTML '
        'fragment, no explanation.\n\n$html';
  }

  /// Approximate progress callback signature used by the UI.
  static ({int done, int total}) progress(int done, int total) =>
      (done: done, total: total);
}
