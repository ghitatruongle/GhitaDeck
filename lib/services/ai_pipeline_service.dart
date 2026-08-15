import 'dart:convert';

/// A single slide checkpoint produced by the resilient pipeline (Track 53,
/// OPT 39). Keeps whatever completed before a failure so generation can
/// resume instead of restarting from scratch.
class CheckpointSlide {
  final String title;
  final String html;
  final int index;

  const CheckpointSlide({
    required this.title,
    required this.html,
    required this.index,
  });

  Map<String, dynamic> toMap() => {'title': title, 'html': html, 'index': index};
}

/// Result of attempting to extract slide JSON from a partially-received
/// stream chunk.
class PartialParseResult {
  final List<Map<String, dynamic>> slides;
  final String? error;
  final bool complete;

  const PartialParseResult({
    required this.slides,
    this.error,
    this.complete = false,
  });
}

/// Resilient & cost-aware AI pipeline (Track 53).
///
/// * [repairJsonArray] balances brackets/quotes in a truncated JSON array so
///   completed slides survive a mid-stream failure.
/// * [parseIncremental] extracts as many complete slide objects as possible
///   from a growing stream buffer (OPT 40 — render slide 1 before the whole
///   response arrives).
/// * [estimateTokens] gives a rough per-session cost figure for the chat UI.
/// * [trimHistoryByTokens] bounds chat history by an approximate token count.
class AIPipelineService {
  AIPipelineService._();

  /// Repairs a truncated JSON array string (missing closing brackets/quotes)
  /// so [jsonDecode] can at least read the completed objects.
  static String repairJsonArray(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '[]';

    // Strip a leading code fence if the model wrapped the output.
    s = s.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'\s*```$'), '').trim();

    // Locate the first '[' — everything before it is model chatter.
    final start = s.indexOf('[');
    if (start == -1) return '[]';
    if (start > 0) s = s.substring(start);

    // Walk brackets outside strings, keeping the open-bracket stack so each
    // unclosed bracket can be closed with its MATCHING closer (a `{` must be
    // closed with `}`, not `]`).
    final stack = <String>[];
    var inString = false;
    var escaped = false;
    var lastDepthZero = -1; // last index where the array fully closed
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '[' || ch == '{') {
        stack.add(ch);
      } else if (ch == ']' || ch == '}') {
        if (stack.isNotEmpty) stack.removeLast();
        if (stack.isEmpty) lastDepthZero = i;
      }
    }
    // If the array was closed somewhere mid-stream, truncate at that point so
    // we only parse complete objects.
    if (lastDepthZero >= 0 && lastDepthZero < s.length - 1) {
      s = s.substring(0, lastDepthZero + 1);
      // Recompute the open stack against the truncated text.
      stack.clear();
      inString = false;
      escaped = false;
      for (var i = 0; i < s.length; i++) {
        final ch = s[i];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (ch == r'\') {
            escaped = true;
          } else if (ch == '"') {
            inString = false;
          }
          continue;
        }
        if (ch == '"') {
          inString = true;
        } else if (ch == '[' || ch == '{') {
          stack.add(ch);
        } else if (ch == ']' || ch == '}') {
          if (stack.isNotEmpty) stack.removeLast();
        }
      }
    }
    // A trailing comma (`[... ,]`) is invalid JSON — drop it before closing.
    s = s.replaceFirst(RegExp(r',\s*$'), '');
    // Close every still-open bracket with its matching closer, innermost
    // first.
    if (stack.isNotEmpty) {
      final buf = StringBuffer(s);
      for (final open in stack.reversed) {
        buf.write(open == '{' ? '}' : ']');
      }
      s = buf.toString();
    }
    return s;
  }

  /// Parse as many complete slides as possible from [buffer]. Returns the
  /// completed slides plus whether the array appears finished.
  static PartialParseResult parseIncremental(String buffer) {
    final repaired = repairJsonArray(buffer);
    try {
      final decoded = jsonDecode(repaired);
      if (decoded is! List) {
        return const PartialParseResult(slides: [], error: 'not-an-array');
      }
      final slides = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // Complete only when the ORIGINAL buffer was already a closed array —
      // a repaired (bracket-appended) stream is by definition still running.
      final complete = !_looksTruncated(buffer);
      return PartialParseResult(slides: slides, complete: complete);
    } catch (e) {
      return PartialParseResult(slides: const [], error: '$e');
    }
  }

  /// Best-effort guess of token count: ~4 chars per token, Vietnamese/ASCII
  /// weighted lightly higher for CJK-like density.
  static int estimateTokens(String text) {
    var cjk = 0;
    for (final unit in text.codeUnits) {
      if (unit >= 0x2E80) cjk++;
    }
    final base = (text.length - cjk) ~/ 4;
    final cjkTokens = cjk ~/ 1.5;
    return base + cjkTokens;
  }

  /// Trim a chat history list (maps with 'role'/'content') to stay under
  /// [maxTokens], keeping the most recent messages and dropping the oldest.
  /// Order is preserved (oldest first) — only the tail survives.
  static ({List<Map<String, dynamic>> history, int dropped})
      trimHistoryByTokens(List<Map<String, dynamic>> history,
          {int maxTokens = 6000}) {
    var total = 0;
    var start = 0;
    for (var i = history.length - 1; i >= 0; i--) {
      final content = (history[i]['content'] ?? '').toString();
      final tokens = estimateTokens(content) + 4; // role + overhead
      if (total + tokens > maxTokens) {
        break;
      }
      total += tokens;
      start = i;
    }
    return (
      history: history.sublist(start),
      dropped: start,
    );
  }

  static bool _looksTruncated(String s) {
    final trimmed = s.trimRight();
    return !trimmed.endsWith(']') || trimmed.endsWith(',');
  }


}
