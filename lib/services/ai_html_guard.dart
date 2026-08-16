import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

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
  static const int presentationMaxBytes = 16 * 1024 * 1024;

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
  static const Set<String> _dangerousTags = {
    'script',
    'iframe',
    'object',
    'embed',
    'link',
    'meta',
    'base',
    'form',
    'input',
    'button',
    'select',
    'textarea',
  };
  static const Set<String> _urlAttributes = {
    'href',
    'src',
    'action',
    'formaction',
    'poster',
    'xlink:href',
  };

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
    out = out.replaceAllMapped(_jsUrlRe, (m) => '${m.group(1)}=""');
    out = out.replaceAll(_styleImportRe, '');

    // Parse the fragment and inspect decoded attributes. This catches single
    // quotes, unquoted values, character entities and whitespace/control-byte
    // obfuscation that regular expressions cannot reliably cover.
    out = _sanitizeDom(out, dangerous);
    if (dangerous.isNotEmpty) {
      final warning = 'dangerous_tag:${dangerous.toSet().join(',')}';
      if (!warnings.contains(warning)) warnings.add(warning);
    }

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

  static int utf8Length(String s) => utf8.encode(s).length;

  static String _sanitizeDom(String html, List<String> dangerous) {
    final fragment = html_parser.parseFragment(html);
    for (final element in List<dom.Element>.from(
        fragment.querySelectorAll(_dangerousTags.join(',')))) {
      dangerous.add(element.localName ?? 'tag');
      element.remove();
    }
    for (final element
        in List<dom.Element>.from(fragment.querySelectorAll('*'))) {
      for (final name in List<String>.from(element.attributes.keys)) {
        final lowerName = name.toLowerCase();
        final value = element.attributes[name] ?? '';
        if (lowerName.startsWith('on') || lowerName == 'srcdoc') {
          element.attributes.remove(name);
          continue;
        }
        if (_urlAttributes.contains(lowerName) && _unsafeUrl(value)) {
          element.attributes[name] = '';
          continue;
        }
        if (lowerName == 'style') {
          element.attributes[name] = _sanitizeCss(value);
        }
      }
      if (element.localName == 'style') {
        element.text = _sanitizeCss(element.text);
      }
    }
    return fragment.outerHtml;
  }

  static bool _unsafeUrl(String value) {
    final normalized =
        value.replaceAll(RegExp(r'[\u0000-\u0020\u007f]+'), '').toLowerCase();
    return normalized.startsWith('javascript:') ||
        normalized.startsWith('vbscript:') ||
        normalized.startsWith('data:text/html') ||
        normalized.startsWith('data:application/xhtml+xml');
  }

  static String _sanitizeCss(String value) {
    var css = value.replaceAll(_styleImportRe, '');
    css = css.replaceAll(
      RegExp(
        r'''url\s*\(\s*(["']?)\s*(javascript|vbscript|data:text/html)[^)]*\)''',
        caseSensitive: false,
      ),
      'none',
    );
    css = css.replaceAll(
        RegExp(r'expression\s*\([^)]*\)', caseSensitive: false), '');
    return css;
  }

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
    if (utf8Length(html) <= maxBytes) return html;
    var budget = maxBytes;
    var cut = _prefixWithinBytes(html, budget);
    for (var attempt = 0; attempt < 6; attempt++) {
      final closed = _closeOpenTags(cut);
      final excess = utf8Length(closed) - maxBytes;
      if (excess <= 0) return closed;
      budget = (utf8Length(cut) - excess - 16).clamp(0, maxBytes);
      cut = _prefixWithinBytes(html, budget);
    }
    return _prefixWithinBytes(html, maxBytes);
  }

  static String _prefixWithinBytes(String value, int maxBytes) {
    var low = 0;
    var high = value.length;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (utf8Length(value.substring(0, mid)) <= maxBytes) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    // Do not leave a dangling UTF-16 high surrogate at the cut point.
    if (low > 0 &&
        low < value.length &&
        value.codeUnitAt(low - 1) >= 0xD800 &&
        value.codeUnitAt(low - 1) <= 0xDBFF) {
      low--;
    }
    return value.substring(0, low);
  }

  static String _closeOpenTags(String cut) {
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
