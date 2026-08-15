import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/chart_data.dart';
import '../../services/embedded_workbook_service.dart';

/// Grid data produced by [ChartDataGrid].
class ChartGridData {
  ChartGridData({required this.categories, required this.series});

  final List<String> categories;

  /// (series name, values) pairs in column order.
  final List<(String, List<double>)> series;

  ChartData toChartData({
    ChartType type = ChartType.column,
    String title = '',
    ChartStyle style = const ChartStyle(),
  }) {
    return ChartData(
      type: type,
      title: title,
      categories: categories,
      series: [
        for (final (name, values) in series)
          ChartSeries(name: name, values: values),
      ],
      style: style,
    );
  }
}

/// An Excel-like grid for chart data (Track 09, P1–P2): column A holds the
/// category labels, further columns the series. Supports add/remove rows and
/// columns, cell selection, CSV paste, and quick fill.
class ChartDataGrid extends StatefulWidget {
  const ChartDataGrid({
    super.key,
    this.initialCategories = const [],
    this.initialSeries = const [],
    this.onChanged,
  });

  final List<String> initialCategories;
  final List<(String, List<double>)> initialSeries;
  final ValueChanged<ChartGridData>? onChanged;

  @override
  State<ChartDataGrid> createState() => _ChartDataGridState();
}

class _ChartDataGridState extends State<ChartDataGrid> {
  late List<TextEditingController> _categories;
  late List<TextEditingController> _seriesNames;
  late List<List<TextEditingController>> _values;
  int? _selectedRow;
  int? _selectedCol;

  @override
  void initState() {
    super.initState();
    _categories = [
      for (final c in widget.initialCategories) TextEditingController(text: c),
    ];
    _seriesNames = [
      for (final (name, _) in widget.initialSeries)
        TextEditingController(text: name),
    ];
    _values = [
      for (final (_, values) in widget.initialSeries)
        [
          for (final v in values) TextEditingController(text: _num(v)),
        ],
    ];
    if (_values.isEmpty) _addSeries();
    if (_categories.isEmpty) _addRow();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in _categories) {
      c.dispose();
    }
    for (final c in _seriesNames) {
      c.dispose();
    }
    for (final col in _values) {
      for (final c in col) {
        c.dispose();
      }
    }
    super.dispose();
  }

  ChartGridData get data => ChartGridData(
        categories: [
          for (final c in _categories) c.text.trim(),
        ],
        series: [
          for (var s = 0; s < _values.length; s++)
            (
              _seriesNames[s].text.trim(),
              [
                for (final v in _values[s]) double.tryParse(v.text.trim()) ?? 0,
              ],
            ),
        ],
      );

  void _notify() => widget.onChanged?.call(data);

  void _addRow() {
    setState(() {
      _categories.add(TextEditingController(text: 'Mục ${_categories.length + 1}'));
      for (final col in _values) {
        col.add(TextEditingController(text: '10'));
      }
    });
    _notify();
  }

  void _removeRow() {
    if (_categories.length <= 1) return;
    setState(() {
      _categories.removeLast().dispose();
      for (final col in _values) {
        col.removeLast().dispose();
      }
    });
    _notify();
  }

  void _addSeries() {
    setState(() {
      _seriesNames.add(TextEditingController(text: 'Chuỗi ${_values.length + 1}'));
      _values.add([
        for (var r = 0; r < _categories.length; r++)
          TextEditingController(text: '10'),
      ]);
    });
    _notify();
  }

  void _removeSeries() {
    if (_values.length <= 1) return;
    setState(() {
      _seriesNames.removeLast().dispose();
      for (final c in _values.removeLast()) {
        c.dispose();
      }
    });
    _notify();
  }

  /// Quick fill: the selected column (or the last one) gets 10, 20, 30, …
  void _quickFill() {
    final col = (_selectedCol ?? 0).clamp(0, _values.length - 1);
    setState(() {
      for (var r = 0; r < _categories.length; r++) {
        _values[col][r].text = '${(r + 1) * 10}';
      }
    });
    _notify();
  }

  /// Paste CSV at the selected cell (or replace the whole grid when no cell
  /// is selected).
  void _pasteCsv(String csv) {
    final rows = EmbeddedWorkbookService.parseCsv(csv);
    if (rows.isEmpty) return;
    setState(() {
      if (_selectedRow == null || _selectedCol == null) {
        // Full replace: header row → series names, first column → categories.
        _replaceAll(rows);
      } else {
        // Paste into the selection.
        for (var r = 0; r < rows.length; r++) {
          final targetRow = _selectedRow! + r;
          if (targetRow >= _categories.length) {
            _categories
                .add(TextEditingController(text: 'Mục ${_categories.length + 1}'));
            for (final col in _values) {
              col.add(TextEditingController(text: ''));
            }
          }
          for (var c = 0; c < rows[r].length; c++) {
            final targetCol = _selectedCol! + c;
            if (targetCol >= _values.length) _addSeriesAt(targetCol);
            final cell = rows[r][c];
            if (targetCol == 0) {
              _categories[targetRow].text = cell;
            } else {
              _values[targetCol - 1][targetRow].text = cell;
            }
          }
        }
      }
    });
    _notify();
  }

  void _addSeriesAt(int index) {
    // Keep series count == _values length; pads via _addSeries repeatedly.
    while (index >= _values.length) {
      _seriesNames.add(
          TextEditingController(text: 'Chuỗi ${_values.length + 1}'));
      _values.add([
        for (var r = 0; r < _categories.length; r++)
          TextEditingController(text: '10'),
      ]);
    }
  }

  void _replaceAll(List<List<String>> rows) {
    for (final c in _categories) {
      c.dispose();
    }
    for (final c in _seriesNames) {
      c.dispose();
    }
    for (final col in _values) {
      for (final c in col) {
        c.dispose();
      }
    }
    final maxCols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    _categories = [];
    _seriesNames = [];
    _values = [];
    for (var s = 1; s < maxCols; s++) {
      _seriesNames.add(TextEditingController(
          text: s < rows.first.length ? rows.first[s] : 'Chuỗi $s'));
      _values.add([]);
    }
    if (_values.isEmpty) _addSeries();
    for (var r = 0; r < rows.length; r++) {
      final cat = rows[r].isNotEmpty ? rows[r][0] : '';
      _categories.add(TextEditingController(text: cat));
      for (var s = 0; s < _values.length; s++) {
        _values[s].add(TextEditingController(
            text: s + 1 < rows[r].length ? rows[r][s + 1] : ''));
      }
    }
    if (_categories.isEmpty) _addRow();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const cellWidth = 96.0;
    const cellHeight = 32.0;

    InputDecoration deco(String hint) => InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: InputBorder.none,
        );

    Widget cell(
        TextEditingController controller, int row, int col, String hint) {
      final selected = _selectedRow == row && _selectedCol == col;
      return GestureDetector(
        onTap: () => setState(() {
          _selectedRow = row;
          _selectedCol = col;
        }),
        child: Container(
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.06)
                : null,
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 12),
            decoration: deco(hint),
            onChanged: (_) => _notify(),
            onSubmitted: (_) {},
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              // Header: A + series columns.
              Row(
                children: [
                  Container(
                    width: cellWidth,
                    height: cellHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: const Text('A',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  for (var s = 0; s < _values.length; s++)
                    cell(_seriesNames[s], -1, s + 1, 'B, C, …'),
                ],
              ),
              // Data rows.
              for (var r = 0; r < _categories.length; r++)
                Row(
                  children: [
                    cell(_categories[r], r, 0, 'Nhãn'),
                    for (var s = 0; s < _values.length; s++)
                      cell(_values[s][r], r, s + 1, '0'),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add, size: 14),
              label: Text(l.gridAddRow, style: const TextStyle(fontSize: 11)),
            ),
            TextButton.icon(
              onPressed: _removeRow,
              icon: const Icon(Icons.remove, size: 14),
              label: Text(l.gridRemoveRow, style: const TextStyle(fontSize: 11)),
            ),
            TextButton.icon(
              onPressed: _addSeries,
              icon: const Icon(Icons.add_chart, size: 14),
              label:
                  Text(l.gridAddSeries, style: const TextStyle(fontSize: 11)),
            ),
            TextButton.icon(
              onPressed: _removeSeries,
              icon: const Icon(Icons.remove_circle_outline, size: 14),
              label:
                  Text(l.gridRemoveSeries, style: const TextStyle(fontSize: 11)),
            ),
            TextButton.icon(
              onPressed: _quickFill,
              icon: const Icon(Icons.auto_fix_high, size: 14),
              label: Text(l.gridQuickFill, style: const TextStyle(fontSize: 11)),
            ),
            TextButton.icon(
              onPressed: () => _showPasteDialog(context),
              icon: const Icon(Icons.content_paste, size: 14),
              label: Text(l.gridPasteCsv, style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showPasteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.gridPasteCsv),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Q1, 120, 70\nQ2, 180, 90',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.gridPasteCsv),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      _pasteCsv(result);
    }
  }
}