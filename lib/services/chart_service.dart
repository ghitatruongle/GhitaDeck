import 'dart:math' as math;

import '../models/chart_data.dart';

/// Chart rendering + detection shared by every output format (Track 08).
///
/// Charts live inside slide HTML as
/// `<div data-chart='{"type":"column",…}'></div>` blocks. Each export
/// pipeline picks them up:
///
///  * HTML deck → [renderSvg] inline SVG (self-generated, layout-free),
///  * PPTX → a real DrawingML `<c:chart>` part + embedded xlsx,
///  * PDF → a painted [ChartPdfView]-style widget (see pdf_export_service).
class ChartService {
  ChartService._();

  /// Find every chart definition embedded in [html] (document order).
  static List<ChartData> chartsIn(String html) {
    final charts = <ChartData>[];
    for (final match in _dataChartRegExp.allMatches(html)) {
      // group(1) is the quote character; group(2) carries the JSON.
      final chart = ChartData.fromJson(match.group(2)!);
      if (chart != null) charts.add(chart);
    }
    return charts;
  }

  static final RegExp _dataChartRegExp = RegExp(
      r"""data-chart=(['"])(.*?)\1""",
      caseSensitive: false,
      dotAll: true,
    );

  /// Escape chart JSON for the `data-chart='…'` attribute.
  static String escapeAttribute(ChartData chart) =>
      chart.toJson().replaceAll("'", '&#39;');

/// Markup for inserting [chart] into slide HTML (single-quoted attribute —
/// the JSON keeps its double quotes, only inner single quotes are escaped).
  static String chartMarkup(ChartData chart) =>
      '<div data-chart=\'${escapeAttribute(chart)}\'></div>';

  /// Replace the [index]-th chart block in [html] with the markup of
  /// [chart]; returns [html] unchanged when the index is out of range.
  static String replaceChartAt(String html, int index, ChartData chart) {
    final matches = _dataChartRegExp.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    final start = html.lastIndexOf('<div', match.start);
    final end = html.indexOf('</div>', match.end);
    if (start < 0 || end < 0) return html;
    return html.replaceRange(start, end + '</div>'.length, chartMarkup(chart));
  }

  // ---- SVG rendering (P6) ----------------------------------------------

  static const double svgWidth = 640;
  static const double svgHeight = 400;
  static const double _plotX = 52;
  static const double _plotY = 44;
  static const double _plotW = 560;
  static const double _plotH = 296;

  /// A self-contained inline SVG for [chart].
  static String renderSvg(ChartData chart) {
    final b = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" width="640" height="400" '
          'viewBox="0 0 640 400" font-family="Segoe UI, Arial, sans-serif">');
    if (chart.title.isNotEmpty) {
      _text(b, chart.title, 320, 22, size: 15, weight: 'bold',
          anchor: 'middle', fill: '#222222');
    }
    // Track 09, P10: no data → a friendly placeholder instead of an empty
    // plot area.
    if (chart.series.isEmpty ||
        chart.series.every((s) => s.values.isEmpty)) {
      _text(b, 'Không có dữ liệu biểu đồ', 320, 210,
          size: 14, anchor: 'middle', fill: '#888888');
      b.write('</svg>');
      return b.toString();
    }
    switch (chart.type) {
      case ChartType.column:
      case ChartType.histogram:
        _renderColumns(b, chart, horizontal: false);
      case ChartType.bar:
        _renderColumns(b, chart, horizontal: true);
      case ChartType.line:
        _renderLine(b, chart);
      case ChartType.area:
        _renderArea(b, chart);
      case ChartType.pie:
        _renderPie(b, chart, donut: false);
      case ChartType.donut:
        _renderPie(b, chart, donut: true);
      case ChartType.combo:
        _renderCombo(b, chart);
      case ChartType.treemap:
        _renderTreemap(b, chart);
      case ChartType.sunburst:
        _renderSunburst(b, chart);
      case ChartType.boxWhisker:
        _renderBoxWhisker(b, chart);
      case ChartType.waterfall:
        _renderWaterfall(b, chart);
      case ChartType.funnel:
        _renderFunnel(b, chart);
      case ChartType.map:
        _renderMap(b, chart);
    }
    if (chart.style.showLegend && chart.series.length > 1) {
      _legend(b, chart);
    }
    b.write('</svg>');
    return b.toString();
  }

  // ---- Shared SVG helpers ----

  static void _text(
    StringBuffer b,
    String text,
    double x,
    double y, {
    double size = 11,
    String weight = 'normal',
    String anchor = 'start',
    String fill = '#333333',
  }) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    b.write('<text x="$x" y="$y" font-size="$size" font-weight="$weight" '
        'text-anchor="$anchor" fill="$fill">$escaped</text>');
  }

  static void _legend(StringBuffer b, ChartData chart) {
    var x = 320.0 -
        (chart.series.length * 70.0 - 10) / 2;
    for (final s in chart.series) {
      final color = chart.style.colorAt(chart.series.indexOf(s));
      b.write('<rect x="$x" y="372" width="10" height="10" fill="#$color"/>');
      _text(b, s.name, x + 14, 381);
      x += 70;
    }
  }

  static double _scale(ChartData chart) {
    final max = chart.maxValue == 0 ? 1.0 : chart.maxValue;
    return _plotH / max;
  }

  static void _renderColumns(StringBuffer b, ChartData chart,
      {required bool horizontal}) {
    final n = math.max(chart.categories.length, 1);
    final seriesCount = math.max(chart.series.length, 1);
    final groupW = _plotW / n;
    final barW =
        (groupW * (chart.style.stacked ? 0.75 : 0.72) / seriesCount)
            .clamp(6.0, 60.0);
    final scale = _scale(chart);

    for (var c = 0; c < chart.categories.length; c++) {
      if (!horizontal) {
        _text(b, chart.categories[c],
            _plotX + groupW * c + groupW / 2, _plotY + _plotH + 14,
            anchor: 'middle', size: 9);
      } else {
        _text(b, chart.categories[c], _plotX - 8,
            _plotY + _plotH - (groupW * c + groupW / 2),
            anchor: 'end', size: 9);
      }

      if (chart.style.stacked) {
        // One cumulative column per category (positive values stack up).
        var stackY = _plotY + _plotH;
        for (var s = 0; s < chart.series.length; s++) {
          final v = chart.valueAt(s, c);
          final color = chart.style.colorAt(s);
          final h = v.abs() * scale;
          if (horizontal) {
            b.write('<rect x="$_plotX" y="${_plotY + _plotH - (groupW * c + groupW / 2) - barW / 2}" '
                'width="${v.abs() * scale}" height="$barW" fill="#$color"/>');
          } else {
            stackY -= h;
            b.write('<rect x="${_plotX + groupW * c + (groupW - barW) / 2}" '
                'y="$stackY" width="$barW" height="${math.max(h, 1)}" fill="#$color"/>');
          }
        }
        continue;
      }

      for (var s = 0; s < chart.series.length; s++) {
        final v = chart.valueAt(s, c);
        final color = chart.style.colorAt(s);
        final slotX = _plotX + groupW * c +
            (groupW - barW) * s / math.max(seriesCount - 1, 1) +
            (groupW - barW) / 2;
        final h = v.abs() * scale;
        if (horizontal) {
          final w = h;
          b.write('<rect x="$_plotX" y="${_plotY + _plotH - (groupW * c + groupW / 2) - barW / 2}" '
              'width="${math.max(w, 1)}" height="$barW" fill="#$color"/>');
        } else {
          b.write('<rect x="$slotX" y="${_plotY + _plotH - h}" '
              'width="$barW" height="${math.max(h, 1)}" fill="#$color"/>');
        }
        if (chart.style.showDataLabels) {
          _text(b, v.toStringAsFixed(0), slotX + barW / 2,
              horizontal
                  ? _plotY + _plotH - (groupW * c + groupW / 2) - barW / 2 - 3
                  : _plotY + _plotH - h - 3,
              anchor: 'middle', size: 8, fill: '#333333');
        }
      }
    }
    // Axes.
    b.write('<line x1="$_plotX" y1="${_plotY + _plotH}" '
        'x2="${_plotX + _plotW}" y2="${_plotY + _plotH}" stroke="#999"/>');
    if (horizontal) {
      b.write('<line x1="$_plotX" y1="$_plotY" '
          'x2="$_plotX" y2="${_plotY + _plotH}" stroke="#999"/>');
    }
  }

  static void _renderLine(StringBuffer b, ChartData chart) {
    final n = math.max(chart.categories.length - 1, 1);
    final scale = _scale(chart);
    final step = _plotW / n;
    for (var s = 0; s < chart.series.length; s++) {
      final color = chart.style.colorAt(s);
      final points = <String>[];
      for (var c = 0; c < chart.categories.length; c++) {
        final x = _plotX + c * step;
        final y = _plotY + _plotH - chart.valueAt(s, c) * scale;
        points.add('$x,$y');
      }
      b.write('<polyline points="${points.join(' ')}" fill="none" '
          'stroke="#$color" stroke-width="2.5" stroke-linejoin="round"/>');
      for (var c = 0; c < chart.categories.length; c++) {
        final x = _plotX + c * step;
        final y = _plotY + _plotH - chart.valueAt(s, c) * scale;
        b.write('<circle cx="$x" cy="$y" r="3" fill="#$color"/>');
      }
    }
    for (var c = 0; c < chart.categories.length; c++) {
      _text(b, chart.categories[c], _plotX + c * step, _plotY + _plotH + 14,
          anchor: 'middle', size: 9);
    }
    b.write('<line x1="$_plotX" y1="${_plotY + _plotH}" '
        'x2="${_plotX + _plotW}" y2="${_plotY + _plotH}" stroke="#999"/>');
  }

  static void _renderArea(StringBuffer b, ChartData chart) {
    final n = math.max(chart.categories.length - 1, 1);
    final scale = _scale(chart);
    final step = _plotW / n;
    for (var s = 0; s < chart.series.length; s++) {
      final color = chart.style.colorAt(s);
      final points = <String>[];
      for (var c = 0; c < chart.categories.length; c++) {
        final x = _plotX + c * step;
        final y = _plotY + _plotH - chart.valueAt(s, c) * scale;
        points.add('$x,$y');
      }
      final closed = [
        ...points,
        '${_plotX + (chart.categories.length - 1) * step},${_plotY + _plotH}',
        '$_plotX,${_plotY + _plotH}',
      ].join(' ');
      b.write('<polygon points="$closed" fill="#$color" opacity="0.35"/>');
      b.write('<polyline points="${points.join(' ')}" fill="none" '
          'stroke="#$color" stroke-width="2.5"/>');
    }
    for (var c = 0; c < chart.categories.length; c++) {
      _text(b, chart.categories[c], _plotX + c * step, _plotY + _plotH + 14,
          anchor: 'middle', size: 9);
    }
  }

  static void _renderPie(StringBuffer b, ChartData chart,
      {required bool donut}) {
    final s = chart.series.isNotEmpty
        ? chart.series.first
        : const ChartSeries(name: '', values: []);
    final total = s.values.fold<double>(0, (a, v) => a + v.abs());
    if (total <= 0) return;
    const cx = 320.0;
    const cy = _plotY + _plotH / 2 + 6;
    final r = donut ? 78.0 : 110.0;
    final innerR = donut ? 52.0 : 0.0;
    var angle = -math.pi / 2;
    for (var c = 0; c < s.values.length; c++) {
      final sweep = s.values[c].abs() / total * 2 * math.pi;
      final color = chart.style.colorAt(c);
      if (donut) {
        // Donut slice via stroke-dasharray on a circle.
        final dash = sweep * r;
        final gap = (2 * math.pi - sweep) * r;
        b.write('<circle cx="$cx" cy="$cy" r="$r" fill="none" '
            'stroke="#$color" stroke-width="${2 * (r - innerR)}" '
            'stroke-dasharray="$dash $gap" transform="rotate(${(angle * 180 / math.pi).toStringAsFixed(2)} $cx $cy)"/>');
      } else {
        final x1 = cx + math.cos(angle) * r;
        final y1 = cy + math.sin(angle) * r;
        final x2 = cx + math.cos(angle + sweep) * r;
        final y2 = cy + math.sin(angle + sweep) * r;
        final large = sweep > math.pi ? 1 : 0;
        b.write('<path d="M $cx $cy L $x1 $y1 A $r $r 0 $large 1 $x2 $y2 Z" '
            'fill="#$color" stroke="#fff" stroke-width="1.5"/>');
      }
      angle += sweep;
    }
    // Labels.
    angle = -math.pi / 2;
    for (var c = 0; c < s.values.length; c++) {
      final sweep = s.values[c].abs() / total * 2 * math.pi;
      final mid = angle + sweep / 2;
      final labelR = (donut ? innerR : r) + (donut ? (r - innerR) / 2 : r / 2);
      final lx = cx + math.cos(mid) * labelR;
      final ly = cy + math.sin(mid) * labelR + 4;
      _text(b, chart.categories.isNotEmpty &&
              c < chart.categories.length &&
              chart.categories[c].isNotEmpty
          ? chart.categories[c]
          : s.values[c].toStringAsFixed(0), lx, ly,
          anchor: 'middle', size: 9, weight: 'bold', fill: '#ffffff');
      angle += sweep;
    }
  }

  static void _renderCombo(StringBuffer b, ChartData chart) {
    final n = math.max(chart.categories.length, 1);
    final groupW = _plotW / n;
    final scale = _scale(chart);
    final step = _plotW / math.max(n - 1, 1);
    for (var c = 0; c < chart.categories.length; c++) {
      _text(b, chart.categories[c], _plotX + groupW * c + groupW / 2,
          _plotY + _plotH + 14, anchor: 'middle', size: 9);
    }
    // First series → columns, rest → lines.
    if (chart.series.isNotEmpty) {
      for (var c = 0; c < chart.categories.length; c++) {
        final v = chart.valueAt(0, c);
        final h = v.abs() * scale;
        final barW = (groupW * 0.55).clamp(6.0, 50.0);
        b.write('<rect x="${_plotX + groupW * c + (groupW - barW) / 2}" '
            'y="${_plotY + _plotH - h}" width="$barW" height="$h" '
            'fill="#${chart.style.colorAt(0)}"/>');
      }
    }
    for (var s = 1; s < chart.series.length; s++) {
      final color = chart.style.colorAt(s);
      final points = <String>[];
      for (var c = 0; c < chart.categories.length; c++) {
        points.add('${_plotX + c * step},${_plotY + _plotH - chart.valueAt(s, c) * scale}');
      }
      b.write('<polyline points="${points.join(' ')}" fill="none" '
          'stroke="#$color" stroke-width="2.5"/>');
      for (var c = 0; c < chart.categories.length; c++) {
        b.write('<circle cx="${_plotX + c * step}" '
            'cy="${_plotY + _plotH - chart.valueAt(s, c) * scale}" r="3" '
            'fill="#$color"/>');
      }
    }
    b.write('<line x1="$_plotX" y1="${_plotY + _plotH}" '
        'x2="${_plotX + _plotW}" y2="${_plotY + _plotH}" stroke="#999"/>');
  }

  static void _renderTreemap(StringBuffer b, ChartData chart) {
    final s = chart.series.isNotEmpty ? chart.series.first : null;
    final values = s?.values ?? const <double>[];
    final total = values.fold<double>(0, (a, v) => a + v.abs());
    if (total <= 0) return;
    // Simple slice-and-dice treemap: alternate horizontal/vertical splits.
    var x = _plotX, y = _plotY;
    var w = _plotW, h = _plotH;
    var horizontal = true;
    for (var i = 0; i < values.length; i++) {
      final frac = values[i].abs() / total;
      final color = chart.style.colorAt(i);
      if (horizontal) {
        final sw = w * frac;
        b.write('<rect x="$x" y="$y" width="$sw" height="$h" fill="#$color" '
            'stroke="#fff" stroke-width="1"/>');
        if (chart.categories.isNotEmpty && i < chart.categories.length) {
          _text(b, chart.categories[i], x + 6, y + 16,
              size: 9, fill: '#ffffff');
        }
        x += sw;
        w -= sw;
      } else {
        final sh = h * frac;
        b.write('<rect x="$x" y="$y" width="$w" height="$sh" fill="#$color" '
            'stroke="#fff" stroke-width="1"/>');
        if (chart.categories.isNotEmpty && i < chart.categories.length) {
          _text(b, chart.categories[i], x + 6, y + 16,
              size: 9, fill: '#ffffff');
        }
        y += sh;
        h -= sh;
      }
      horizontal = !horizontal;
    }
  }

  static void _renderSunburst(StringBuffer b, ChartData chart) {
    final s = chart.series.isNotEmpty ? chart.series.first : null;
    final values = s?.values ?? const <double>[];
    final total = values.fold<double>(0, (a, v) => a + v.abs());
    if (total <= 0) return;
    const cx = 320.0;
    const cy = _plotY + _plotH / 2 + 6;
    const outer = 120.0;
    // Categories → one ring segment per category (single series).
    var angle = -math.pi / 2;
    for (var c = 0; c < values.length; c++) {
      final sweep = values[c].abs() / total * 2 * math.pi;
      final color = chart.style.colorAt(c);
      final dash = sweep * outer;
      final gap = (2 * math.pi - sweep) * outer;
      b.write('<circle cx="$cx" cy="$cy" r="$outer" fill="none" '
          'stroke="#$color" stroke-width="24" '
          'stroke-dasharray="$dash $gap" '
          'transform="rotate(${(angle * 180 / math.pi).toStringAsFixed(2)} $cx $cy)"/>');
      angle += sweep;
    }
  }

  static void _renderBoxWhisker(StringBuffer b, ChartData chart) {
    final n = math.max(chart.categories.length, 1);
    final slot = _plotW / n;
    final boxW = (slot * 0.5).clamp(14.0, 70.0);
    for (var c = 0; c < chart.categories.length; c++) {
      _text(b, chart.categories[c], _plotX + slot * c + slot / 2,
          _plotY + _plotH + 14, anchor: 'middle', size: 9);
      final values = <double>[];
      for (final s in chart.series) {
        if (c < s.values.length) values.add(s.values[c]);
      }
      if (values.isEmpty) continue;
      values.sort();
      double pct(double p) =>
          values[(p * (values.length - 1)).round()];
      final median = pct(0.5);
      final q1 = pct(0.25);
      final q3 = pct(0.75);
      final maxV = chart.maxValue == 0 ? 1 : chart.maxValue;
      final scale = _plotH / maxV;
      final cx = _plotX + slot * c + slot / 2;
      final color = chart.style.colorAt(c);
      final yMed = _plotY + _plotH - median * scale;
      final yQ1 = _plotY + _plotH - q1 * scale;
      final yQ3 = _plotY + _plotH - q3 * scale;
      final yHi = _plotY + _plotH - values.last * scale;
      final yLo = _plotY + _plotH - values.first * scale;
      // Whiskers.
      b.write('<line x1="$cx" y1="$yLo" x2="$cx" y2="$yHi" stroke="#666" stroke-width="1.5"/>');
      // Box Q1→Q3.
      b.write('<rect x="${cx - boxW / 2}" y="$yQ3" width="$boxW" '
          'height="${math.max(yQ1 - yQ3, 1)}" fill="#$color" opacity="0.85"/>');
      // Median line.
      b.write('<line x1="${cx - boxW / 2}" y1="$yMed" x2="${cx + boxW / 2}" '
          'y2="$yMed" stroke="#222" stroke-width="2"/>');
    }
  }

  static void _renderWaterfall(StringBuffer b, ChartData chart) {
    final s = chart.series.isNotEmpty ? chart.series.first : null;
    final values = s?.values ?? const <double>[];
    final n = math.max(values.length, 1);
    final slot = _plotW / n;
    final barW = (slot * 0.6).clamp(10.0, 70.0);
    final maxV = values.fold<double>(0, (a, v) => a + v.abs());
    final scale = maxV == 0 ? 1.0 : _plotH / maxV;
    const base = _plotY + _plotH;
    var cumulative = 0.0;
    for (var c = 0; c < values.length; c++) {
      final cx = _plotX + slot * c + slot / 2;
      final v = values[c];
      final rising = v >= 0;
      final h = v.abs() * scale;
      final y = base - cumulative * scale;
      final color = chart.style.colorAt(c);
      _text(b, v.toStringAsFixed(0), cx, y - (rising ? h : 0) - 4,
          anchor: 'middle', size: 8, fill: '#555555');
      b.write('<rect x="${cx - barW / 2}" '
          'y="${y - (rising ? h : 0)}" width="$barW" height="${math.max(h, 1)}" '
          'fill="#$color" stroke="#999"/>');
      // Connector to the next step.
      if (c < values.length - 1) {
        final nextY = base - (cumulative + v) * scale;
        b.write('<line x1="${cx + barW / 2}" y1="$nextY" '
            'x2="${_plotX + slot * (c + 1) + slot / 2 - barW / 2}" y2="$nextY" '
            'stroke="#888" stroke-dasharray="3 2"/>');
      }
      if (chart.categories.isNotEmpty && c < chart.categories.length) {
        _text(b, chart.categories[c], cx, _plotY + _plotH + 14,
            anchor: 'middle', size: 9);
      }
      cumulative += v;
    }
  }

  static void _renderFunnel(StringBuffer b, ChartData chart) {
    final s = chart.series.isNotEmpty ? chart.series.first : null;
    final values = s?.values ?? const <double>[];
    final maxV = values.fold<double>(0, (a, v) => v.abs() > a ? v.abs() : a);
    if (maxV <= 0) return;
    final slotH = _plotH / math.max(values.length, 1);
    var y = _plotY;
    for (var c = 0; c < values.length; c++) {
      final frac = values[c].abs() / maxV;
      final w = _plotW * (0.95 - (1 - frac) * 0.35);
      final x = _plotX + (_plotW - w) / 2;
      final color = chart.style.colorAt(c);
      b.write('<path d="M $x $y L ${x + w} $y L ${x + w * 0.86} ${y + slotH} '
          'L ${x + w * 0.14} ${y + slotH} Z" fill="#$color"/>');
      if (chart.categories.isNotEmpty && c < chart.categories.length) {
        _text(b, chart.categories[c], _plotX + _plotW / 2, y + slotH / 2 + 4,
            anchor: 'middle', size: 10, weight: 'bold', fill: '#ffffff');
      }
      y += slotH;
    }
  }

  static void _renderMap(StringBuffer b, ChartData chart) {
    // Schematic choropleth: no geographic data is stored in the model, so
    // the "map" renders as value-colored region rows (documented).
    final s = chart.series.isNotEmpty ? chart.series.first : null;
    final values = s?.values ?? const <double>[];
    final labels = chart.categories.isEmpty
        ? List.generate(values.length, (i) => 'Region ${i + 1}')
        : chart.categories;
    final maxV = values.fold<double>(0, (a, v) => v.abs() > a ? v.abs() : a);
    final rows = math.max(values.length, 1);
    final slotH = _plotH / rows;
    for (var r = 0; r < values.length; r++) {
      final frac = maxV == 0 ? 0.0 : values[r].abs() / maxV;
      final color = chart.style.colorAt(r);
      final y = _plotY + r * slotH;
      b.write('<rect x="$_plotX" y="$y" width="${_plotW * (0.25 + 0.75 * frac)}" '
          'height="${slotH - 4}" fill="#$color" opacity="${0.45 + 0.55 * frac}"/>');
      _text(b, labels[r], _plotX + 8, y + slotH / 2 + 4,
          size: 10, fill: '#111111');
    }
  }
}