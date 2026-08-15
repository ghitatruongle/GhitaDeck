import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/chart_data.dart';
import '../../services/chart_service.dart';
import 'chart_data_grid.dart';

/// "Chèn biểu đồ" dialog (Track 08, P7–P8): pick a type, edit title /
/// categories / series, tune options, preview, then insert or replace a
/// chart inside the current slide's HTML (`<div data-chart=…>`), which all
/// three export formats render.
class ChartDialog extends StatefulWidget {
  const ChartDialog({super.key, this.currentHtml = '', this.editIndex});

  /// The current slide HTML — used to list existing charts for editing.
  final String currentHtml;

  /// Index of the chart to edit, or null to insert a new one.
  final int? editIndex;

  @override
  State<ChartDialog> createState() => _ChartDialogState();
}

class _ChartDialogState extends State<ChartDialog> {
  late ChartType _type;
  late final TextEditingController _title;
  late ChartGridData _grid;
  bool _legend = true;
  bool _labels = false;
  bool _stacked = false;

  /// Charts already present in the slide (for the "edit existing" flow).
  late List<ChartData> _existing;

  @override
  void initState() {
    super.initState();
    _existing = ChartService.chartsIn(widget.currentHtml);
    final initial = (widget.editIndex != null &&
            widget.editIndex! < _existing.length)
        ? _existing[widget.editIndex!]
        : ChartData.sample(ChartType.column);
    _type = initial.type;
    _title = TextEditingController(text: initial.title);
    _grid = ChartGridData(
      categories: initial.categories,
      series: [for (final s in initial.series) (s.name, s.values)],
    );
    _legend = initial.style.showLegend;
    _labels = initial.style.showDataLabels;
    _stacked = initial.style.stacked;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  ChartData get _draft => _grid.toChartData(
        type: _type,
        title: _title.text.trim(),
        style: ChartStyle(
          showLegend: _legend,
          showDataLabels: _labels,
          stacked: _stacked,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.insert_chart_outlined),
          const SizedBox(width: 10),
          Text(widget.editIndex == null ? l.insertChart : l.editChart),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_existing.isNotEmpty) ...[
                Text(l.chartExisting,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: widget.editIndex,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 0; i < _existing.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                            '${_existing[i].type.name} — ${_existing[i].title}'),
                      ),
                  ],
                  onChanged: (i) {
                    if (i == null) return;
                    Navigator.of(context).pop('edit:$i');
                  },
                ),
                const SizedBox(height: 12),
              ],
              // Type
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final type in ChartType.values)
                    ChoiceChip(
                      label: Text(_chartTypeName(l, type),
                          style: const TextStyle(fontSize: 11)),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l.chartTitle,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(l.chartData,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              ChartDataGrid(
                initialCategories: _grid.categories,
                initialSeries: _grid.series,
                onChanged: (grid) => _grid = grid,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  Checkbox(
                    value: _legend,
                    onChanged: (v) => setState(() => _legend = v ?? true),
                  ),
                  Text(l.chartLegend),
                  Checkbox(
                    value: _labels,
                    onChanged: (v) => setState(() => _labels = v ?? false),
                  ),
                  Text(l.chartDataLabels),
                  Checkbox(
                    value: _stacked,
                    onChanged: (v) => setState(() => _stacked = v ?? false),
                  ),
                  Text(l.chartStacked),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.chartPreview,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: CustomPaint(
                  painter: _ChartPreviewPainter(_draft),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: Text(widget.editIndex == null ? l.insertChart : l.chartUpdate),
          onPressed: () => Navigator.pop(context, _draft),
        ),
      ],
    );
  }

  static String _chartTypeName(AppLocalizations l, ChartType type) =>
      switch (type) {
        ChartType.column => l.chartColumn,
        ChartType.bar => l.chartBar,
        ChartType.line => l.chartLine,
        ChartType.pie => l.chartPie,
        ChartType.area => l.chartArea,
        ChartType.donut => l.chartDonut,
        ChartType.combo => l.chartCombo,
        ChartType.treemap => l.chartTreemap,
        ChartType.sunburst => l.chartSunburst,
        ChartType.histogram => l.chartHistogram,
        ChartType.boxWhisker => l.chartBoxWhisker,
        ChartType.waterfall => l.chartWaterfall,
        ChartType.funnel => l.chartFunnel,
        ChartType.map => l.chartMap,
      };
}

/// Compact live preview painted with the same palette as the exports.
class _ChartPreviewPainter extends CustomPainter {
  _ChartPreviewPainter(this.chart);

  final ChartData chart;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final plotX = w * 0.08;
    final plotY = h * 0.12;
    final plotW = w * 0.84;
    final plotH = h * 0.8;
    final maxV = chart.maxValue == 0 ? 1.0 : chart.maxValue;
    Color colorAt(int i) =>
        Color(int.parse('FF${chart.style.colorAt(i)}', radix: 16));

    switch (chart.type) {
      case ChartType.pie:
      case ChartType.donut:
        final values =
            chart.series.isNotEmpty ? chart.series.first.values : const <double>[];
        final total = values.fold<double>(0, (a, v) => a + v.abs());
        final center = Offset(plotX + plotW / 2, plotY + plotH / 2);
        final r = math.min(plotW, plotH) / 2;
        var start = -math.pi / 2;
        for (var i = 0; i < values.length; i++) {
          final sweep = values[i].abs() / total * 2 * math.pi;
          final paint = Paint()..color = colorAt(i);
          if (chart.type == ChartType.donut) {
            canvas.drawArc(
                Rect.fromCircle(center: center, radius: r),
                start,
                sweep,
                true,
                Paint()
                  ..color = colorAt(i)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = r * 0.5);
          } else {
            canvas.drawArc(Rect.fromCircle(center: center, radius: r), start,
                sweep, true, paint);
          }
          start += sweep;
        }
        return;
      case ChartType.line:
      case ChartType.area:
      case ChartType.combo:
        final step = plotW / math.max(chart.categories.length - 1, 1);
        for (var s = 0; s < chart.series.length; s++) {
          final path = Path();
          for (var c = 0; c < chart.categories.length; c++) {
            final p = Offset(
                plotX + c * step,
                plotY + plotH - chart.valueAt(s, c) / maxV * plotH);
            c == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(
              path,
              Paint()
                ..color = colorAt(s)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        }
        return;
      default:
        final n = math.max(chart.categories.length, 1);
        final slot = plotW / n;
        final barW = (slot * 0.55).clamp(4.0, 40.0);
        for (var c = 0; c < chart.categories.length; c++) {
          for (var s = 0; s < chart.series.length; s++) {
            final barH = chart.valueAt(s, c) / maxV * plotH;
            canvas.drawRect(
                Rect.fromLTWH(plotX + slot * c + (slot - barW) / 2,
                    plotY + plotH - barH, barW, barH),
                Paint()..color = colorAt(s));
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPreviewPainter oldDelegate) =>
      oldDelegate.chart != chart;
}