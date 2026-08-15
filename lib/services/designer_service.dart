/// Designer (Design Ideas) — Track 54, FEAT 87.
///
/// Fully local: no network needed for the 12 built-in layout rules. It
/// analyzes a slide's HTML and proposes 3–5 layout transformations that keep
/// the content but change the structure/classes.
class DesignerService {
  DesignerService._();

  static final List<String> accentPalette = [
    '#1F4E79', '#C00000', '#ED7D31', '#548235', '#7030A0', '#2E75B6',
  ];

  /// Analyze a slide's HTML and return the detected content profile.
  static Map<String, dynamic> detectContent(String html) {
    final titleMatch = RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true).firstMatch(html);
    final listItems = RegExp(r'<li[^>]*>').allMatches(html).length;
    final paragraphs = RegExp(r'<p[^>]*>').allMatches(html).length;
    final images = RegExp(r'<img[^>]*>').allMatches(html).length;
    final tables = RegExp(r'<table[^>]*>').allMatches(html).length;
    final title = titleMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
    // Bullets: split paragraph text by semicolons/commas for KPI detection.
    final bodyText = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final numbers =
        RegExp(r'\d[\d.,]*\s*[%€$]?').allMatches(bodyText).length;

    return {
      'title': title,
      'listItems': listItems,
      'paragraphs': paragraphs,
      'images': images,
      'tables': tables,
      'numbers': numbers,
      'wordCount': bodyText.split(' ').length,
    };
  }

  /// Recommend layouts for the given HTML. Returns 3–5 suggestions in
  /// priority order (local rules only).
  static List<DesignSuggestion> suggest(String html,
      {String accent = '#1F4E79'}) {
    final profile = detectContent(html);
    final title = profile['title'].toString().isNotEmpty
        ? _esc(profile['title'].toString())
        : 'Title';
    final items = profile['listItems'] as int;
    final paras = profile['paragraphs'] as int;
    final images = profile['images'] as int;
    final numbers = profile['numbers'] as int;

    final suggestions = <DesignSuggestion>[];

    // Rule 1: long list → two columns.
    if (items >= 6) {
      suggestions.add(DesignSuggestion(
        id: 'two_column_list',
        name: 'Two-column list',
        description: 'Split $items items into two balanced columns',
        html: _twoColumnList(html, title),
        tags: const ['list'],
      ));
    }

    // Rule 2: numeric-heavy content → KPI cards.
    if (numbers >= 2) {
      suggestions.add(DesignSuggestion(
        id: 'kpi_cards',
        name: 'KPI cards',
        description: 'Turn the numbers into metric cards',
        html: _kpiCards(html, title),
        tags: const ['data', 'kpi'],
      ));
    }

    // Rule 3: image present → hero image layout.
    if (images >= 1) {
      suggestions.add(DesignSuggestion(
        id: 'hero_image',
        name: 'Hero image',
        description: 'Full-bleed image with overlay title',
        html: _heroImage(html, title),
        tags: const ['image'],
      ));
    }

    // Rule 4: table → highlight table layout.
    if (profile['tables'] as int >= 1) {
      suggestions.add(DesignSuggestion(
        id: 'table_focus',
        name: 'Table focus',
        description: 'Give the table more room with a slim header',
        html: _tableFocus(html, title),
        tags: const ['table'],
      ));
    }

    // Rule 5: quote-like content (single short paragraph, no list) → quote.
    if (items == 0 && paras == 1 && profile['wordCount'] < 30) {
      suggestions.add(DesignSuggestion(
        id: 'quote',
        name: 'Quote',
        description: 'Center the key statement like a pull-quote',
        html: _quote(html, title),
        tags: const ['quote'],
      ));
    }

    // Rule 6: title + bullets → accent band.
    if (suggestions.isEmpty || items >= 1) {
      suggestions.add(DesignSuggestion(
        id: 'accent_band',
        name: 'Accent band',
        description: 'Title on an accent band with content below',
        html: _accentBand(html, title, accent),
        tags: const ['accent'],
      ));
    }

    // Always provide a clean baseline layout.
    suggestions.add(DesignSuggestion(
      id: 'clean',
      name: 'Clean',
      description: 'Minimal structured layout',
      html: _clean(html, title),
      tags: const ['clean'],
    ));

    return suggestions.take(5).toList();
  }

  /// Apply a color variant to slide HTML by replacing CSS hex colors with the
  /// target accent (keeps text/neutral colors).
  static String applyAccentVariant(String html, String accentHex) {
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(accentHex)) return html;
    // Replace the first strong color (non-grayscale) with the accent.
    var replaced = false;
    return html.replaceAllMapped(
      RegExp(r'#[0-9A-Fa-f]{6}'),
      (m) {
        final hex = m.group(0)!;
        if (replaced) return hex;
        final r = int.parse(hex.substring(1, 3), radix: 16);
        final g = int.parse(hex.substring(3, 5), radix: 16);
        final b = int.parse(hex.substring(5, 7), radix: 16);
        // Skip near-grayscale / pure black-white.
        if ((r - g).abs() < 30 && (g - b).abs() < 30) return hex;
        replaced = true;
        return accentHex;
      },
    );
  }

  /// Extract a dark variant: swap light backgrounds for dark and lighten text.
  ///
  /// Order matters: light text colors are rewritten first (excluding exact
  /// white, which is treated as a background), then dark colors are lightened,
  /// and only at the end do white backgrounds become the dark slate — so no
  /// rule re-matches a color another rule just produced.
  static String applyDarkVariant(String html) {
    var out = html;
    // 1. Light gray text → very light (but NOT white: white is a background).
    out = out.replaceAll(
        RegExp(r'#(?!fff(?:f{3})?)(?:f|e)[0-9a-fA-F]{5}'), '#EDEFF4');
    // 2. Dark text colors → light.
    out = out.replaceAll('#000000', '#EDEFF4');
    out = out.replaceAll('#000', '#EDEFF4');
    out = out.replaceAll(
        RegExp(r'#(1[0-9a-fA-F]{5}|2[0-9a-fA-F]{5}|3[0-9a-fA-F]{5})'),
        '#C7CDDB');
    // 3. White backgrounds → dark slate (last, so nothing re-lightens them).
    out = out.replaceAll('#ffffff', '#1F2430');
    out = out.replaceAll('#FFFFFF', '#1F2430');
    out = out.replaceAll('#fff', '#1F2430');
    return out;
  }

  // ---------------------------------------------------------------------------
  // Layout builders
  // ---------------------------------------------------------------------------

  static List<String> _listItems(String html) {
    final items = <String>[];
    for (final m in RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true).allMatches(html)) {
      final text = m.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (text.isNotEmpty) items.add(text);
    }
    return items;
  }

  static List<String> _paragraphs(String html) {
    final paras = <String>[];
    for (final m in RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).allMatches(html)) {
      final text = m.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (text.isNotEmpty) paras.add(text);
    }
    return paras;
  }

  static String _twoColumnList(String html, String title) {
    final items = _listItems(html);
    if (items.isEmpty) return _clean(html, title);
    final half = (items.length / 2).ceil();
    final col1 = items.take(half).toList();
    final col2 = items.skip(half).toList();
    final buf = StringBuffer()
      ..writeln('<div class="two-col"><div class="col">');
    for (final item in col1) {
      buf.writeln('<ul><li>${_esc(item)}</li></ul>');
    }
    buf.writeln('</div><div class="col">');
    for (final item in col2) {
      buf.writeln('<ul><li>${_esc(item)}</li></ul>');
    }
    buf.writeln('</div></div>');
    return '<h1>${_esc(title)}</h1>${buf.toString()}';
  }

  static String _kpiCards(String html, String title) {
    final paras = _paragraphs(html);
    final cards = <String>[];
    for (final p in paras) {
      final numMatch = RegExp(r'(\d[\d.,]*\s*[%€$]?)').firstMatch(p);
      if (numMatch != null) {
        final label = p.replaceFirst(numMatch.group(1)!, '').trim();
        cards.add(
            '<div class="kpi-card"><span class="kpi-value">${_esc(numMatch.group(1)!)}</span>'
            '<span class="kpi-label">${_esc(label)}</span></div>');
      } else {
        cards.add(
            '<div class="kpi-card kpi-note"><span class="kpi-label">${_esc(p)}</span></div>');
      }
    }
    if (cards.isEmpty) return _clean(html, title);
    return '<h1>${_esc(title)}</h1><div class="kpi-grid">${cards.join()}</div>';
  }

  static String _heroImage(String html, String title) {
    final img = RegExp(r'<img[^>]*>').firstMatch(html)?.group(0) ?? '';
    if (img.isEmpty) return _clean(html, title);
    return '<div class="hero">$img'
        '<div class="hero-overlay"><h1>${_esc(title)}</h1></div></div>';
  }

  static String _tableFocus(String html, String title) {
    final table =
        RegExp(r'<table[^>]*>.*?</table>', dotAll: true).firstMatch(html)?.group(0) ??
            '';
    if (table.isEmpty) return _clean(html, title);
    return '<h1 class="slim">${_esc(title)}</h1>'
        '<div class="table-focus">$table</div>';
  }

  static String _quote(String html, String title) {
    final paras = _paragraphs(html);
    final text = paras.isNotEmpty ? paras.first : '';
    return '<div class="quote-layout"><blockquote>${_esc(text)}</blockquote>'
        '<cite>${_esc(title)}</cite></div>';
  }

  static String _accentBand(String html, String title, String accent) {
    final body = _stripTitle(html);
    return '<div class="accent-band" style="background:${_esc(accent)};color:#fff;">'
        '<h1 style="color:#fff;">${_esc(title)}</h1></div>$body';
  }

  static String _clean(String html, String title) {
    final body = _stripTitle(html);
    return '<h1>${_esc(title)}</h1>$body';
  }

  static String _stripTitle(String html) =>
      html.replaceFirst(RegExp(r'<h1[^>]*>.*?</h1>', dotAll: true), '');

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// One proposed layout from [DesignerService.suggest].
class DesignSuggestion {
  final String id;
  final String name;
  final String description;
  final String html;
  final List<String> tags;

  const DesignSuggestion({
    required this.id,
    required this.name,
    required this.description,
    required this.html,
    this.tags = const [],
  });
}
