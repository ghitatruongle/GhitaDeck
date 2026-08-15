import '../models/drawn_shape.dart';

/// A captured style snapshot that can be re-applied to another element
/// (Track 24, P3–P6). Stored as plain data so all three exporters
/// (HTML / PPTX / PDF) can consume it — not just the UI.
class FormatSnapshot {
  /// CSS-ish property map (lowercase keys, e.g. 'font-size', 'color',
  /// 'background-color', 'font-family', 'font-weight', 'text-align'...).
  final Map<String, String> css;

  /// Bold / italic / underline toggles captured from <b>/<i>/<u> wrappers.
  final bool bold;
  final bool italic;
  final bool underline;

  /// Shape style (when captured from a DrawnShape).
  final String? fillColor;
  final double? fillTransparency;
  final String? strokeColor;
  final double? strokeWidth;
  final String? gradientStart;
  final String? gradientEnd;
  final double? gradientAngle;

  const FormatSnapshot({
    this.css = const {},
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fillColor,
    this.fillTransparency,
    this.strokeColor,
    this.strokeWidth,
    this.gradientStart,
    this.gradientEnd,
    this.gradientAngle,
  });

  bool get isEmpty =>
      css.isEmpty && !bold && !italic && !underline && fillColor == null;

  /// Capture a text format snapshot from an HTML fragment: reads the first
  /// element's inline `style` attribute and <b>/<i>/<u> markers.
  factory FormatSnapshot.fromHtmlFragment(String html) {
    final css = <String, String>{};
    var bold = false, italic = false, underline = false;

    // Inline style of the first element that carries one.
    final styleMatch = RegExp(r'style="([^"]*)"').firstMatch(html);
    if (styleMatch != null) {
      for (final decl in styleMatch.group(1)!.split(';')) {
        final parts = decl.split(':');
        if (parts.length != 2) continue;
        final key = parts[0].trim().toLowerCase();
        final value = parts[1].trim();
        if (key.isNotEmpty && value.isNotEmpty) css[key] = value;
      }
    }
    bold = html.contains('<b>') || css['font-weight'] == 'bold';
    italic = html.contains('<i>') || css['font-style'] == 'italic';
    underline = html.contains('<u>') || css['text-decoration'] == 'underline';

    return FormatSnapshot(css: css, bold: bold, italic: italic, underline: underline);
  }

  /// Capture a shape format snapshot from a DrawnShape.
  factory FormatSnapshot.fromShape(DrawnShape shape) {
    return FormatSnapshot(
      fillColor: shape.fillColor,
      fillTransparency: shape.fillTransparency,
      strokeColor: shape.strokeColor,
      strokeWidth: shape.strokeWidth,
      gradientStart: shape.gradientStart.isEmpty ? null : shape.gradientStart,
      gradientEnd: shape.gradientEnd.isEmpty ? null : shape.gradientEnd,
      gradientAngle: shape.gradientStart.isEmpty ? null : shape.gradientAngle,
    );
  }

  /// Build the inline style string from the captured CSS (stable key order).
  String get styleString {
    final parts = <String>[];
    for (final key in css.keys) {
      parts.add('$key: ${css[key]}');
    }
    return parts.join('; ');
  }

  /// Apply the snapshot to a plain text selection by wrapping it in a
  /// `<span style="...">` (with <b>/<i>/<u> when captured).
  String applyToSelection(String text) {
    var inner = text;
    if (bold) inner = '<b>$inner</b>';
    if (italic) inner = '<i>$inner</i>';
    if (underline) inner = '<u>$inner</u>';
    if (css.isNotEmpty) inner = '<span style="$styleString">$inner</span>';
    return inner;
  }

  /// Apply the snapshot to a DrawnShape (copy-on-write semantics).
  DrawnShape applyToShape(DrawnShape shape) {
    return shape.copyWith(
      fillColor: fillColor,
      fillTransparency: fillTransparency,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
      gradientAngle: gradientAngle,
    );
  }
}

/// Format Painter Service (Track 24).
///
/// Capture-once / paste-many semantics: one-shot by default, persistent when
/// the painter stays armed (double-click behaviour is handled by the UI).
class FormatPainterService {
  FormatSnapshot? _snapshot;
  bool _armed = false;

  FormatSnapshot? get snapshot => _snapshot;
  bool get isArmed => _armed && _snapshot != null;

  /// Arm the painter with a captured snapshot (Ctrl+Shift+C).
  void capture(FormatSnapshot snapshot, {bool persistent = false}) {
    _snapshot = snapshot;
    _armed = true;
  }

  /// Paste the captured format; disarms after use unless [persistent].
  FormatSnapshot? use({bool persistent = false}) {
    if (!_armed) return null;
    final snap = _snapshot;
    if (!persistent) _armed = false;
    return snap;
  }

  void clear() {
    _snapshot = null;
    _armed = false;
  }
}
