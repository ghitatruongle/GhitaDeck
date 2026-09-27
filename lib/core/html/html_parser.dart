import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../document/slide_document.dart';
import 'html_parse_codec.dart';

class HtmlAttrScan {
  static final RegExp _styleDeclRegExp = RegExp(r'([\w-]+)\s*:\s*([^;]+)');

  static final RegExp bgColorAttrRe = RegExp(
    r"""data-bg-color=["']([^"']+)["']""",
    caseSensitive: false,
  );
  static final RegExp diagramPatternRe = RegExp(
    r"""data-smartart=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp chartPatternRe = RegExp(
    r"""data-chart='([^']*)'""",
    caseSensitive: false,
  );
  static final RegExp videoPatternRe = RegExp(
    r"""<video\b[^>]*data-video=(['"])(.*?)\1[^>]*>""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp model3dPatternRe = RegExp(
    r"""data-model3d=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp actionPatternRe = RegExp(
    r"""data-action=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp equationPatternRe = RegExp(
    r"""data-equation=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp olePatternRe = RegExp(
    r"""data-ole=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp zoomPatternRe = RegExp(
    r"""data-zoom=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp sectionZoomPatternRe = RegExp(
    r"""data-sectionzoom=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp cameoPatternRe = RegExp(
    r"""data-cameo=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
}

class HtmlParseCore {
  static int jpegQualityForMaxWidth(int? imageMaxWidth) {
    switch (imageMaxWidth) {
      case 150:
        return 70;
      case 600:
        return 90;
      default:
        return 80;
    }
  }

  static String extractNotes(String html, {HtmlParseCache? parseCache}) {
    if (html.trim().isEmpty) return '';
    if (parseCache != null) {
      return parseCache.notesFor(html);
    }
    try {
      final doc = html_parser.parse(html);
      final aside = doc.querySelector('aside.notes');
      return aside?.text.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static List<Map<String, dynamic>> parseHtmlContentFull(
    String html, {
    HtmlParseCache? parseCache,
  }) {
    if (html.trim().isEmpty) {
      return [
        {
          'type': 'text',
          'paragraphs': [
            {'text': '', 'bold': 'false', 'italic': 'false'},
          ],
        },
      ];
    }
    if (parseCache != null) {
      return parseCache.blocksFor(html);
    }
    final document = html_parser.parse(html);
    return parseHtmlContentFullFromDoc(document, fallbackText: html);
  }

  static List<Map<String, dynamic>> parseHtmlContentFullFromDoc(
    dom.Document document, {
    String fallbackText = '',
  }) {
    final body = document.body;
    if (body == null) {
      return [
        {
          'type': 'text',
          'paragraphs': [
            {'text': fallbackText, 'bold': 'false', 'italic': 'false'},
          ],
        },
      ];
    }

    for (final aside in body.querySelectorAll('aside.notes')) {
      aside.remove();
    }
    final blocks = _extractBlocks(body);
    if (blocks.isEmpty) {
      return [
        {
          'type': 'text',
          'paragraphs': [
            {'text': body.text, 'bold': 'false', 'italic': 'false'},
          ],
        },
      ];
    }
    return blocks;
  }

  static List<Map<String, String>> parseHtmlContent(String html) {
    final blocks = parseHtmlContentFull(html);
    final paragraphs = <Map<String, String>>[];
    for (final block in blocks) {
      if (block['type'] == 'text') {
        for (final run
            in (block['paragraphs'] as List).cast<Map<String, String>>()) {
          final legacyRun = Map<String, String>.from(run)
            ..remove('paragraphStart')
            ..remove('itemStart');
          paragraphs.add(legacyRun);
        }
      } else if (block['type'] == 'list') {
        for (final item
            in (block['items'] as List).cast<Map<String, String>>()) {
          final legacyItem = Map<String, String>.from(item)
            ..remove('paragraphStart')
            ..remove('itemStart');
          paragraphs.add(legacyItem);
        }
      }
    }
    return paragraphs;
  }

  static const Map<String, String> _cssColorNames = {
    'black': '000000',
    'white': 'FFFFFF',
    'red': 'FF0000',
    'green': '008000',
    'blue': '0000FF',
    'yellow': 'FFFF00',
    'orange': 'FFA500',
    'purple': '800080',
    'gray': '808080',
    'grey': '808080',
    'silver': 'C0C0C0',
    'navy': '000080',
    'teal': '008080',
    'maroon': '800000',
    'olive': '808000',
    'lime': '00FF00',
    'aqua': '00FFFF',
    'cyan': '00FFFF',
    'magenta': 'FF00FF',
    'fuchsia': 'FF00FF',
    'pink': 'FFC0CB',
    'brown': 'A52A2A',
    'gold': 'FFD700',
  };

  static String? cssColorToHex(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.startsWith('#')) {
      final hex = v.substring(1);
      if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)) return hex.toUpperCase();
      if (RegExp(r'^[0-9a-f]{3}$').hasMatch(hex)) {
        return hex.split('').map((c) => '$c$c').join().toUpperCase();
      }
      return null;
    }
    final rgbMatch = RegExp(
      r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',
    ).firstMatch(v);
    if (rgbMatch != null) {
      String toHex(String s) =>
          int.parse(s).clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return (toHex(rgbMatch.group(1)!) +
              toHex(rgbMatch.group(2)!) +
              toHex(rgbMatch.group(3)!))
          .toUpperCase();
    }
    return _cssColorNames[v]?.toUpperCase();
  }

  static String? cssFontSizeToSz(String raw) {
    final v = raw.trim().toLowerCase();
    final match = RegExp(r'^([\d.]+)\s*(px|pt|em|rem)?$').firstMatch(v);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || value <= 0) return null;
    final unit = match.group(2) ?? 'px';
    double pt;
    switch (unit) {
      case 'pt':
        pt = value;
        break;
      case 'em':
      case 'rem':
        pt = value * 12;
        break;
      default:
        pt = value * 0.75;
    }
    final sz = (pt * 100).round();
    if (sz < 100 || sz > 40000) return null;
    return sz.toString();
  }

  static Map<String, String> _mergeElementStyle(
    dom.Element el,
    Map<String, String> style,
  ) {
    final merged = Map<String, String>.from(style);
    final styleAttr = el.attributes['style'];
    if (styleAttr != null && styleAttr.isNotEmpty) {
      for (final m in HtmlAttrScan._styleDeclRegExp.allMatches(styleAttr)) {
        final prop = m.group(1)!.trim().toLowerCase();
        final value = m.group(2)!.trim();
        switch (prop) {
          case 'color':
            final hex = cssColorToHex(value);
            if (hex != null) merged['color'] = hex;
            break;
          case 'background-color':
            final hex = cssColorToHex(value);
            if (hex != null) merged['highlight'] = hex;
            break;
          case 'font-size':
            final sz = cssFontSizeToSz(value);
            if (sz != null) merged['size'] = sz;
            break;
          case 'font-family':
            final family = value
                .split(',')
                .first
                .trim()
                .replaceAll(RegExp(r'''["']'''), '');
            if (family.isNotEmpty) merged['font'] = family;
            break;
          case 'font-weight':
            if (value == 'bold' || (int.tryParse(value) ?? 0) >= 600) {
              merged['bold'] = 'true';
            }
            break;
          case 'font-style':
            if (value == 'italic') merged['italic'] = 'true';
            break;
          case 'text-decoration':
            if (value.contains('underline')) merged['underline'] = 'true';
            if (value.contains('line-through')) merged['strike'] = 'true';
            break;
          case 'text-align':
            final algn = _cssAlignToAlgn(value);
            if (algn != null) merged['align'] = algn;
            break;
        }
      }
    }
    final alignAttr = el.attributes['align'];
    if (alignAttr != null) {
      final algn = _cssAlignToAlgn(alignAttr);
      if (algn != null) merged['align'] = algn;
    }
    return merged;
  }

  static String? _cssAlignToAlgn(String value) {
    switch (value.trim().toLowerCase()) {
      case 'left':
        return 'l';
      case 'center':
        return 'ctr';
      case 'right':
        return 'r';
      case 'justify':
        return 'just';
    }
    return null;
  }

  static Map<String, String> _makeRun(
    String text,
    Map<String, String> style, {
    bool isBreak = false,
  }) {
    return {
      'text': text,
      'bold': style['bold'] ?? 'false',
      'italic': style['italic'] ?? 'false',
      if (style['underline'] == 'true') 'underline': 'true',
      if (style['strike'] == 'true') 'strike': 'true',
      if ((style['color'] ?? '').isNotEmpty) 'color': style['color']!,
      if ((style['highlight'] ?? '').isNotEmpty)
        'highlight': style['highlight']!,
      if ((style['size'] ?? '').isNotEmpty) 'size': style['size']!,
      if ((style['font'] ?? '').isNotEmpty) 'font': style['font']!,
      if ((style['align'] ?? '').isNotEmpty) 'align': style['align']!,
      if ((style['href'] ?? '').isNotEmpty) 'href': style['href']!,
      if (isBreak) 'isBreak': 'true',
    };
  }

  static List<Map<String, dynamic>> _extractBlocks(
    dom.Element element, [
    Map<String, String> inheritedStyle = const {},
  ]) {
    final result = <Map<String, dynamic>>[];
    List<Map<String, String>> currentParagraphs = [];
    List<Map<String, String>> currentListItems = [];
    bool currentListOrdered = false;
    bool inList = false;

    void flushParagraphs() {
      if (currentParagraphs.isNotEmpty) {
        result.add({
          'type': 'text',
          'paragraphs': List.from(currentParagraphs),
        });
        currentParagraphs = [];
      }
    }

    void flushList() {
      if (currentListItems.isNotEmpty) {
        result.add({
          'type': 'list',
          'items': List.from(currentListItems),
          'ordered': currentListOrdered,
        });
        currentListItems = [];
      }
      inList = false;
    }

    for (final node in element.nodes) {
      if (node is dom.Text) {
        final normalized = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (normalized.isNotEmpty) {
          if (inList) flushList();
          final run = _makeRun(normalized, inheritedStyle);
          if (currentParagraphs.isEmpty) run['paragraphStart'] = 'true';
          currentParagraphs.add(run);
        }
      } else if (node is dom.Element) {
        final tag = node.localName;
        final style = _mergeElementStyle(node, inheritedStyle);

        if (tag == 'br') {
          final run = _makeRun('', inheritedStyle, isBreak: true);
          if (inList) {
            if (currentListItems.isEmpty) run['itemStart'] = 'true';
            currentListItems.add(run);
          } else {
            if (currentParagraphs.isEmpty) {
              run['paragraphStart'] = 'true';
            }
            currentParagraphs.add(run);
          }
        } else if (tag == 'img') {
          flushParagraphs();
          flushList();
          final src = node.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            result.add({'type': 'image', 'src': src});
          }
        } else if (tag == 'video' &&
            node.attributes.containsKey('data-video')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'video',
            'data-video': node.attributes['data-video'] ?? '',
            'poster': node.attributes['poster'] ?? '',
            'src': node.attributes['src'] ?? '',
          });
        } else if (tag == 'span' && node.attributes.containsKey('data-icon')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'icon',
            'data-icon': node.attributes['data-icon'] ?? '',
          });
        } else if (tag == 'div' &&
            node.attributes.containsKey('data-smartart')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'smartart',
            'data-smartart': node.attributes['data-smartart'] ?? '',
          });
        } else if (tag == 'div' &&
            node.attributes.containsKey('data-model3d')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'model3d',
            'data-model3d': node.attributes['data-model3d'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-chart')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'chart',
            'data-chart': node.attributes['data-chart'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-action')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'action',
            'data-action': node.attributes['data-action'] ?? '',
          });
        } else if (tag == 'div' &&
            node.attributes.containsKey('data-equation')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'equation',
            'data-equation': node.attributes['data-equation'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-ole')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'ole',
            'data-ole': node.attributes['data-ole'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-zoom')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'zoom',
            'data-zoom': node.attributes['data-zoom'] ?? '',
          });
        } else if (tag == 'div' &&
            node.attributes.containsKey('data-sectionzoom')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'sectionzoom',
            'data-sectionzoom': node.attributes['data-sectionzoom'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-cameo')) {
          flushParagraphs();
          flushList();
          result.add({
            'type': 'cameo',
            'data-cameo': node.attributes['data-cameo'] ?? '',
          });
        } else if (tag == 'p' ||
            tag == 'div' ||
            tag == 'h1' ||
            tag == 'h2' ||
            tag == 'h3' ||
            tag == 'h4' ||
            tag == 'h5' ||
            tag == 'h6') {
          flushList();

          final hasBlockChildren = node.children.any(
            (c) => const [
              'img',
              'ul',
              'ol',
              'table',
              'p',
              'div',
            ].contains(c.localName),
          );
          if ((tag == 'div' || tag == 'p') && hasBlockChildren) {
            flushParagraphs();
            result.addAll(_extractBlocks(node, style));
            continue;
          }
          var subPars = _extractInlineParagraphs(node, style);
          if (subPars.isNotEmpty) {
            if (tag != null && tag.startsWith('h')) {
              for (final p in subPars) {
                p['bold'] = 'true';
                p['italic'] = p['italic'] ?? 'false';
              }
            }
            subPars = _prepareRunGroup(subPars, 'paragraphStart');
            currentParagraphs.addAll(subPars);
          }
        } else if (tag == 'ul' || tag == 'ol') {
          flushParagraphs();
          flushList();
          inList = true;
          currentListOrdered = (tag == 'ol');
          for (final child in node.nodes) {
            if (child is dom.Element && child.localName == 'li') {
              final liStyle = _mergeElementStyle(child, style);
              final items = _prepareRunGroup(
                _extractInlineParagraphs(child, liStyle),
                'itemStart',
              );
              for (final item in items) {
                currentListItems.add(item);
              }
            }
          }
        } else if (tag == 'table') {
          flushParagraphs();
          flushList();
          final tableData = _extractTable(node);
          if (tableData.isNotEmpty) {
            result.add({
              'type': 'table',
              'rows': tableData,
              'headerRow': node.querySelector('tr th') != null,
            });
          }
        } else if (tag == 'strong' || tag == 'b') {
          var children = _extractInlineParagraphs(node, {
            ...style,
            'bold': 'true',
          });
          if (inList && currentListItems.isEmpty) {
            children = _prepareRunGroup(children, 'itemStart');
          } else if (!inList && currentParagraphs.isEmpty) {
            children = _prepareRunGroup(children, 'paragraphStart');
          }
          for (final child in children) {
            if (inList) {
              currentListItems.add(child);
            } else {
              currentParagraphs.add(child);
            }
          }
        } else if (tag == 'em' || tag == 'i') {
          var children = _extractInlineParagraphs(node, {
            ...style,
            'italic': 'true',
          });
          if (inList && currentListItems.isEmpty) {
            children = _prepareRunGroup(children, 'itemStart');
          } else if (!inList && currentParagraphs.isEmpty) {
            children = _prepareRunGroup(children, 'paragraphStart');
          }
          for (final child in children) {
            if (inList) {
              currentListItems.add(child);
            } else {
              currentParagraphs.add(child);
            }
          }
        } else {
          final subBlocks = _extractBlocks(node, style);
          for (final block in subBlocks) {
            if (block['type'] == 'text') {
              currentParagraphs.addAll(
                (block['paragraphs'] as List).cast<Map<String, String>>(),
              );
            } else if (block['type'] == 'list' ||
                block['type'] == 'image' ||
                block['type'] == 'table') {
              flushParagraphs();
              result.add(block);
            }
          }
        }
      }
    }

    flushParagraphs();
    flushList();
    return result;
  }

  static List<Map<String, String>> _extractInlineParagraphs(
    dom.Element element, [
    Map<String, String> inheritedStyle = const {},
  ]) {
    final result = <Map<String, String>>[];
    for (final node in element.nodes) {
      if (node is dom.Text) {
        final normalized = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (normalized.trim().isNotEmpty) {
          result.add(_makeRun(normalized, inheritedStyle));
        }
      } else if (node is dom.Element) {
        final tag = node.localName;
        final style = _mergeElementStyle(node, inheritedStyle);
        if (tag == 'br') {
          result.add(_makeRun('', inheritedStyle, isBreak: true));
        } else if (tag == 'strong' || tag == 'b') {
          result.addAll(
            _extractInlineParagraphs(node, {...style, 'bold': 'true'}),
          );
        } else if (tag == 'em' || tag == 'i') {
          result.addAll(
            _extractInlineParagraphs(node, {...style, 'italic': 'true'}),
          );
        } else if (tag == 'u' || tag == 'ins') {
          result.addAll(
            _extractInlineParagraphs(node, {...style, 'underline': 'true'}),
          );
        } else if (tag == 's' || tag == 'del' || tag == 'strike') {
          result.addAll(
            _extractInlineParagraphs(node, {...style, 'strike': 'true'}),
          );
        } else if (tag == 'a') {
          final href = node.attributes['href'] ?? '';
          result.addAll(
            _extractInlineParagraphs(
              node,
              href.isNotEmpty ? {...style, 'href': href} : style,
            ),
          );
        } else {
          result.addAll(_extractInlineParagraphs(node, style));
        }
      }
    }
    return result;
  }

  static List<List<Map<String, String>>> _extractTable(dom.Element tableEl) {
    final rows = <List<Map<String, String>>>[];
    for (final child in tableEl.nodes) {
      if (child is dom.Element) {
        if (child.localName == 'thead') {
          for (final th in child.nodes) {
            if (th is dom.Element && th.localName == 'tr') {
              rows.add(_extractTableRow(th));
            }
          }
        } else if (child.localName == 'tbody') {
          for (final tr in child.nodes) {
            if (tr is dom.Element && tr.localName == 'tr') {
              rows.add(_extractTableRow(tr));
            }
          }
        } else if (child.localName == 'tr') {
          rows.add(_extractTableRow(child));
        }
      }
    }
    return rows;
  }

  static List<Map<String, String>> _extractTableRow(dom.Element tr) {
    final cells = <Map<String, String>>[];
    for (final child in tr.nodes) {
      if (child is dom.Element &&
          (child.localName == 'th' || child.localName == 'td')) {
        final style = _mergeElementStyle(child, const {});
        final text = child.text.trim();
        final isHeader = child.localName == 'th';
        final cell = _makeRun(text, style);
        if (isHeader) cell['bold'] = 'true';
        cells.add(cell);
      }
    }
    return cells;
  }

  static List<Map<String, String>> _prepareRunGroup(
    List<Map<String, String>> runs,
    String startMarker,
  ) {
    final prepared = runs.map(Map<String, String>.from).toList();
    if (prepared.isEmpty) return prepared;

    for (final run in prepared) {
      if (run['isBreak'] != 'true') {
        run['text'] = (run['text'] ?? '').replaceAll(RegExp(r'\s+'), ' ');
      }
    }
    final textRuns = prepared.where((run) => run['isBreak'] != 'true').toList();
    if (textRuns.isNotEmpty) {
      textRuns.first['text'] = (textRuns.first['text'] ?? '').trimLeft();
      textRuns.last['text'] = (textRuns.last['text'] ?? '').trimRight();
    }
    prepared.removeWhere(
      (run) => run['isBreak'] != 'true' && (run['text'] ?? '').isEmpty,
    );
    if (prepared.isNotEmpty) prepared.first[startMarker] = 'true';
    return prepared;
  }
}

class HtmlParseCache {
  HtmlParseCache({int capacity = 128}) : _capacity = capacity;

  static final HtmlParseCache shared = HtmlParseCache();

  final int _capacity;

  final Map<String, ParsedHtmlEntry> _entries = {};

  int hits = 0;
  int misses = 0;

  double parseMs = 0;

  static String _fnv1a64(String input) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _keyFor(String html) => _fnv1a64(html);

  void _touch(String key) {
    final entry = _entries.remove(key);
    if (entry != null) _entries[key] = entry;
  }

  ParsedHtmlEntry entryFor(String html) {
    final key = _keyFor(html);
    final cached = _entries[key];
    if (cached != null && cached.html == html) {
      hits++;
      _touch(key);
      return cached;
    }

    misses++;

    final bgColorMatch = HtmlAttrScan.bgColorAttrRe.firstMatch(html);
    final bgColor = bgColorMatch?.group(1);
    final rust = HtmlParseCodec.parseToJson(html);
    final notes = rust?.notes ?? '';
    final subtitle =
        rust != null ? (rust.subtitle.isEmpty ? null : rust.subtitle) : null;
    if (rust != null) {
      final entry = ParsedHtmlEntry(
        html,
        notes: notes,
        subtitle: subtitle,
        blocks: rust.blocks,
        blocksNoFirstH2: rust.blocksNoFirstH2,
        bgColor: bgColor,
      );
      _entries[key] = entry;
      if (_entries.length > _capacity) {
        _entries.remove(_entries.keys.first);
      }
      return entry;
    }
    final watch = Stopwatch()..start();
    final doc = html_parser.parse(html);
    parseMs += watch.elapsedMicroseconds / 1000;
    final dartNotes = doc.querySelector('aside.notes')?.text.trim() ?? '';
    final h2 = doc.querySelector('h2');
    final dartSubtitle =
        (h2 != null && h2.text.trim().isNotEmpty) ? h2.text.trim() : null;
    final blocks = HtmlParseCore.parseHtmlContentFullFromDoc(
      doc,
      fallbackText: html,
    );

    final h2Again = doc.querySelector('h2');
    if (h2Again != null) h2Again.remove();
    final blocksNoFirstH2 = HtmlParseCore.parseHtmlContentFullFromDoc(
      doc,
      fallbackText: html,
    );

    final entry = ParsedHtmlEntry(
      html,
      notes: dartNotes,
      subtitle: dartSubtitle,
      blocks: blocks,
      blocksNoFirstH2: blocksNoFirstH2,
      bgColor: bgColor,
    );
    _entries[key] = entry;
    if (_entries.length > _capacity) {
      _entries.remove(_entries.keys.first);
    }
    return entry;
  }

  String notesFor(String html) => entryFor(html).notes;

  String? subtitleFor(String html) => entryFor(html).subtitle;

  SlideDocument documentFor(String html) {
    final entry = entryFor(html);
    return SlideDocument.fromParts(
      html: html,
      notes: entry.notes,
      subtitle: entry.subtitle,
      legacyBlocks: entry.blocks,
      bgColor: entry.bgColor,
    );
  }

  List<Map<String, dynamic>> blocksFor(
    String html, {
    bool dropFirstH2 = false,
  }) {
    final entry = entryFor(html);
    return dropFirstH2 ? entry.blocksNoFirstH2 : entry.blocks;
  }

  void clear() {
    _entries.clear();
    hits = 0;
    misses = 0;
    parseMs = 0;
  }
}

class ParsedHtmlEntry {
  ParsedHtmlEntry(
    this.html, {
    required this.notes,
    required this.subtitle,
    required this.blocks,
    required this.blocksNoFirstH2,
    required this.bgColor,
  });

  final String html;
  final String notes;
  final String? subtitle;
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> blocksNoFirstH2;
  final String? bgColor;

  String? get bgColorValue => bgColor;
}
