/// Section model (Track 20, P6): groups slides for Section Zoom navigation.
///
/// A section has a name and a start slide index. Sections are stored in the
/// presentation state (not per-slide) and exported to PPTX as `<p:sectionLst>`
/// metadata and to HTML as a section menu.
library;

import 'dart:convert';

class DeckSection {
  const DeckSection({
    this.name = '',
    this.startSlide = 0,
  });

  /// Section display name.
  final String name;

  /// 0-based index of the first slide in this section.
  final int startSlide;

  Map<String, dynamic> toMap() => {
        if (name.isNotEmpty) 'name': name,
        'startSlide': startSlide,
      };

  static DeckSection fromMap(Map<String, dynamic> map) => DeckSection(
        name: map['name']?.toString() ?? '',
        startSlide: (map['startSlide'] as num?)?.toInt() ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  static DeckSection fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const DeckSection();
      return fromMap(map);
    } catch (_) {
      return const DeckSection();
    }
  }
}

class SectionService {
  SectionService._();

  /// Serialize a list of sections to a JSON string (stored in deck meta).
  static String sectionsToJson(List<DeckSection> sections) =>
      jsonEncode(sections.map((s) => s.toMap()).toList());

  static List<DeckSection> sectionsFromJson(String json) {
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      return list
          .map((e) => e is Map<String, dynamic>
              ? DeckSection.fromMap(e)
              : (e is Map ? DeckSection.fromMap(Map<String, dynamic>.from(e)) : null))
          .whereType<DeckSection>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}