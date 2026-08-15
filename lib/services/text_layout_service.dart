import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Advanced text layout utilities operating on slide HTML content (Track 28):
/// deck-wide font replace, change case, character spacing, text direction,
/// autofit hints, bullet numbering and tab stops.
///
/// The HTML edits keep inline styles so both the WebView preview and the
/// exporters (which read the same HTML) pick the change up.
class TextLayoutService {
  TextLayoutService._();

  /// Precompiled — created once instead of once per word inside
  /// [_applyCase] title mode (the splitter maps over every whitespace
  /// token of every text node).
  static final RegExp _whitespaceOnlyRe = RegExp(r'^\s+$');

  /// Precompiled sentence-start matcher (sentence case mode).
  static final RegExp _sentenceStartRe = RegExp(
      r'(^|[.!?]\s+)([a-zàáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ])');

  /// Replace [fromFont] with [toFont] in [html]. Matching is
  /// case-insensitive on font-family names (quoted or unquoted). Returns the
  /// replaced HTML.
  static String replaceFont(String html, String fromFont, String toFont) {
    final re = RegExp(
      'font-family\\s*:\\s*(["\']?)(${RegExp.escape(fromFont)})(["\']?)',
      caseSensitive: false,
    );
    return html.replaceAllMapped(re, (m) {
      return 'font-family: ${m[1]}$toFont${m[3]}';
    });
  }

  /// Change case of the plain text inside [html] (keeps tags/attributes).
  /// [mode]: 'sentence' | 'upper' | 'lower' | 'title' | 'toggle'.
  static String changeCase(String html, String mode) {
    final doc = html_parser.parseFragment(html);
    void walk(dom.Node node) {
      for (final child in node.nodes.toList()) {
        if (child is dom.Text) {
          child.text = _applyCase(child.text, mode);
        } else if (child is dom.Element) {
          walk(child);
        }
      }
    }

    walk(doc);
    return doc.outerHtml;
  }

  static String _applyCase(String text, String mode) {
    switch (mode) {
      case 'upper':
        return text.toUpperCase();
      case 'lower':
        return text.toLowerCase();
      case 'title':
        return text
            .split(RegExp(r'(\s+)'))
            .map((w) => w.isEmpty || _whitespaceOnlyRe.hasMatch(w)
                ? w
                : w[0].toUpperCase() + w.substring(1))
            .join();
      case 'toggle':
        return text
            .split('')
            .map((c) => c == c.toUpperCase() ? c.toLowerCase() : c.toUpperCase())
            .join();
      case 'sentence':
      default:
        // First letter of each sentence uppercased.
        return text.replaceAllMapped(
          _sentenceStartRe,
          (m) => m[1]! + m[2]!.toUpperCase(),
        );
    }
  }

  /// Apply character spacing (tracking) to every text element in [html].
  /// [px] can be negative. Inline `letter-spacing` replaces any existing one.
  static String setCharacterSpacing(String html, double px) {
    final doc = html_parser.parseFragment(html);
    final digits = px == px.roundToDouble()
        ? 0
        : (px * 10 == (px * 10).roundToDouble() ? 1 : 2);
    final value = '${px.toStringAsFixed(digits)}px';
    for (final el in _textElements(doc)) {
      _setStyle(el, 'letter-spacing', value);
    }
    return doc.outerHtml;
  }

  /// Wrap the content of [html] so it renders vertically.
  /// [mode]: 'horizontal' | 'vertical' (writing-mode vertical-rl) |
  /// 'rotated90' | 'rotated270' (CSS transform fallbacks).
  static String setTextDirection(String html, String mode) {
    final doc = html_parser.parseFragment(html);
    for (final el in _textElements(doc)) {
      switch (mode) {
        case 'vertical':
          _setStyle(el, 'writing-mode', 'vertical-rl');
        case 'rotated90':
          _setStyle(el, 'writing-mode', 'vertical-rl');
          _setStyle(el, 'transform', 'rotate(90deg)');
        case 'rotated270':
          _setStyle(el, 'writing-mode', 'vertical-rl');
          _setStyle(el, 'transform', 'rotate(270deg)');
        default:
          _removeStyle(el, 'writing-mode');
          _removeStyle(el, 'transform');
      }
    }
    return doc.outerHtml;
  }

  /// Mark autofit behaviour on the top-level container of [html].
  /// [mode]: 'none' | 'shrink' (shrink text on overflow) |
  /// 'resizeShape' (resize the shape to fit text).
  static String setAutofit(String html, String mode) {
    final doc = html_parser.parseFragment(html);
    final container = _ensureContainer(doc);
    switch (mode) {
      case 'shrink':
        _setStyle(container, 'overflow', 'hidden');
        _setStyle(container, 'text-overflow', 'ellipsis');
        container.attributes['data-autofit'] = 'shrink';
      case 'resizeShape':
        container.attributes['data-autofit'] = 'resizeShape';
      default:
        container.attributes.remove('data-autofit');
        _removeStyle(container, 'overflow');
        _removeStyle(container, 'text-overflow');
    }
    return doc.outerHtml;
  }

  /// Apply bullet settings to every `<li>` in [html].
  /// [startAt] sets the numbering start (1 = default). [level] sets the
  /// list indent level (0 = first). [image] optionally replaces the bullet
  /// with an icon/image URL.
  static String setBullets(
    String html, {
    int? startAt,
    int level = 0,
    String? image,
  }) {
    final doc = html_parser.parseFragment(html);
    for (final li in doc.querySelectorAll('li')) {
      final parent = li.parent;
      if (startAt != null && parent != null && parent.localName == 'ol') {
        parent.attributes['start'] = '$startAt';
      }
      if (level > 0) {
        _setStyle(li, 'margin-left', '${24 * level}px');
      }
      if (image != null && image.isNotEmpty) {
        _setStyle(li, 'list-style-image', "url('$image')");
        _setStyle(li, 'list-style-type', 'none');
      }
    }
    return doc.outerHtml;
  }

  /// Add a tab stop declaration to the container style.
  /// [positionsPx] are tab stops from the left; [leader] is '.' or '-' or
  /// '' (no leader). Stored as data attributes so exporters can emit
  /// OOXML `<a:tabLst>`.
  static String setTabStops(String html, List<double> positionsPx, {String leader = ''}) {
    final doc = html_parser.parseFragment(html);
    final container = _ensureContainer(doc);
    container.attributes['data-tabstops'] =
        positionsPx.map((p) => p.round().toString()).join(',');
    if (leader.isNotEmpty) {
      container.attributes['data-tableader'] = leader;
    }
    return doc.outerHtml;
  }

  // ---- helpers -----------------------------------------------------------

  static List<dom.Element> _textElements(dom.DocumentFragment doc) =>
      doc.querySelectorAll('p, span, div, h1, h2, h3, h4, h5, h6, li');

  static dom.Element _ensureContainer(dom.DocumentFragment doc) {
    if (doc.children.isNotEmpty) return doc.children.first;
    final container = dom.Element.tag('div');
    doc.nodes.insert(0, container);
    return container;
  }

  /// Set a CSS property inside the element's `style` attribute, preserving
  /// the other declarations.
  static void _setStyle(dom.Element el, String prop, String value) {
    final decls = _styleDeclarations(el);
    decls[prop] = value;
    el.attributes['style'] = decls.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('; ');
  }

  static void _removeStyle(dom.Element el, String prop) {
    final decls = _styleDeclarations(el);
    decls.remove(prop);
    el.attributes['style'] = decls.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('; ');
  }

  static Map<String, String> _styleDeclarations(dom.Element el) {
    final out = <String, String>{};
    final raw = el.attributes['style'];
    if (raw != null && raw.isNotEmpty) {
      for (final decl in raw.split(';')) {
        final idx = decl.indexOf(':');
        if (idx <= 0) continue;
        final prop = decl.substring(0, idx).trim().toLowerCase();
        final value = decl.substring(idx + 1).trim();
        if (prop.isNotEmpty) out[prop] = value;
      }
    }
    return out;
  }

  /// OOXML `<a:bodyPr>` attributes for [mode] (Track 28, P4).
  static String bodyPrDirection(String mode) => switch (mode) {
        'vertical' => ' vert="vert"',
        'rotated90' => ' vert="vert270"',
        'rotated270' => ' vert="eaVert"',
        _ => '',
      };

  /// OOXML `<a:buAutoNum>` for an ordered list starting at [startAt].
  static String bulletAutoNum(int startAt, {int indentLevel = 0}) =>
      '<a:buAutoNum type="arabicPeriod" startAt="$startAt"/>'
      '${indentLevel > 0 ? ' <a:ind sz="${indentLevel * 25}"/>' : ''}';

  /// OOXML `<a:tabLst>` from [positionsPx] with optional [leader].
  static String tabListXml(List<double> positionsPx, {String leader = ''}) {
    final buf = StringBuffer();
    if (positionsPx.isEmpty) return '';
    buf.write('<a:tabLst>');
    // PPTX tab positions are in EMU within the text box; ~9525 EMU per pt.
    for (final p in positionsPx) {
      final pos = (p * 72.0 * 9525.0).round(); // px → pt → EMU
      final leaderAttr = switch (leader) {
        '.' => ' algn="l" leader="dot"',
        '-' => ' algn="l" leader="hyphen"',
        _ => ' algn="l"',
      };
      buf.write('<a:tab pos="$pos"$leaderAttr/>');
    }
    buf.write('</a:tabLst>');
    return buf.toString();
  }
}
