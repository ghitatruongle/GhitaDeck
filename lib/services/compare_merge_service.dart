import 'dart:convert';

/// Slide-level diff result for one slide position (Track 51, FEAT 86).
class SlideDiff {
  final int index;
  final String kind; // 'added' | 'removed' | 'changed' | 'same'
  final String? titleA;
  final String? titleB;
  final int addedCount;
  final int removedCount;
  final bool textChanged;

  const SlideDiff({
    required this.index,
    required this.kind,
    this.titleA,
    this.titleB,
    this.addedCount = 0,
    this.removedCount = 0,
    this.textChanged = false,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'kind': kind,
        'titleA': titleA,
        'titleB': titleB,
        'addedCount': addedCount,
        'removedCount': removedCount,
        'textChanged': textChanged,
      };
}

/// Compare & Merge service (Track 51, P4–P6).
///
/// * [compare] opens two `.ghita` bundles and diffs each slide position:
///   added / removed / changed / same, with a text-level add/remove count.
/// * [merge] combines two bundles slide-by-slide according to a per-position
///   choice ('A' | 'B' | 'both') and reports which positions matched.
class CompareMergeService {
  CompareMergeService._();

  /// A single parsed slide (title + normalized text) for diffing.
  static List<Map<String, dynamic>> parseBundleSlides(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map || decoded['slides'] is! List) return const [];
      final result = <Map<String, dynamic>>[];
      for (final item in decoded['slides'] as List) {
        if (item is Map) {
          final slide = Map<String, dynamic>.from(item);
          final html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
          final title = (slide['title'] ?? '').toString();
          result.add({
            'title': title,
            'text': _textOf(html),
            'htmlContent': html,
          });
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// Diff two slide lists by position. Positions are aligned 1:1 by index;
  /// a missing side at an index reports added/removed.
  static List<SlideDiff> compare(List<Map<String, dynamic>> a,
      List<Map<String, dynamic>> b) {
    final diffs = <SlideDiff>[];
    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      final inA = i < a.length;
      final inB = i < b.length;
      if (!inA) {
        diffs.add(SlideDiff(
          index: i,
          kind: 'added',
          titleB: b[i]['title'].toString(),
          addedCount: _wordCount(b[i]['text'].toString()),
        ));
        continue;
      }
      if (!inB) {
        diffs.add(SlideDiff(
          index: i,
          kind: 'removed',
          titleA: a[i]['title'].toString(),
          removedCount: _wordCount(a[i]['text'].toString()),
        ));
        continue;
      }
      final textA = _slideText(a[i]);
      final textB = _slideText(b[i]);
      final titleA = _slideTitle(a[i]);
      final titleB = _slideTitle(b[i]);
      if (textA == textB && titleA == titleB) {
        diffs.add(SlideDiff(
            index: i, kind: 'same', titleA: titleA, titleB: titleB));
      } else {
        final stats = _textStats(textA, textB);
        diffs.add(SlideDiff(
          index: i,
          kind: 'changed',
          titleA: titleA,
          titleB: titleB,
          addedCount: stats.$1,
          removedCount: stats.$2,
          textChanged: textA != textB,
        ));
      }
    }
    return diffs;
  }

  /// Merge two bundles with a per-position choice.
  ///
  /// [choices] maps slide index → 'A' (take version A), 'B' (take B), or
  /// 'both' (insert A's slide then B's). Indexes beyond the shorter list
  /// keep the side that exists. Returns merged slide maps plus a summary.
  static ({List<Map<String, dynamic>> slides, int fromA, int fromB, int both})
      merge(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b,
          Map<int, String> choices) {
    final merged = <Map<String, dynamic>>[];
    var fromA = 0, fromB = 0, both = 0;
    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      final choice = choices[i];
      final hasA = i < a.length;
      final hasB = i < b.length;
      if (choice == 'both' && hasA && hasB) {
        merged.add(a[i]);
        merged.add(b[i]);
        both++;
      } else if (choice == 'B' && hasB) {
        merged.add(b[i]);
        fromB++;
      } else if (hasA) {
        merged.add(a[i]);
        fromA++;
      } else if (hasB) {
        merged.add(b[i]);
        fromB++;
      }
    }
    return (
      slides: merged,
      fromA: fromA,
      fromB: fromB,
      both: both,
    );
  }

  /// Human-readable report of a compare: one line per slide.
  static String report(List<SlideDiff> diffs) {
    final buf = StringBuffer();
    for (final d in diffs) {
      switch (d.kind) {
        case 'added':
          buf.writeln('+ #${d.index + 1} added: ${d.titleB} '
              '(${d.addedCount} words)');
        case 'removed':
          buf.writeln('- #${d.index + 1} removed: ${d.titleA} '
              '(${d.removedCount} words)');
        case 'changed':
          buf.writeln('~ #${d.index + 1} changed: "${d.titleA}" → '
              '"${d.titleB}" (+${d.addedCount}/-${d.removedCount})');
        default:
          buf.writeln('= #${d.index + 1} same: ${d.titleA}');
      }
    }
    return buf.toString().trimRight();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _slideText(Map<String, dynamic> slide) {
    final text = slide['text']?.toString();
    if (text != null && text.isNotEmpty) return text;
    final html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
    return _textOf(html);
  }

  static String _slideTitle(Map<String, dynamic> slide) =>
      (slide['title'] ?? '').toString();

  static String _textOf(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static int _wordCount(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length;
  }

  /// Multi-set text diff: count of tokens added and removed.
  static (int, int) _textStats(String a, String b) {
    final aWords = a.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final bWords = b.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final aCount = <String, int>{};
    final bCount = <String, int>{};
    for (final w in aWords) {
      aCount[w] = (aCount[w] ?? 0) + 1;
    }
    for (final w in bWords) {
      bCount[w] = (bCount[w] ?? 0) + 1;
    }
    var added = 0;
    var removed = 0;
    for (final entry in bCount.entries) {
      final have = aCount[entry.key] ?? 0;
      if (entry.value > have) added += entry.value - have;
    }
    for (final entry in aCount.entries) {
      final have = bCount[entry.key] ?? 0;
      if (entry.value > have) removed += entry.value - have;
    }
    return (added, removed);
  }
}
