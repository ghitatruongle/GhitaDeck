import 'dart:math' as math;

/// Accessibility Checker (Track 58, FEAT 95).
///
/// Local checks per slide:
/// * missing/empty `alt` on images;
/// * WCAG AA contrast between text color and background (4.5:1 normal);
/// * reading order: title first, then content — reports when the first
///   heading is not an h1 or content precedes the title.
///
/// Results carry enough info to jump to the offending slide and, for
/// contrast, a suggested replacement color that meets AA.
class AccessibilityService {
  AccessibilityService._();

  /// Run all checks on the deck. Returns issues sorted by slide.
  static List<Issue> checkDeck(List<Map<String, dynamic>> slides) {
    final issues = <Issue>[];
    for (var i = 0; i < slides.length; i++) {
      issues.addAll(checkSlide(slides[i], slideIndex: i));
    }
    return issues;
  }

  static List<Issue> checkSlide(Map<String, dynamic> slide,
      {int slideIndex = 0}) {
    final html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
    final visual = slide['visualElements'];
    final issues = <Issue>[];

    // 1. Alt text on images.
    final imgRe = RegExp(r'<img\b[^>]*>');
    var imgIndex = 0;
    for (final m in imgRe.allMatches(html)) {
      final tag = m.group(0)!;
      final altMatch = RegExp(r'alt\s*=\s*"([^"]*)"').firstMatch(tag);
      final hasAlt = altMatch != null && altMatch.group(1)!.trim().isNotEmpty;
      final dataAlt = visual is Map && (visual['alt_$imgIndex'] as String? ?? '').isNotEmpty;
      if (!hasAlt && !dataAlt) {
        issues.add(Issue(
          slideIndex: slideIndex,
          type: 'alt',
          message: 'Image ${imgIndex + 1} is missing alt text.',
          suggestion: 'Add a short description of the image content.',
        ));
      }
      imgIndex++;
    }

    // 2. Contrast: find inline color + background pairs and check WCAG AA.
    final colorRe = RegExp(r'color\s*:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})');
    final bgRe = RegExp(
        r'background(?:-color)?\s*:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})');
    final color = colorRe.firstMatch(html)?.group(1);
    final bg = bgRe.firstMatch(html)?.group(1);
    if (color != null && bg != null) {
      final ratio = _contrastRatio(_hexToRgb(color), _hexToRgb(bg));
      if (ratio < 4.5) {
        final fix = _nearestAaColor(_hexToRgb(color), _hexToRgb(bg));
        issues.add(Issue(
          slideIndex: slideIndex,
          type: 'contrast',
          message:
              'Text color $color on $bg has contrast ${ratio.toStringAsFixed(2)}:1 (needs ≥ 4.5:1).',
          suggestion: 'Switch text to a darker color that meets WCAG AA.',
          suggestedColor: fix,
        ));
      }
    }

    // 3. Reading order: content before an h1, or no h1.
    final h1Pos = html.indexOf(RegExp(r'<h1\b'));
    final firstTextPos = _firstTextPos(html);
    if (h1Pos == -1) {
      issues.add(Issue(
        slideIndex: slideIndex,
        type: 'reading_order',
        message: 'Slide has no h1 title.',
        suggestion: 'Add an <h1> title as the first element.',
      ));
    } else if (firstTextPos != -1 && firstTextPos < h1Pos) {
      issues.add(Issue(
        slideIndex: slideIndex,
        type: 'reading_order',
        message: 'Content text appears before the h1 title.',
        suggestion: 'Move the title (h1) to the top of the slide.',
      ));
    }

    return issues;
  }

  /// One-tap fixes that can be applied automatically (alt via suggestion
  /// template; contrast via suggested color). Returns the fixed slide map.
  static Map<String, dynamic> applyFix(Map<String, dynamic> slide, Issue issue) {
    var html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
    switch (issue.type) {
      case 'alt':
        // Fill the first image without alt with a placeholder derived from
        // the slide title.
        final title = (slide['title'] ?? 'Slide').toString();
        html = html.replaceFirstMapped(
          RegExp(r'<img\b(?![^>]*\salt=)[^>]*>'),
          (m) {
            var tag = m.group(0)!;
            final close = tag.endsWith('/>') ? '/>' : '>';
            tag = tag.substring(0, tag.length - close.length);
            return '$tag alt="$title illustration" $close';
          },
        );
        return {...slide, 'htmlContent': html};
      case 'contrast':
        final sc = issue.suggestedColor;
        if (sc != null) {
          html = html.replaceFirst(
              RegExp(r'color\s*:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})'),
              'color: $sc');
        }
        return {...slide, 'htmlContent': html};
      default:
        return slide;
    }
  }

  /// Text report for submission (P6).
  static String report(List<Issue> issues, {int slideCount = 0}) {
    final buf = StringBuffer()
      ..writeln('Accessibility Report — $slideCount slide(s)')
      ..writeln('Total issues: ${issues.length}');
    if (issues.isEmpty) {
      buf.writeln('No issues found. 🎉');
      return buf.toString();
    }
    for (final issue in issues) {
      buf.writeln(
          '[Slide ${issue.slideIndex + 1}] ${issue.type}: ${issue.message}');
      if (issue.suggestion != null) {
        buf.writeln('    → ${issue.suggestion}');
      }
    }
    return buf.toString();
  }

  // -------------------------------------------------------------------------
  // Color helpers
  // -------------------------------------------------------------------------

  static (int, int, int) _hexToRgb(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    return (
      int.parse(h.substring(0, 2), radix: 16),
      int.parse(h.substring(2, 4), radix: 16),
      int.parse(h.substring(4, 6), radix: 16),
    );
  }

  static String _rgbToHex((int, int, int) rgb) {
    String p(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${p(rgb.$1)}${p(rgb.$2)}${p(rgb.$3)}'.toUpperCase();
  }

  static double _relativeLuminance((int, int, int) rgb) {      double f(double c) {
        final s = c / 255;
        return s <= 0.03928
            ? s / 12.92
            : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
      }

    return 0.2126 * f(rgb.$1.toDouble()) +
        0.7152 * f(rgb.$2.toDouble()) +
        0.0722 * f(rgb.$3.toDouble());
  }

  static double _contrastRatio((int, int, int) a, (int, int, int) b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Darken the foreground until contrast ≥ 4.5:1 against [bg].
  static String _nearestAaColor((int, int, int) fg, (int, int, int) bg) {
    var r = fg.$1, g = fg.$2, b = fg.$3;
    for (var step = 0; step < 10; step++) {
      if (_contrastRatio((r, g, b), bg) >= 4.5) break;
      r = (r * 0.8).round().clamp(0, 255);
      g = (g * 0.8).round().clamp(0, 255);
      b = (b * 0.8).round().clamp(0, 255);
    }
    return _rgbToHex((r, g, b));
  }

  static int _firstTextPos(String html) {
    final tagRe = RegExp(r'<[^>]+>');
    var last = 0;
    for (final m in tagRe.allMatches(html)) {
      final between = html.substring(last, m.start);
      if (between.trim().isNotEmpty) return last;
      last = m.end;
    }
    final tail = html.substring(last);
    return tail.trim().isNotEmpty ? last : -1;
  }
}

/// One accessibility finding.
class Issue {
  final int slideIndex;
  final String type; // 'alt' | 'contrast' | 'reading_order'
  final String message;
  final String? suggestion;
  final String? suggestedColor;

  const Issue({
    required this.slideIndex,
    required this.type,
    required this.message,
    this.suggestion,
    this.suggestedColor,
  });
}
