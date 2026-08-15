import 'dart:math';

import '../models/comment.dart';

/// Comment management (Track 48, FEAT 81).
///
/// Comments live in the slide map under the `comments` key (list of comment
/// maps) so they flow through the existing collaboration delta sync, `.ghita`
/// bundle persistence and PPTX/HTML export pipelines without a second
/// transport. [mentionsIn] extracts @-mentions from comment text so the UI
/// can highlight them and the session can notify collaborators.
class CommentService {
  CommentService._();

  static const String slideCommentsKey = 'comments';

  /// All comments for [slides] (across slides), newest first.
  static List<Comment> allComments(List<Map<String, dynamic>> slides) {
    final result = <Comment>[];
    for (final slide in slides) {
      result.addAll(commentsFor(slide));
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static List<Comment> commentsFor(Map<String, dynamic> slide) {
    final raw = slide[slideCommentsKey];
    if (raw is! List) return const [];
    final result = <Comment>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        result.add(Comment.fromMap(item));
      } else if (item is Map) {
        result.add(Comment.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  static int countFor(Map<String, dynamic> slide) =>
      commentsFor(slide).length;

  /// Add a comment (or a reply when [replyTo] is set) to [slide].
  static Comment addComment(
    Map<String, dynamic> slide, {
    required String text,
    required String authorName,
    required String authorColor,
    String? replyTo,
    String? anchor,
  }) {
    final comment = Comment(
      id: _newId(),
      slideIndex: (slide['index'] as num?)?.toInt() ?? 0,
      text: text,
      authorName: authorName,
      authorColor: authorColor,
      createdAt: DateTime.now(),
      replyTo: replyTo,
      anchor: anchor,
    );
    final list = commentsFor(slide).map((c) => c.toMap()).toList();
    list.add(comment.toMap());
    slide[slideCommentsKey] = list;
    return comment;
  }

  static Comment? updateComment(
    Map<String, dynamic> slide,
    String commentId, {
    String? text,
    bool? resolved,
  }) {
    final list = commentsFor(slide).map((c) => c.toMap()).toList();
    final index = list.indexWhere((c) => c['id'] == commentId);
    if (index < 0) return null;
    final updated = Comment.fromMap(list[index]).copyWith(
      text: text,
      resolved: resolved,
    );
    list[index] = updated.toMap();
    slide[slideCommentsKey] = list;
    return updated;
  }

  static bool removeComment(
      Map<String, dynamic> slide, String commentId) {
    final list = commentsFor(slide).map((c) => c.toMap()).toList();
    final before = list.length;
    list.removeWhere((c) => c['id'] == commentId);
    if (list.length == before) return false;
    slide[slideCommentsKey] = list;
    return true;
  }

  /// Resolve (or un-resolve) a comment thread.
  static bool setResolved(
      Map<String, dynamic> slide, String commentId, bool resolved) {
    return updateComment(slide, commentId, resolved: resolved) != null;
  }

  /// @-mentions found in [text] — unique names, trimmed of the leading '@'.
  static List<String> mentionsIn(String text) {
    final result = <String>[];
    for (final match in RegExp(r'@([A-Za-z0-9_\p{L}]{2,24})', unicode: true)
        .allMatches(text)) {
      final name = match.group(1)!;
      if (!result.contains(name)) result.add(name);
    }
    return result;
  }

  /// Strip @-mentions that don't belong to any [knownNames] (dangling refs).
  static List<Comment> filterMentionsToKnown(
      List<Comment> comments, Set<String> knownNames) {
    return comments.where((c) {
      final mentions = mentionsIn(c.text);
      if (mentions.isEmpty) return true;
      return mentions.any(knownNames.contains);
    }).toList();
  }

  /// OOXML `<p:cm>` comment list for a slide (PowerPoint comments pane).
  /// One `<p:cm>` per comment with author, datetime, text and a thread id.
  /// PowerPoint needs `<p:cmAuthorLst>` in presentation.xml too — the caller
  /// adds that via [authorListXml].
  static String commentListXml(
      List<Comment> comments, String authorColorHex) {
    if (comments.isEmpty) return '';
    final b = StringBuffer()
      ..write('<p:cmLst xmlns:p="http://schemas.openxmlformats.org/'
          'presentationml/2006/main">');
    var n = 0;
    for (final c in comments) {
      n++;
      final parent = c.replyTo != null
          ? '<p:parentCm><p:cmId>${_idNum(c.replyTo!)}</p:cmId></p:parentCm>'
          : '';
      final anchor = c.anchor != null && c.anchor!.isNotEmpty
          ? '<p:pos x="0" y="0"/>'
          : '';
      b.write(
          '<p:cm authorId="0" dt="${_ooxmlDate(c.createdAt)}" idx="$n">'
          '<p:text>${_xml(c.text)}</p:text>$parent$anchor'
          '<p:extLst><p:ext uri="{BB962C8B-B14F-4D97-AF65-F5344CB8AC3E}">'
          '<p14:threadingInfo xmlns:p14="http://schemas.microsoft.com/office/'
          'powerpoint/2010/main" xmlns:a16="http://schemas.microsoft.com/'
          'office/drawing/2014/main" '
          'a16:rowId="0" a16:originalAuthorId="0"/>'
          '</p:ext></p:extLst>'
          '</p:cm>');
    }
    b.write('</p:cmLst>');
    return b.toString();
  }

  /// `<p:cmAuthorLst>` for the presentation.xml comments authors part.
  static String authorListXml(String authorName, String colorHex) =>
      '<p:cmAuthorLst xmlns:p="http://schemas.openxmlformats.org/'
      'presentationml/2006/main"><p:cmAuthor id="0" '
      'name="${_xml(authorName)}" initials="GH" '
      'lastIdx="1" clrIndex="${_colorIndex(colorHex)}" '
      'color="${_xml(colorHex)}"/></p:cmAuthorLst>';

  static int _colorIndex(String hex) {
    final clean = hex.replaceAll('#', '');
    final v = int.tryParse(
            clean.length >= 6 ? clean.substring(0, 6) : 'FF9800',
            radix: 16) ??
        0xFF9800;
    return (v % 17).clamp(0, 16);
  }

  static int _idNum(String id) {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0) % 100000;
  }

  static String _ooxmlDate(DateTime dt) {
    // PowerPoint uses the ISO-8601 style with a timezone offset.
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    return '${local.year}-${two(local.month)}-${two(local.day)}T'
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
        '$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)}';
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static final Random _random = Random.secure();

  static String _newId() {
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'c_$hex';
  }
}
