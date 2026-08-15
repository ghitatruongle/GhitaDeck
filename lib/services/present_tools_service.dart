import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Active presentation tool (Track 35, FEAT 55/56/57).
enum PresentTool {
  none,
  pen,
  highlighter,
  laser,
}

/// Result of pressing a shortcut key in the presentation (Track 35, P4/P7).
enum PresentAction {
  none,
  nextSlide,
  prevSlide,
  toggleGrid,
  toggleBlack,
  toggleWhite,
  toggleLaser,
  togglePen,
  toggleHighlighter,
  toggleMagnifier,
  openHelp,
}

/// Session-wide presentation settings (Track 35, P8) — persisted per app
/// session (not to disk) via [PresentToolsService].
class PresentSessionSettings {
  final ColorHex penColor;
  final ColorHex highlighterColor;
  final double penWidth;
  final bool laserOnByDefault;

  const PresentSessionSettings({
    this.penColor = const ColorHex(0xFFED1C24),
    this.highlighterColor = const ColorHex(0xFFFFF200),
    this.penWidth = 3.0,
    this.laserOnByDefault = false,
  });

  PresentSessionSettings copyWith({
    ColorHex? penColor,
    ColorHex? highlighterColor,
    double? penWidth,
    bool? laserOnByDefault,
  }) =>
      PresentSessionSettings(
        penColor: penColor ?? this.penColor,
        highlighterColor: highlighterColor ?? this.highlighterColor,
        penWidth: penWidth ?? this.penWidth,
        laserOnByDefault: laserOnByDefault ?? this.laserOnByDefault,
      );

  Map<String, dynamic> toMap() => {
        'penColor': penColor.value,
        'highlighterColor': highlighterColor.value,
        'penWidth': penWidth,
        'laserOnByDefault': laserOnByDefault,
      };

  static PresentSessionSettings fromMap(Map<String, dynamic> map) =>
      PresentSessionSettings(
        penColor: ColorHex((map['penColor'] as num?)?.toInt() ?? 0xFFED1C24),
        highlighterColor:
            ColorHex((map['highlighterColor'] as num?)?.toInt() ?? 0xFFFFF200),
        penWidth: (map['penWidth'] as num?)?.toDouble() ?? 3.0,
        laserOnByDefault: map['laserOnByDefault'] == true,
      );

  String toJson() => jsonEncode(toMap());

  static PresentSessionSettings fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is Map<String, dynamic>) return fromMap(map);
    } catch (_) {}
    return const PresentSessionSettings();
  }
}

/// ARGB color stored as an int, safe to embed in `#rrggbb` CSS/JS strings.
class ColorHex {
  final int value;
  const ColorHex(this.value);

  /// CSS hex without alpha (`#rrggbb`).
  String get cssHex {
    final rgb = value & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  bool operator ==(Object other) => other is ColorHex && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// A single ink stroke captured while presenting (Track 35, P5).
class PresentStroke {
  final int slideIndex;
  final PresentTool tool;
  final ColorHex color;
  final double width;
  final List<OffsetPct> points;

  const PresentStroke({
    required this.slideIndex,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
  });

  Map<String, dynamic> toMap() => {
        'slideIndex': slideIndex,
        'tool': tool.name,
        'color': color.value,
        'width': width,
        'points': points.map((p) => p.toMap()).toList(),
      };

  static PresentStroke fromMap(Map<String, dynamic> map) => PresentStroke(
        slideIndex: (map['slideIndex'] as num?)?.toInt() ?? 0,
        tool: PresentTool.values.asNameMap()[map['tool']] ?? PresentTool.pen,
        color: ColorHex((map['color'] as num?)?.toInt() ?? 0xFFED1C24),
        width: (map['width'] as num?)?.toDouble() ?? 3.0,
        points: (map['points'] as List? ?? const [])
            .map((e) => OffsetPct.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// A point in slide-relative percent coordinates (0–100), so strokes survive
/// window resizing and export cleanly.
class OffsetPct {
  final double x, y;
  const OffsetPct(this.x, this.y);

  Map<String, dynamic> toMap() => {'x': x, 'y': y};

  static OffsetPct fromMap(Map<String, dynamic> map) => OffsetPct(
        (map['x'] as num?)?.toDouble() ?? 0,
        (map['y'] as num?)?.toDouble() ?? 0,
      );
}

/// Tracks the interactive presentation tools for [PresentScreen] (Track 35).
///
/// Pure state + serialization so every behaviour is unit-testable without a
/// WebView2 runtime. The screen binds pointer/scroll/keyboard events to this
/// service and paints the overlays it describes.
class PresentToolsService extends ChangeNotifier {
  PresentToolsService({PresentSessionSettings? settings})
      : _settings = settings ?? const PresentSessionSettings();

  PresentSessionSettings _settings;
  PresentSessionSettings get settings => _settings;

  PresentTool _tool = PresentTool.none;
  PresentTool get tool => _tool;

  bool _magnifier = false;
  bool get magnifier => _magnifier;

  bool _blackScreen = false;
  bool get blackScreen => _blackScreen;

  bool _whiteScreen = false;
  bool get whiteScreen => _whiteScreen;

  bool _gridOpen = false;
  bool get gridOpen => _gridOpen;

  /// Ink currently being drawn (null when pointer is up).
  PresentStroke? _activeStroke;
  PresentStroke? get activeStroke => _activeStroke;

  final List<PresentStroke> _strokes = [];
  List<PresentStroke> get strokes => List.unmodifiable(_strokes);

  /// Magnifier zoom factor (1.0 = off, up to 3.0).
  double _zoom = 1.0;
  double get zoom => _zoom;

  // ---- Tool toggles -------------------------------------------------------

  void setTool(PresentTool tool) {
    if (_tool == tool && tool != PresentTool.none) {
      // Tapping the active tool again turns it off.
      _tool = PresentTool.none;
    } else {
      _tool = tool;
    }
    if (_tool == PresentTool.laser) _magnifier = false;
    notifyListeners();
  }

  void toggleLaser() => setTool(
      _tool == PresentTool.laser ? PresentTool.none : PresentTool.laser);

  void togglePen() =>
      setTool(_tool == PresentTool.pen ? PresentTool.none : PresentTool.pen);

  void toggleHighlighter() => setTool(_tool == PresentTool.highlighter
      ? PresentTool.none
      : PresentTool.highlighter);

  // ---- Black / white screen ----------------------------------------------

  void toggleBlackScreen() {
    _blackScreen = !_blackScreen;
    _whiteScreen = false;
    notifyListeners();
  }

  void toggleWhiteScreen() {
    _whiteScreen = !_whiteScreen;
    _blackScreen = false;
    notifyListeners();
  }

  void clearScreens() {
    _blackScreen = false;
    _whiteScreen = false;
    notifyListeners();
  }

  // ---- Grid navigator (P4) ------------------------------------------------

  void toggleGrid() {
    _gridOpen = !_gridOpen;
    notifyListeners();
  }

  void closeGrid() {
    if (_gridOpen) {
      _gridOpen = false;
      notifyListeners();
    }
  }

  // ---- Magnifier (P6) ------------------------------------------------------

  void toggleMagnifier() {
    _magnifier = !_magnifier;
    if (_magnifier) {
      _tool = PresentTool.none;
      _zoom = 1.5;
    } else {
      _zoom = 1.0;
    }
    notifyListeners();
  }

  /// Ctrl+wheel zoom: returns the new zoom (clamped 1.0–3.0).
  double adjustZoom(double delta) {
    _zoom = (_zoom + delta).clamp(1.0, 3.0);
    if (_zoom <= 1.0) _magnifier = false;
    notifyListeners();
    return _zoom;
  }

  // ---- Ink strokes (P5) ----------------------------------------------------

  void startStroke(int slideIndex, OffsetPct start) {
    if (_tool != PresentTool.pen && _tool != PresentTool.highlighter) return;
    _activeStroke = PresentStroke(
      slideIndex: slideIndex,
      tool: _tool,
      color: _tool == PresentTool.pen
          ? _settings.penColor
          : _settings.highlighterColor,
      width: _tool == PresentTool.pen ? _settings.penWidth : 14.0,
      points: [start],
    );
    notifyListeners();
  }

  void continueStroke(OffsetPct point) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    _activeStroke = PresentStroke(
      slideIndex: stroke.slideIndex,
      tool: stroke.tool,
      color: stroke.color,
      width: stroke.width,
      points: [...stroke.points, point],
    );
    notifyListeners();
  }

  void endStroke() {
    final stroke = _activeStroke;
    if (stroke != null) _strokes.add(stroke);
    _activeStroke = null;
    notifyListeners();
  }

  void clearStrokes() {
    _strokes.clear();
    _activeStroke = null;
    notifyListeners();
  }

  /// Remove strokes drawn on a slide that was just deleted (slide index >=
  /// [newLength] are dropped, indices above [removedAt] shift down by one).
  void removeSlide(int removedAt) {
    _strokes.removeWhere((s) => s.slideIndex == removedAt);
    for (var i = 0; i < _strokes.length; i++) {
      if (_strokes[i].slideIndex > removedAt) {
        final s = _strokes[i];
        _strokes[i] = PresentStroke(
          slideIndex: s.slideIndex - 1,
          tool: s.tool,
          color: s.color,
          width: s.width,
          points: s.points,
        );
      }
    }
    notifyListeners();
  }

  // ---- Settings (P8) -------------------------------------------------------

  void updateSettings(PresentSessionSettings next) {
    _settings = next;
    notifyListeners();
  }

  // ---- Keyboard mapping (P4/P7) -------------------------------------------

  /// Map a raw key event to a [PresentAction]. Pure function, unit-tested.
  static PresentAction actionForKey(String key, {required bool ctrl}) {
    switch (key) {
      case 'ArrowRight':
      case ' ':
      case 'PageDown':
        return PresentAction.nextSlide;
      case 'ArrowLeft':
      case 'PageUp':
        return PresentAction.prevSlide;
      case 'g':
      case 'G':
        return PresentAction.toggleGrid;
      case 'b':
      case 'B':
        return PresentAction.toggleBlack;
      case 'w':
      case 'W':
        return PresentAction.toggleWhite;
      case 'l':
      case 'L':
        return PresentAction.toggleLaser;
      case 'p':
      case 'P':
        return PresentAction.togglePen;
      case 'h':
      case 'H':
        return PresentAction.toggleHighlighter;
      case 'm':
      case 'M':
        return PresentAction.toggleMagnifier;
      case '?':
      case '/':
        return PresentAction.openHelp;
      default:
        return PresentAction.none;
    }
  }
}
