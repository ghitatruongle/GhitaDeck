import 'dart:convert';

/// VBA handling + macro-equivalent script (Track 61, FEAT 98 P4–P6).
///
/// The app does NOT execute VBA. It:
/// * detects `.pptm`/macro files and marks them so the exporter keeps them
///   as-is and the UI warns when opening macro content (P4);
/// * records user actions into a JSON "macro script" and replays it (P5/P6) —
///   the JSONScript is the app's portable equivalent of a VBA macro.
class VbaService {
  VbaService._();

  /// Whether a file name/path is a macro-enabled PowerPoint file.
  static bool isMacroFile(String pathOrName) =>
      pathOrName.toLowerCase().endsWith('.pptm');

  /// Whether the document has an embedded vbaProject (stored in the .ghita
  /// bundle map). Returns true when present.
  static bool hasVbaProject(Map<String, dynamic> document) =>
      document['vbaProject'] != null || document['hasMacros'] == true;

  /// Warning text for opening a macro file (P4).
  static String macroWarning(String fileName) =>
      '"$fileName" contains macros. Macros are not executed by this app. '
      'Enable only if you trust the source.';

  // -------------------------------------------------------------------------
  // JSON macro script (P5/P6)
  // -------------------------------------------------------------------------

  /// Record an action into a JSON script. [script] is a map with a 'steps'
  /// list. [action] one of: 'add_slide', 'update_slide', 'remove_slide',
  /// 'set_bg', 'export'.
  static Map<String, dynamic> record(
    Map<String, dynamic> script,
    String action,
    Map<String, dynamic> params,
  ) {
    return {
      ...script,
      'steps': [
        ...(script['steps'] as List? ?? []),
        {
          'action': action,
          'params': params,
          'at': DateTime.now().toIso8601String(),
        }
      ],
    };
  }

  static String encode(List<Map<String, dynamic>> steps) =>
      jsonEncode({'version': 1, 'steps': steps});

  static List<Map<String, dynamic>> decode(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return (map['steps'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Replay a macro script against [slides]. Supports:
  /// * add_slide {slide}
  /// * update_slide {index, slide}
  /// * remove_slide {index}
  /// * set_bg {index?, color} — index null = all slides.
  /// Returns the new slide list.
  static List<Map<String, dynamic>> replay(
    List<Map<String, dynamic>> slides,
    List<Map<String, dynamic>> steps,
  ) {
    var out = List<Map<String, dynamic>>.from(slides);
    for (final step in steps) {
      final action = (step['action'] ?? '').toString();
      final params = (step['params'] as Map?) ?? const {};
      switch (action) {
        case 'add_slide':
          final slide = params['slide'];
          if (slide is Map) {
            out.add(Map<String, dynamic>.from(slide));
          }
        case 'update_slide':
          final index = params['index'];
          final slide = params['slide'];
          if (index is int && slide is Map && index >= 0 && index < out.length) {
            out[index] = {
              ...out[index],
              ...Map<String, dynamic>.from(slide),
            };
          }
        case 'remove_slide':
          final index = params['index'];
          if (index is int && index >= 0 && index < out.length) {
            out.removeAt(index);
          }
        case 'set_bg':
          final color = (params['color'] ?? '').toString();
          if (color.isEmpty) break;
          final index = params['index'];
          if (index is int && index >= 0 && index < out.length) {
            out[index] = {...out[index], 'bgColor': color};
          } else if (index == null) {
            out = [
              for (final s in out) {...s, 'bgColor': color}
            ];
          }
      }
    }
    return out;
  }
}
