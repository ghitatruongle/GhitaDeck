import 'dart:math' as math;

import '../models/smartart.dart';

/// SmartArt rendering + HTML-block helpers shared by every export format
/// (Track 10). Diagrams live inside slide HTML as
/// `<div data-smartart='…json…'>` blocks.
class SmartArtService {
  SmartArtService._();

  static final RegExp _blockRegExp = RegExp(
      r"""data-smartart=(['"])(.*?)\1""",
      caseSensitive: false,
      dotAll: true);

  /// Every diagram embedded in [html] (document order).
  static List<SmartArtGraph> diagramsIn(String html) {
    final result = <SmartArtGraph>[];
    for (final m in _blockRegExp.allMatches(html)) {
      final graph = SmartArtGraph.fromJson(m.group(2)!);
      if (graph != null) result.add(graph);
    }
    return result;
  }

  /// Markup for inserting [graph] into slide HTML (single-quoted attribute).
  static String smartartMarkup(SmartArtGraph graph) =>
      '<div data-smartart=\'${graph.toJson().replaceAll("'", '&#39;')}\'></div>';

  /// Replace the [index]-th diagram in [html] with the markup of [graph].
  static String replaceDiagramAt(String html, int index, SmartArtGraph graph) {
    final matches = _blockRegExp.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    final start = html.lastIndexOf('<div', match.start);
    final end = html.indexOf('</div>', match.end);
    if (start < 0 || end < 0) return html;
    return html.replaceRange(start, end + '</div>'.length, smartartMarkup(graph));
  }

  // ---- SVG rendering ----------------------------------------------------

  static const double svgWidth = 640;
  static const double svgHeight = 360;

  /// Inline SVG for [graph] (same visual language as PDF/PPTX).
  static String renderSvg(SmartArtGraph graph) {
    final b = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" '
          'viewBox="0 0 640 360" font-family="Segoe UI, Arial, sans-serif">');
    final nodes = graph.orderedNodes;
    if (nodes.isEmpty) {
      _text(b, 'Không có nội dung SmartArt', 320, 180,
          size: 14, anchor: 'middle', fill: '#888888');
      b.write('</svg>');
      return b.toString();
    }
    switch (graph.layout.group) {
      case SmartArtGroup.list:
        _renderList(b, graph, nodes);
      case SmartArtGroup.process:
        _renderProcess(b, graph, nodes);
      case SmartArtGroup.cycle:
        _renderCycle(b, graph, nodes);
      case SmartArtGroup.hierarchy:
        _renderHierarchy(b, graph, nodes);
      case SmartArtGroup.relationship:
        _renderRelationship(b, graph, nodes);
      case SmartArtGroup.matrix:
        _renderMatrix(b, graph, nodes);
      case SmartArtGroup.pyramid:
        _renderPyramid(b, graph, nodes);
      case SmartArtGroup.picture:
        _renderPicture(b, graph, nodes);
    }
    b.write('</svg>');
    return b.toString();
  }

  static void _text(StringBuffer b, String text, double x, double y,
      {double size = 11,
      String anchor = 'start',
      String fill = '#333333',
      String weight = 'normal'}) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    b.write('<text x="$x" y="$y" font-size="$size" font-weight="$weight" '
        'text-anchor="$anchor" fill="$fill">$escaped</text>');
  }

  static String _color(SmartArtGraph g, int index) =>
      g.colorTheme.colorAt(index);

  /// Word-wrap node text into at most [maxLines] short lines.
  static List<String> _lines(String text, {int maxLines = 2}) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final lines = <String>[];
    var current = '';
    for (final w in words) {
      if (current.isNotEmpty && current.length + w.length > 14) {
        lines.add(current);
        current = w;
      } else {
        current = current.isEmpty ? w : '$current $w';
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.take(maxLines).toList();
  }

  static void _box(StringBuffer b, double x, double y, double w, double h,
      SmartArtGraph g, int index, String text,
      {String? fill, String stroke = '#333333'}) {
    b.write('<rect x="$x" y="$y" width="$w" height="$h" rx="6" '
        'fill="${fill ?? '#${_color(g, index)}'}" stroke="$stroke"/>');
    final lines = _lines(text);
    for (var i = 0; i < lines.length; i++) {
      _text(b, lines[i], x + w / 2, y + h / 2 + (i - lines.length / 2) * 14 + 4,
          anchor: 'middle', size: 12, fill: '#ffffff', weight: 'bold');
    }
  }

  static void _renderList(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    final n = math.max(nodes.length, 1);
    final slotH = 300.0 / n;
    final boxH = math.max(slotH - 14, 24.0);
    for (var i = 0; i < nodes.length; i++) {
      _box(b, 60, 20 + i * slotH, 520, boxH, g, i, nodes[i].text);
    }
  }

  static void _renderProcess(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    final n = math.max(nodes.length, 1);
    final slotW = 560.0 / n;
    final boxW = slotW - 26;
    for (var i = 0; i < nodes.length; i++) {
      final x = 40 + i * slotW;
      // Chevron-ish box with an arrow tail.
      _box(b, x, 120, boxW, 120, g, i, nodes[i].text);
      if (i < nodes.length - 1) {
        b.write('<polygon points="${x + boxW},150 ${x + boxW + 20},120 '
            '${x + boxW + 20},180" fill="#${_color(g, i)}"/>');
      }
    }
  }

  static void _renderCycle(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    const cx = 320.0;
    const cy = 170.0;
    const r = 110.0;
    final n = math.max(nodes.length, 1);
    var angle = -math.pi / 2;
    for (var i = 0; i < nodes.length; i++) {
      final sweep = 2 * math.pi / n;
      final x = cx + math.cos(angle) * r - 45;
      final y = cy + math.sin(angle) * r - 30;
      _box(b, x, y, 90, 60, g, i, nodes[i].text);
      angle += sweep;
    }
    b.write('<circle cx="$cx" cy="$cy" r="38" fill="none" '
        'stroke="#${_color(g, 0)}" stroke-width="3" stroke-dasharray="5 4"/>');
  }

  static void _renderHierarchy(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    final top = nodes.where((n) => n.parentId == null).toList();
    if (top.isEmpty) return _renderList(b, g, nodes);
    final t = top.first;
    _box(b, 220, 20, 200, 50, g, 0, t.text);
    final kids = g.childrenOf(t.id);
    if (kids.isEmpty) return;
    final k = math.max(kids.length, 1);
    final slotW = 560.0 / k;
    for (var i = 0; i < kids.length; i++) {
      final cx = 40 + i * slotW + slotW / 2;
      b.write('<line x1="320" y1="70" x2="$cx" y2="100" stroke="#888"/>');
      _box(b, cx - 70, 100, 140, 60, g, i + 1, kids[i].text);
    }
  }

  static void _renderRelationship(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    final n = math.max(nodes.length, 1);
    final slotW = 560.0 / n;
    for (var i = 0; i < nodes.length; i++) {
      final x = 40 + i * slotW;
      _box(b, x + 4, 130, slotW - 24, 100, g, i, nodes[i].text);
      if (i < nodes.length - 1) {
        b.write('<circle cx="${x + slotW - 6}" cy="180" r="6" '
            'fill="#${_color(g, i)}"/>');
      }
    }
  }

  static void _renderMatrix(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    const cols = 2;
    const cellW = 250.0;
    const cellH = 110.0;
    for (var i = 0; i < nodes.length; i++) {
      final r = i ~/ cols;
      final c = i % cols;
      _box(b, 70 + c * (cellW + 20), 30 + r * (cellH + 20), cellW, cellH, g, i,
          nodes[i].text);
    }
  }

  static void _renderPyramid(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    final n = math.max(nodes.length, 1);
    final slotH = 300.0 / n;
    var y = 20.0;
    for (var i = 0; i < nodes.length; i++) {
      final frac = (n - i) / n;
      final w = 500 * frac;
      final x = 320 - w / 2;
      b.write('<path d="M $x $y L ${x + w} $y L ${x + w * 0.8} ${y + slotH} '
          'L ${x + w * 0.2} ${y + slotH} Z" fill="#${_color(g, i)}"/>');
      final lines = _lines(nodes[i].text);
      for (var j = 0; j < lines.length; j++) {
        _text(b, lines[j], 320, y + slotH / 2 + (j - lines.length / 2) * 13 + 4,
            anchor: 'middle', size: 11, fill: '#ffffff', weight: 'bold');
      }
      y += slotH;
    }
  }

  static void _renderPicture(StringBuffer b, SmartArtGraph g, List<SmartArtNode> nodes) {
    final n = math.max(nodes.length, 1);
    final slotH = 300.0 / n;
    for (var i = 0; i < nodes.length; i++) {
      final y = 20 + i * slotH;
      b.write('<rect x="60" y="$y" width="80" height="${slotH - 14}" rx="6" '
          'fill="#${_color(g, i)}"/>');
      _text(b, '🖼', 100, y + (slotH - 14) / 2 + 5,
          anchor: 'middle', size: 18);
      _box(b, 160, y, 420, slotH - 14, g, i, nodes[i].text);
    }
  }
}