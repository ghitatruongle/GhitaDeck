/// AI output guard (Track 52, OPT 38).
///
/// Validates and sanitizes AI-generated slide HTML before it lands in the
/// deck:
///
/// * strips dangerous tags (`script`, `iframe`, `object`, `embed`,
///   `link`, `meta`, `base`, `form`, `input`, `button`, `select`,
///   `textarea`) and event handlers;
/// * enforces a size cap (default 100 KB);
/// * auto-shrinks over-limit HTML by removing duplicate class attributes;
/// * checks the HTML is balanced enough to parse and can auto-repair trivial
///   mismatches.
class AIHtmlGuard {
  AIHtmlGuard._();

  static const int defaultMaxBytes = 100 * 1024;

  static final RegExp _dangerousTagRe = RegExp(
    r'<\s*(script|iframe|object|embed|link|meta|base|form|input|button|select|textarea)\b[^>]*>.*?</\s*\1\s*>'
    r'|<\s*(script|iframe|object|embed|link|meta|base|form|input|button|select|textarea)\b[^>]*/?>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _eventHandlerRe = RegExp(
      "\\son\\w+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
      caseSensitive: false);

  static final RegExp _jsUrlRe = RegExp(
      r'(href|src|action)\s*=\s*"(javascript|vbscript|data:text/html)[^"]*"',
      caseSensitive: false);

  static final RegExp _styleImportRe =
      RegExp(r'@import\s+url?\(?[^;)]*\);?', caseSensitive: false);

  static final RegExp _duplicateClassRe = RegExp(r'\sclass="[^"]*"');

  /// Sanitize + validate [html]. Returns cleaned HTML and warnings such as
  /// `dangerous_tag:script` or `too_large:shrunk`.
  static GuardResult guard(String html, {int maxBytes = defaultMaxBytes}) {
    final warnings = <String>[];
    var out = html;

    // 1. Strip dangerous elements, keeping a visible marker for the UI.
    final dangerous = <String>[];
    out = out.replaceAllMapped(_dangerousTagRe, (m) {
      final tag = (m.group(1) ?? 'tag').toLowerCase();
      if (tag.isNotEmpty && tag != 'tag') dangerous.add(tag);
      return '';
    });
    if (dangerous.isNotEmpty) {
      warnings.add('dangerous_tag:${dangerous.toSet().join(',')}');
    }

    // 2. Remove event handlers and javascript: URLs.
    out = out.replaceAll(_eventHandlerRe, '');
    out = out.replaceAllMapped(
        _jsUrlRe, (m) => '${m.group(1)}=""');
    out = out.replaceAll(_styleImportRe, '');

    // 3. Size cap with automatic shrink.
    var shrunk = false;
    while (utf8Length(out) > maxBytes && _shrinkableCount(out) > 1) {
      final next = _shrinkOnce(out);
      if (next == out) break; // safety: no progress
      out = next;
      shrunk = true;
    }
    if (utf8Length(out) > maxBytes) {
      out = _truncateTo(out, maxBytes);
      shrunk = true;
    }
    if (shrunk) warnings.add('too_large:shrunk');

    // 4. Balance check + trivial repair.
    final balance = _tagBalance(out);
    if (balance.closing > balance.opening) {
      out = _trimStrayClosers(out);
      warnings.add('repaired:stray_closing_tags');
    }

    return GuardResult(html: out, warnings: warnings, shrunk: shrunk);
  }

  /// True when the HTML looks structurally parseable (every opening tag has
  /// a matching closing tag; self-closing tags are excluded).
  static bool isBalanced(String html) {
    final balance = _tagBalance(html);
    return balance.opening == balance.closing;
  }

  static int utf8Length(String s) => s.codeUnits.length;

  static int _shrinkableCount(String html) =>
      _duplicateClassRe.allMatches(html).length;

  static String _shrinkOnce(String html) {
    // Remove repeated class attributes (keep the first occurrence).
    var seen = false;
    return html.replaceAllMapped(_duplicateClassRe, (m) {
      if (!seen) {
        seen = true;
        return m.group(0)!;
      }
      return '';
    });
  }

  static String _truncateTo(String html, int maxBytes) {
    if (html.length <= maxBytes) return html;
    var cut = html.substring(0, maxBytes);
    // Close any open tags at the cut point so it still parses.
    final openTags = RegExp(r'<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>')
        .allMatches(cut)
        .map((m) => m.group(1)!.toLowerCase())
        .toList();
    final closeTags = RegExp(r'</([a-zA-Z][a-zA-Z0-9]*)>')
        .allMatches(cut)
        .map((m) => m.group(1)!.toLowerCase())
        .toList();
    final unclosed = <String>[];
    for (final tag in openTags.toSet()) {
      final opens = openTags.where((t) => t == tag).length;
      final closes = closeTags.where((t) => t == tag).length;
      if (opens > closes && !unclosed.contains(tag)) unclosed.add(tag);
    }
    final buf = StringBuffer(cut);
    for (final tag in unclosed.reversed) {
      buf.write('</$tag>');
    }
    return buf.toString();
  }

  static ({int opening, int closing}) _tagBalance(String html) {
    var opening = 0;
    var closing = 0;
    final re = RegExp(r'</?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>');
    for (final m in re.allMatches(html)) {
      final raw = m.group(0)!;
      if (raw.startsWith('</')) {
        closing++;
      } else if (!raw.endsWith('/>')) {
        opening++;
      }
    }
    return (opening: opening, closing: closing);
  }

  static String _trimStrayClosers(String html) {
    var out = html;
    for (var i = 0; i < 5; i++) {
      final re = RegExp(r'</([a-zA-Z][a-zA-Z0-9]*)\s*>(?![\s\S]*<\1\b)');
      final m = re.firstMatch(out);
      if (m == null) break;
      out = out.replaceRange(m.start, m.end, '');
    }
    return out;
  }
}

/// Result of a [AIHtmlGuard.guard] pass.
class GuardResult {
  final String html;
  final List<String> warnings;
  final bool shrunk;

  const GuardResult({
    required this.html,
    required this.warnings,
    this.shrunk = false,
  });
}
