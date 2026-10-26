import 'package:flutter/material.dart';
import 'package:ghita_deck/providers/presentation_state.dart';

/// A pre-made HTML template for presentation slides.
class SlideTemplate {
  final String id;
  final String name;
  final String description;
  final String htmlContent;
  final SlideEffect recommendedEffect;
  final IconData icon;
  final Color accentColor;
  final String category;

  /// Known template icons keyed by code point (tree-shake friendly:
  /// dynamic IconData construction breaks icon font tree shaking).
  static const Map<int, IconData> knownIcons = {
    983162: Icons.business_center,
    983166: Icons.palette,
    983195: Icons.school,
    983187: Icons.campaign,
    983173: Icons.crop_square,
    988132: Icons.dashboard,
    983015: Icons.code,
    983373: Icons.menu_book,
    988292: Icons.science,
    983391: Icons.assessment,
    983642: Icons.people,
    983457: Icons.photo_library,
    983782: Icons.celebration,
    983571: Icons.bar_chart,
    983473: Icons.compare_arrows,
    983489: Icons.account_tree,
    983344: Icons.title,
    982960: Icons.thumb_up,
    983561: Icons.format_list_numbered,
    983483: Icons.timeline,
  };

  static IconData iconForCodePoint(int? codePoint) =>
      knownIcons[codePoint] ?? Icons.description;

  SlideTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.htmlContent,
    required this.recommendedEffect,
    required this.icon,
    required this.accentColor,
    this.category = 'General',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'htmlContent': htmlContent,
      'recommendedEffect': recommendedEffect.name,
      'icon': icon.codePoint,
      'accentColor': accentColor.toARGB32(),
      'category': category,
    };
  }

  factory SlideTemplate.fromMap(Map<String, dynamic> map) {
    return SlideTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      htmlContent: map['htmlContent'] as String,
      recommendedEffect: SlideEffect.values.firstWhere(
        (e) => e.name == map['recommendedEffect'],
        orElse: () => SlideEffect.none,
      ),
      icon: iconForCodePoint(map['icon'] as int?),
      // Tolerate persisted templates whose accentColor is missing or stored as a
      // hex string (theme exports do) instead of throwing and aborting the
      // whole template/bundle load.
      accentColor: Color(
        map['accentColor'] is int
            ? map['accentColor'] as int
            : 0xFF2196F3, // default Office Blue
      ),
      category: (map['category'] as String?) ?? 'General',
    );
  }
}
