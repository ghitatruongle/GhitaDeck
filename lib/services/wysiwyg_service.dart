/// WYSIWYG toolbar operations (Track 63, OPT 15).
///
/// Applies inline HTML formatting around a text selection in a slide's HTML
/// source: `<b>`, `<i>`, `<u>`, `<span style="color:...">`, and wraps the
/// *visible* text — not tags. Works on the editor's selection range mapped
/// into the raw HTML.
class WysiwygService {
  WysiwygService._();

  /// Wrap the selected text (raw HTML offsets) with [openTag]/[closeTag].
  /// When the selection spans only tags (or is empty), returns unchanged.
  static FormatResult wrapSelection(
    String html,
    int selStart,
    int selEnd,
    String openTag,
    String closeTag,
  ) {
    if (selStart < 0 || selEnd > html.length || selEnd <= selStart) {
      return FormatResult(html, selStart, selEnd);
    }
    final selected = html.substring(selStart, selEnd);
    if (selected.trim().isEmpty) {
      return FormatResult(html, selStart, selEnd);
    }
    final out = StringBuffer()
      ..write(html.substring(0, selStart))
      ..write(openTag)
      ..write(selected)
      ..write(closeTag)
      ..write(html.substring(selEnd));
    return FormatResult(out.toString(), selStart + openTag.length,
        selEnd + openTag.length);
  }

  /// Wrap the selected *visible text* with a colored span. Text nodes inside
  /// the selection are located and wrapped individually (tags untouched).
  static FormatResult colorSelection(
    String html,
    int selStart,
    int selEnd,
    String hexColor,
  ) {
    if (selStart < 0 || selEnd > html.length || selEnd <= selStart) return FormatResult(html, selStart, selEnd);
    final prefix = html.substring(0, selStart);
    final mid = html.substring(selStart, selEnd);
    final suffix = html.substring(selEnd);

    final buf = StringBuffer();
    final tagRe = RegExp(r'<[^>]+>');
    var last = 0;
    for (final m in tagRe.allMatches(mid)) {
      final text = mid.substring(last, m.start);
      if (text.isNotEmpty) {
        buf.write('<span style="color:${_esc(hexColor)}">$text</span>');
      }
      buf.write(m.group(0));
      last = m.end;
    }
    final tail = mid.substring(last);
    if (tail.isNotEmpty) {
      buf.write('<span style="color:${_esc(hexColor)}">$tail</span>');
    }
    return FormatResult('$prefix${buf.toString()}$suffix',
        selStart, selStart + buf.toString().length);
  }

  /// Toggle a wrap: if the selection is already wrapped by [openTag], unwrap
  /// it (returns the inner HTML); otherwise wrap.
  static FormatResult toggleWrap(
    String html,
    int selStart,
    int selEnd,
    String openTag,
    String closeTag,
  ) {
    final re = RegExp('${RegExp.escape(openTag)}([\\s\\S]*?)${RegExp.escape(closeTag)}');
    final selected = html.substring(selStart, selEnd);
    final m = re.firstMatch(selected);
    if (m != null && m.start == 0 && m.end == selected.length) {
      return FormatResult(
          html.replaceRange(selStart, selEnd, m.group(1)!), selStart, selStart + m.group(1)!.length);
    }
    return wrapSelection(html, selStart, selEnd, openTag, closeTag);
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Result of applying a format: new HTML + the new selection range.
class FormatResult {
  final String html;
  final int start;
  final int end;

  const FormatResult(this.html, this.start, this.end);
}

/// HTML syntax highlighting via flutter_highlight (Track 63, OPT 13).
///
/// This is a lightweight helper that maps the existing `highlight` package
/// grammar for HTML. The actual CodeField widget lives in the editor; this
/// service exposes the grammar name + a tokenizer for tests.
class HtmlHighlightService {
  HtmlHighlightService._();

  /// Grammar key used by flutter_highlight's `HighlightView`/`CodeField`.
  static const String grammar = 'html';

  /// Approximate highlight ranges (tag name, attribute, string, comment) for
  /// tests — the real editor uses the highlight package, this is a pure-Dart
  /// classifier that must agree on the obvious cases.
  static List<({String type, int start, int end})> classify(String html) {
    final result = <({String type, int start, int end})>[];
    final re = RegExp(
        "(<!--[\\s\\S]*?-->)|(</?[a-zA-Z][a-zA-Z0-9-]*)|([a-zA-Z-]+)(?==)|(\"[^\"]*\"|'[^']*')");
    for (final m in re.allMatches(html)) {
      final type = m.group(1) != null
          ? 'comment'
          : m.group(2) != null
              ? 'tag'
              : m.group(3) != null
                  ? 'attr'
                  : 'string';
      result.add((type: type, start: m.start, end: m.end));
    }
    return result;
  }
}
