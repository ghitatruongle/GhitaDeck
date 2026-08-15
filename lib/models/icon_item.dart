/// Icon library item (Track 15, FEAT 11).
///
/// Carries a name, category, and SVG path data; the icon travels inside slide
/// HTML as a `<span data-icon='{...}'></span>` block. Every export format reads
/// this block and renders the icon appropriately (PNG for PPTX, inline SVG for
/// HTML, PNG for PDF).
library;

import 'dart:convert';

class IconItem {
  const IconItem({
    this.name = '',
    this.category = '',
    this.svgPath = '',
    this.color = '#000000',
    this.size = 24,
  });

  /// Display name (e.g. "Add", "Home").
  final String name;

  /// Category (e.g. "Arrows", "Business", "UI").
  final String category;

  /// SVG path `d` attribute — the icon shape.
  final String svgPath;

  /// User-selected fill colour (hex, e.g. "#FF0000").
  final String color;

  /// Icon size in pixels.
  final int size;

  IconItem copyWith({
    String? name,
    String? category,
    String? svgPath,
    String? color,
    int? size,
  }) =>
      IconItem(
        name: name ?? this.name,
        category: category ?? this.category,
        svgPath: svgPath ?? this.svgPath,
        color: color ?? this.color,
        size: size ?? this.size,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'svgPath': svgPath,
        if (color != '#000000') 'color': color,
        if (size != 24) 'size': size,
      };

  /// Full SVG markup for embedding in HTML/PDF.
  String get svgMarkup {
    final c = color;
    final s = size;
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 24 24" width="$s" height="$s" '
        'fill="$c"><path d="$svgPath"/></svg>';
  }

  static IconItem fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const IconItem();
      return IconItem(
        name: map['name']?.toString() ?? '',
        category: map['category']?.toString() ?? '',
        svgPath: map['svgPath']?.toString() ?? '',
        color: map['color']?.toString() ?? '#000000',
        size: (map['size'] as num?)?.toInt() ?? 24,
      );
    } catch (_) {
      return const IconItem();
    }
  }

  String toJson() => jsonEncode(toMap());
}