import 'dart:convert';

/// A named, ordered subset of slides for presentation (Track 36, FEAT 60).
///
/// Slides are referenced by their 0-based index in the deck at the time the
/// show is created; indices that fall out of range at present-time are
/// skipped (defensive — a deck may shrink after the show was saved).
class CustomShow {
  final String id;
  final String name;

  /// 0-based slide indices in presentation order.
  final List<int> slideIndices;

  const CustomShow({
    this.id = '',
    this.name = '',
    this.slideIndices = const [],
  });

  CustomShow copyWith({String? id, String? name, List<int>? slideIndices}) =>
      CustomShow(
        id: id ?? this.id,
        name: name ?? this.name,
        slideIndices: slideIndices ?? this.slideIndices,
      );

  /// Indices clamped to a live deck of [slideCount] slides, in order.
  List<int> validIndices(int slideCount) => slideIndices
      .where((i) => i >= 0 && i < slideCount)
      .toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'slideIndices': slideIndices,
      };

  static CustomShow fromMap(Map<String, dynamic> map) => CustomShow(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        slideIndices: (map['slideIndices'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  String toJson() => jsonEncode(toMap());

  static CustomShow fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is Map<String, dynamic>) return fromMap(map);
    } catch (_) {}
    return const CustomShow();
  }

  @override
  bool operator ==(Object other) =>
      other is CustomShow && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Manager for the deck's custom shows (Track 36, P6).
class CustomShowService {
  CustomShowService._();

  static List<CustomShow> fromJsonList(String json) {
    try {
      final list = jsonDecode(json);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(CustomShow.fromMap)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static String toJsonList(List<CustomShow> shows) =>
      jsonEncode(shows.map((s) => s.toMap()).toList());

  /// Build a default show from a deck of [slideCount] slides (all of them).
  static CustomShow defaultShow(int slideCount, {String name = 'All slides'}) =>
      CustomShow(
        name: name,
        slideIndices: List.generate(slideCount, (i) => i),
      );

  /// Insert [index] if not present, else remove it (toggle), returning the
  /// new list in ascending order.
  static List<int> toggleIndex(List<int> indices, int index) {
    final next = [...indices];
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    next.sort();
    return next;
  }
}
