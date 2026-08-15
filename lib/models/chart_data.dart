/// Chart model for exported presentations (Track 08, FEAT 1–2).
library;
///
/// Pure Dart + serializable, so chart definitions travel inside slide HTML
/// as `<div data-chart='…json…'>` blocks and cross the worker isolate.
import 'dart:convert';
enum ChartType {
  column,
  bar,
  line,
  pie,
  area,
  donut,
  combo,
  treemap,
  sunburst,
  histogram,
  boxWhisker,
  waterfall,
  funnel,
  map,
}

/// Display preferences shared by every renderer (PPTX/PDF/HTML).
class ChartStyle {
  const ChartStyle({
    this.colors = const [
      '4472C4',
      'ED7D31',
      'A5A5A5',
      'FFC000',
      '5B9BD5',
      '70AD47',
    ],
    this.showLegend = true,
    this.showDataLabels = false,
    this.stacked = false,
  });

  final List<String> colors;
  final bool showLegend;
  final bool showDataLabels;
  final bool stacked;

  String colorAt(int index) =>
      colors[index % colors.length].toUpperCase();

  Map<String, dynamic> toMap() => {
        'colors': colors,
        'showLegend': showLegend,
        'showDataLabels': showDataLabels,
        'stacked': stacked,
      };

  static ChartStyle fromMap(Map<String, dynamic> map) {
    final rawColors = map['colors'];
    return ChartStyle(
      colors: rawColors is List
          ? rawColors.map((e) => e.toString()).toList()
          : const [
              '4472C4',
              'ED7D31',
              'A5A5A5',
              'FFC000',
              '5B9BD5',
              '70AD47',
            ],
      showLegend: map['showLegend'] != false,
      showDataLabels: map['showDataLabels'] == true,
      stacked: map['stacked'] == true,
    );
  }
}

/// One named data series (a row of the chart grid).
class ChartSeries {
  const ChartSeries({required this.name, required this.values});

  final String name;
  final List<double> values;

  Map<String, dynamic> toMap() => {'name': name, 'values': values};

  static ChartSeries fromMap(Map<String, dynamic> map) => ChartSeries(
        name: (map['name'] ?? '').toString(),
        values: (map['values'] as List? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
      );
}

/// A complete chart definition.
class ChartData {
  const ChartData({
    required this.type,
    this.title = '',
    this.categories = const [],
    this.series = const [],
    this.style = const ChartStyle(),
  });

  final ChartType type;
  final String title;
  final List<String> categories;
  final List<ChartSeries> series;
  final ChartStyle style;

  bool get isMultiSeries => series.length > 1;

  /// The largest absolute value across all series (for normalization).
  double get maxValue {
    var max = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        final a = v.abs();
        if (a > max) max = a;
      }
    }
    return max;
  }

  double valueAt(int seriesIndex, int categoryIndex) {
    if (seriesIndex < 0 || seriesIndex >= series.length) return 0;
    final values = series[seriesIndex].values;
    if (categoryIndex < 0 || categoryIndex >= values.length) return 0;
    return values[categoryIndex];
  }

  /// The JSON payload stored in the `data-chart` attribute.
  String toJson() => const JsonEncoder().convert(toMap());

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'categories': categories,
        'series': series.map((s) => s.toMap()).toList(),
        'style': style.toMap(),
      };

  static ChartData? fromJson(String json) {
    try {
      final map = const JsonDecoder().convert(json);
      return fromMap(map as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static ChartData fromMap(Map<String, dynamic> map) {
    final typeName = (map['type'] ?? 'column').toString();
    return ChartData(
      type: ChartType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => ChartType.column,
      ),
      title: (map['title'] ?? '').toString(),
      categories: (map['categories'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      series: (map['series'] as List? ?? const [])
          .map((e) => ChartSeries.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      style: ChartStyle.fromMap(
          Map<String, dynamic>.from((map['style'] as Map?) ?? const {})),
    );
  }

  /// Simple demo chart for the insert dialog preview.
  static ChartData sample(ChartType type) {
    const names = {
      ChartType.column: 'Doanh thu theo quý',
      ChartType.bar: 'So sánh phòng ban',
      ChartType.line: 'Xu hướng tăng trưởng',
      ChartType.pie: 'Cơ cấu thị phần',
      ChartType.area: 'Tích lũy doanh số',
      ChartType.donut: 'Phân bổ ngân sách',
    };
    return ChartData(
      type: type,
      title: names[type] ?? 'Biểu đồ',
      categories: const ['Q1', 'Q2', 'Q3', 'Q4'],
      series: const [
        ChartSeries(name: 'Nội bộ', values: [120, 180, 140, 210]),
        ChartSeries(name: 'Xuất khẩu', values: [70, 90, 110, 130]),
      ],
    );
  }
}