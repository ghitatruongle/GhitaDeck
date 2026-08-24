/// Service to generate Mermaid.js diagram definitions and HTML graphic representations.
class MermaidDiagramService {
  /// Escape user text before embedding into generated HTML (steps/topics can
  /// contain quotes, `<`, `&` which previously broke the markup).
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Generates a Mermaid flowchart HTML block.
  ///
  /// [accentColor] tints the step chips so diagrams follow the deck theme
  /// (defaults to the original blue when omitted).
  String generateFlowchartHtml(List<String> steps, {String? accentColor}) {
    if (steps.isEmpty) return '';
    final fill = _safeColor(accentColor) ?? '#3B82F6';
    final buffer = StringBuffer();
    buffer.writeln('<div class="diagram-flowchart" style="padding: 16px; background: rgba(0,0,0,0.03); border-radius: 12px; margin-top: 16px;">');
    buffer.writeln('<h3>Sơ Đồ Quy Trình (Flowchart)</h3>');
    buffer.writeln('<div style="display: flex; gap: 12px; align-items: center; overflow-x: auto;">');

    for (var i = 0; i < steps.length; i++) {
      buffer.writeln(
        '<div style="padding: 12px 18px; background: $fill; color: white; border-radius: 8px; font-weight: bold;">'
        '${i + 1}. ${_esc(steps[i])}'
        '</div>',
      );
      if (i < steps.length - 1) {
        buffer.writeln('<div style="font-size: 20px; color: #6B7280;">➔</div>');
      }
    }

    buffer.writeln('</div></div>');
    return buffer.toString();
  }

  /// Generates a Mermaid mindmap HTML block.
  ///
  /// [accentColor] tints the subtopic cards (defaults to the original green).
  String generateMindmapHtml(String centralTopic, List<String> subtopics,
      {String? accentColor}) {
    final fill = _safeColor(accentColor) ?? '#10B981';
    final buffer = StringBuffer();
    buffer.writeln('<div class="diagram-mindmap" style="padding: 16px; background: rgba(0,0,0,0.03); border-radius: 12px; margin-top: 16px;">');
    buffer.writeln('<h3>Sơ Đồ Tư Duy (Mindmap): ${_esc(centralTopic)}</h3>');
    buffer.writeln('<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px;">');

    for (final topic in subtopics) {
      buffer.writeln(
        '<div style="padding: 14px; background: $fill; color: white; border-radius: 8px; text-align: center; font-weight: 500;">'
        '📌 ${_esc(topic)}'
        '</div>',
      );
    }

    buffer.writeln('</div></div>');
    return buffer.toString();
  }

  /// Only well-formed #RRGGBB values are accepted as accents; anything else
  /// falls back to the built-in colour instead of injecting raw markup.
  static String? _safeColor(String? hex) {
    if (hex == null) return null;
    final value = hex.trim();
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value) ? value : null;
  }
}
