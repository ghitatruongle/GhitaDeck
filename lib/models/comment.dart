import 'dart:convert';

/// Discussion comment (Track 48, FEAT 81).
///
/// A comment is anchored to a slide and optionally to a text run within the
/// slide's HTML (the [anchor] selector). Comments support threaded replies
/// via [replyTo] and a resolved flag, and are persisted in `.ghita` bundles
/// and synced over the LAN collaboration channel.
class Comment {
  final String id;
  final int slideIndex;
  final String text;
  final String authorName;
  final String authorColor;
  final DateTime createdAt;
  final bool resolved;
  final String? replyTo;
  final String? anchor;

  const Comment({
    required this.id,
    required this.slideIndex,
    required this.text,
    required this.authorName,
    required this.authorColor,
    required this.createdAt,
    this.resolved = false,
    this.replyTo,
    this.anchor,
  });

  Comment copyWith({
    String? text,
    bool? resolved,
    String? replyTo,
  }) {
    return Comment(
      id: id,
      slideIndex: slideIndex,
      text: text ?? this.text,
      authorName: authorName,
      authorColor: authorColor,
      createdAt: createdAt,
      resolved: resolved ?? this.resolved,
      replyTo: replyTo ?? this.replyTo,
      anchor: anchor,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'slideIndex': slideIndex,
        'text': text,
        'authorName': authorName,
        'authorColor': authorColor,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'resolved': resolved,
        if (replyTo != null) 'replyTo': replyTo,
        if (anchor != null) 'anchor': anchor,
      };

  static Comment fromMap(Map<String, dynamic> map) => Comment(
        id: (map['id'] ?? '').toString(),
        slideIndex: (map['slideIndex'] as num?)?.toInt() ?? 0,
        text: (map['text'] ?? '').toString(),
        authorName: (map['authorName'] ?? 'Unknown').toString(),
        authorColor: (map['authorColor'] ?? '#FF9800').toString(),
        createdAt: DateTime.tryParse(
                (map['createdAt'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        resolved: map['resolved'] == true,
        replyTo: map['replyTo']?.toString(),
        anchor: map['anchor']?.toString(),
      );

  String toJson() => jsonEncode(toMap());

  static Comment fromJson(String json) {
    try {
      return fromMap(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return fromMap(const {});
    }
  }
}
