/// Equation service (Track 18, FEAT 18).
///
/// Converts a small subset of MathML (fraction, sqrt, sup/sub, sum, integral,
/// matrix, plain runs) into OOXML `<a:math>` markup for PPTX export, and into
/// an **inline SVG** renderer for HTML/PDF (P4). Slides carry
/// `<div data-equation='...'>` blocks.
library;

import 'dart:convert';
import 'dart:math' as math;

class EquationData {
  const EquationData({
    this.mathml = '',
    this.latex = '',
  });

  final String mathml;
  final String latex;

  Map<String, dynamic> toMap() => {
        if (mathml.isNotEmpty) 'mathml': mathml,
        if (latex.isNotEmpty) 'latex': latex,
      };

  static EquationData fromMap(Map<String, dynamic> map) => EquationData(
        mathml: map['mathml']?.toString() ?? '',
        latex: map['latex']?.toString() ?? '',
      );

  String toJson() => jsonEncode(toMap());

  static EquationData fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const EquationData();
      return fromMap(map);
    } catch (_) {
      return const EquationData();
    }
  }

  String get htmlMarkup => EquationService.renderSvg(mathml);

  /// Shorthand: render this equation as SVG.
  String get svgMarkup => EquationService.renderSvg(mathml);
}

class EquationService {
  EquationService._();

  static final RegExp _dataEquationRegExp = RegExp(
    r"""data-equation=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  /// Find every equation block in [html].
  static List<EquationData> equationsIn(String html) {
    final result = <EquationData>[];
    for (final match in _dataEquationRegExp.allMatches(html)) {
      result.add(EquationData.fromJson(match.group(2)!));
    }
    return result;
  }

  static String escapeAttribute(EquationData eq) =>
      eq.toJson().replaceAll("'", '&#39;');

  static String equationMarkup(EquationData eq) =>
      '<div data-equation=\'${escapeAttribute(eq)}\'></div>';

  static int equationCount(String html) =>
      _dataEquationRegExp.allMatches(html).length;

  /// Replace the [index]-th equation block.
  static String replaceEquationAt(String html, int index, EquationData eq) {
    final pattern = RegExp(
      r"""<div\b[^>]*data-equation=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = pattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, equationMarkup(eq));
  }

  // ---- MathML → OOXML a:math conversion ---------------------------------

  /// Convert a MathML string to OOXML `<m:oMath>` inner XML.
  /// Returns null when the input is not supported (caller falls back to
  /// the plain-text representation).
  static String? mathmlToOoxml(String mathml) {
    final s = mathml.trim();
    if (s.isEmpty) return null;
    final b = StringBuffer();
    if (!_convertNode(s, b)) return null;
    return b.toString();
  }

  static bool _convertNode(String s, StringBuffer b) {
    // Plain text (no angle bracket)
    if (!s.contains('<')) {
      b.write('<m:r><m:t>${_xmlText(s)}</m:t></m:r>');
      return true;
    }
    // Simple matcher: <tag>...</tag>
    final tagMatch = RegExp(r'^\s*<([a-zA-Z]+)>(.*)</\1>\s*$',
            dotAll: true)
        .firstMatch(s);
    if (tagMatch == null) {
      // Maybe it's a self-closing or a run with attributes — try text.
      final text = s.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (text.isNotEmpty) {
        b.write('<m:r><m:t>${_xmlText(text)}</m:t></m:r>');
        return true;
      }
      return false;
    }
    final tag = tagMatch.group(1);
    final inner = tagMatch.group(2)!;
    switch (tag) {
      case 'mi':
      case 'mn':
      case 'mo':
      case 'ms':
        b.write('<m:r><m:t>${_xmlText(inner)}</m:t></m:r>');
        return true;
      case 'mrow':
        return _convertNode(inner, b);
      case 'mfrac':
        final parts = _splitTopLevel(inner);
        if (parts.length != 2) return false;
        b.write('<m:f><m:fPr><m:type m:val="bar"/></m:fPr>'
            '<m:num>');
        if (!_convertNode(parts[0], b)) return false;
        b.write('</m:num><m:den>');
        if (!_convertNode(parts[1], b)) return false;
        b.write('</m:den></m:f>');
        return true;
      case 'msqrt':
        b.write('<m:rad><m:radPr><m:degHide m:val="1"/></m:radPr>'
            '<m:deg/><m:e>');
        if (!_convertNode(inner, b)) return false;
        b.write('</m:e></m:rad>');
        return true;
      case 'msup':
        final parts = _splitTopLevel(inner);
        if (parts.length != 2) return false;
        b.write('<m:sSup><m:e>');
        if (!_convertNode(parts[0], b)) return false;
        b.write('</m:e><m:sup>');
        if (!_convertNode(parts[1], b)) return false;
        b.write('</m:sup></m:sSup>');
        return true;
      case 'msub':
        final parts = _splitTopLevel(inner);
        if (parts.length != 2) return false;
        b.write('<m:sSub><m:e>');
        if (!_convertNode(parts[0], b)) return false;
        b.write('</m:e><m:sub>');
        if (!_convertNode(parts[1], b)) return false;
        b.write('</m:sub></m:sSub>');
        return true;
      case 'msubsup':
        final parts = _splitTopLevel(inner);
        if (parts.length != 3) return false;
        b.write('<m:sSubSup><m:e>');
        if (!_convertNode(parts[0], b)) return false;
        b.write('</m:e><m:sub>');
        if (!_convertNode(parts[1], b)) return false;
        b.write('</m:sub><m:sup>');
        if (!_convertNode(parts[2], b)) return false;
        b.write('</m:sup></m:sSubSup>');
        return true;
      case 'munderover':
        final parts = _splitTopLevel(inner);
        if (parts.length != 3) return false;
        b.write('<m:nary><m:naryPr><m:chr m:val="∑"/>'
            '<m:limLoc m:val="undOvr"/></m:naryPr>'
            '<m:sub>');
        if (!_convertNode(parts[1], b)) return false;
        b.write('</m:sub><m:sup>');
        if (!_convertNode(parts[2], b)) return false;
        b.write('</m:sup><m:e>');
        if (!_convertNode(parts[0], b)) return false;
        b.write('</m:e></m:nary>');
        return true;
      case 'mtable':
        final rows = _splitRows(inner);
        b.write('<m:m><m:mPr/><m:mr>');
        for (final row in rows) {
          final cells = _splitCells(row);
          for (final cell in cells) {
            b.write('<m:e>');
            if (!_convertNode(cell, b)) return false;
            b.write('</m:e>');
          }
        }
        b.write('</m:mr></m:m>');
        return true;
      default:
        // Unknown tag — recurse into children.
        return _convertNode(inner, b);
    }
  }

  static List<String> _splitTopLevel(String s) {
    // Split a MathML fragment into its top-level children: each child is a
    // `<tag>...</tag>` sequence (no space needed between siblings).
    final parts = <String>[];
    var depth = 0;
    var current = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '<') {
        // Opening tag '<' (not '</').
        final closing = i + 1 < s.length && s[i + 1] == '/';
        if (!closing) depth++;
        current.write(c);
        // Skip to the end of this tag.
        var j = i + 1;
        while (j < s.length && s[j] != '>') {
          current.write(s[j]);
          j++;
        }
        if (j < s.length) {
          current.write('>');
          if (closing) depth--;
          i = j;
          if (depth == 0) {
            parts.add(current.toString().trim());
            current = StringBuffer();
          }
        }
      } else {
        current.write(c);
      }
    }
    if (current.toString().trim().isNotEmpty) {
      parts.add(current.toString().trim());
    }
    return parts;
  }

  static List<String> _splitRows(String s) {
    return s
        .split(RegExp(r'</?mtr>'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> _splitCells(String s) {
    return s
        .split(RegExp(r'</?mtd>'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _xmlText(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // ---- MathML → inline SVG renderer (P4) ---------------------------------

  /// Render a MathML equation as an inline SVG document (self-drawn — no
  /// KaTeX/MathJax network dependency). Supports the same subset as the
  /// OOXML converter: fractions, square roots, sup/sub, sums, integrals,
  /// matrices, and plain runs. Falls back to a styled text element when the
  /// input cannot be parsed.
  static String renderSvg(String mathml) {
    final inner = mathml
        .trim()
        .replaceFirst(RegExp(r'^<math[^>]*>'), '')
        .replaceFirst(RegExp(r'</math>\s*$'), '')
        .trim();
    final layout = _layoutRun(inner);
    final w = (layout.width + 12).round().clamp(24, 2000);
    final h = (layout.height + 12).round().clamp(16, 800);
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" '
        'width="$w" height="$h" role="img" aria-label="equation">'
        '<g transform="translate(6, ${(layout.descent + 6).toStringAsFixed(1)})">'
        '${layout.markup}</g></svg>';
  }

  /// Lay out one MathML node into an SVG fragment.
  static _SvgLayout _layoutRun(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) {
      return const _SvgLayout('', 0, 0, 0);
    }
    final tagMatch = RegExp(r'^<([a-zA-Z]+)>(.*)</\1>$', dotAll: true)
        .firstMatch(trimmed);
    if (tagMatch == null) {
      // Plain text (possibly with entity references).
      final text = _xmlText(trimmed);
      final width = trimmed.length * 9.0;
      return _SvgLayout(
          '<text x="0" y="0" font-size="16" font-family="Cambria Math, serif" '
          'font-style="italic" fill="#000000">$text</text>',
          width, 16, 4);
    }
    final tag = tagMatch.group(1);
    final inner = tagMatch.group(2)!;
    switch (tag) {
      case 'mi':
      case 'mn':
      case 'mo':
      case 'ms':
        return _textLayout(_xmlText(inner), italic: tag == 'mi');
      case 'mrow':
        return _concat(_splitTopLevel(inner));
      case 'mfrac':
        final parts = _splitTopLevel(inner);
        if (parts.length != 2) return _textLayout('?');
        final numL = _layoutRun(parts[0]);
        final denL = _layoutRun(parts[1]);
        final width = math.max(numL.width, denL.width) + 8;
        const numY = 0.0;
        final denY = numL.height + 16.0;
        final barY = numL.height + 6.0;
        final markup = '<g>'
            '<g transform="translate(0,$numY)">${numL.markup}</g>'
            '<line x1="0" y1="$barY" x2="$width" y2="$barY" '
            'stroke="#000" stroke-width="1"/>'
            '<g transform="translate(0,$denY)">${denL.markup}</g>'
            '</g>';
        return _SvgLayout(markup, width, denY + denL.height, denL.descent + 2);
      case 'msqrt':
        final innerL = _layoutRun(inner);
        final width = innerL.width + 14;
        final markup = '<g>'
            '<path d="M2,${innerL.height + 2} L8,${innerL.height - 6} '
            'L12,${innerL.height - 2} L${width - 6},${innerL.height - 2} '
            'L${width - 6},0 L$width,0 L$width,${innerL.height} '
            'L12,${innerL.height} Z" fill="none" stroke="#000" stroke-width="1"/>'
            '<g transform="translate(10,0)">${innerL.markup}</g>'
            '</g>';
        return _SvgLayout(markup, width, innerL.height, innerL.descent + 2);
      case 'msup':
        final parts = _splitTopLevel(inner);
        if (parts.length != 2) return _textLayout('?');
        final baseL = _layoutRun(parts[0]);
        final supL = _layoutRun(parts[1]);
        final markup = '<g>'
            '<g transform="translate(0,${-supL.height * 0.6})">'
            '<g transform="scale(0.7)">${supL.markup}</g></g>'
            '<g transform="translate(${(baseL.width + 2).toStringAsFixed(1)},0)">'
            '${baseL.markup}</g></g>';
        final width = baseL.width + supL.width * 0.7 + 4;
        return _SvgLayout(markup, width, baseL.height, baseL.descent);
      case 'msub':
        final parts = _splitTopLevel(inner);
        if (parts.length != 2) return _textLayout('?');
        final baseL = _layoutRun(parts[0]);
        final subL = _layoutRun(parts[1]);
        final markup = '<g>'
            '<g transform="translate(${(baseL.width + 2).toStringAsFixed(1)},'
            '${(baseL.height * 0.4).toStringAsFixed(1)})">'
            '<g transform="scale(0.7)">${subL.markup}</g></g>'
            '<g transform="translate(0,0)">${baseL.markup}</g></g>';
        final width = baseL.width + subL.width * 0.7 + 4;
        return _SvgLayout(markup, width, baseL.height, baseL.descent);
      case 'munderover':
        final parts = _splitTopLevel(inner);
        if (parts.length != 3) return _textLayout('?');
        final baseL = _layoutRun(parts[0]);
        final subL = _layoutRun(parts[1]);
        final supL = _layoutRun(parts[2]);
        final width = math.max(baseL.width, math.max(subL.width, supL.width)) + 4;
        final markup = '<g>'
            '<g transform="translate(0,0)">${baseL.markup}</g>'
            '<g transform="translate(0,${-supL.height - 6})">'
            '<g transform="scale(0.7)">${supL.markup}</g></g>'
            '<g transform="translate(0,${baseL.height + 4})">'
            '<g transform="scale(0.7)">${subL.markup}</g></g>'
            '</g>';
        return _SvgLayout(markup, width, baseL.height + subL.height * 0.7 + 6, baseL.descent);
      case 'mtable':
        final rows = _splitRows(inner);
        final rowLayouts = <List<_SvgLayout>>[];
        var maxWidth = 0.0;
        for (final row in rows) {
          final cells = _splitCells(row);
          final cellLayouts = cells.map(_layoutRun).toList();
          rowLayouts.add(cellLayouts);
          maxWidth = math.max(maxWidth, cellLayouts.fold(0.0, (m, c) => m + c.width));
        }
        final markup = StringBuffer('<g>');
        var y = 0.0;
        for (final row in rowLayouts) {
          var x = 0.0;
          final rowH = row.fold(0.0, (m, c) => math.max(m, c.height));
          for (final cell in row) {
            markup.write(
                '<g transform="translate(${x.toStringAsFixed(1)},${y.toStringAsFixed(1)})">${cell.markup}</g>');
            x += cell.width + 10;
          }
          y += rowH + 8;
        }
        markup.write('</g>');
        return _SvgLayout(markup.toString(), maxWidth, y, 4);
      default:
        return _layoutRun(inner);
    }
  }

  static _SvgLayout _textLayout(String text, {bool italic = false}) {
    final width = text.length * 9.0;
    return _SvgLayout(
        '<text x="0" y="0" font-size="16" font-family="Cambria Math, serif" '
        '${italic ? 'font-style="italic" ' : ''}fill="#000000">$text</text>',
        width, 16, 4);
  }

  static _SvgLayout _concat(List<String> parts) {
    final layouts = parts.map(_layoutRun).toList();
    final markup = StringBuffer('<g>');
    var x = 0.0;
    var maxH = 0.0;
    var maxDescent = 0.0;
    for (final l in layouts) {
      markup.write(
          '<g transform="translate(${x.toStringAsFixed(1)},0)">${l.markup}</g>');
      x += l.width;
      maxH = math.max(maxH, l.height);
      maxDescent = math.max(maxDescent, l.descent);
    }
    markup.write('</g>');
    return _SvgLayout(markup.toString(), x, maxH, maxDescent);
  }
}

/// A laid-out SVG fragment: markup plus metrics (width, height, descent).
class _SvgLayout {
  final String markup;
  final double width;
  final double height;
  final double descent;

  const _SvgLayout(this.markup, this.width, this.height, this.descent);
}
