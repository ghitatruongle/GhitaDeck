/// A single user guide line on the canvas (Track 27, P5).
class GuideLine {
  /// Position in slide % (0–100).
  final double position;

  /// true = horizontal guide (y position), false = vertical (x position).
  final bool horizontal;

  final bool locked;

  const GuideLine({
    required this.position,
    required this.horizontal,
    this.locked = false,
  });

  GuideLine copyWith({double? position, bool? locked}) => GuideLine(
        position: position ?? this.position,
        horizontal: horizontal,
        locked: locked ?? this.locked,
      );

  Map<String, dynamic> toMap() =>
      {'position': position, 'horizontal': horizontal, 'locked': locked};

  static GuideLine fromMap(Map<String, dynamic> map) => GuideLine(
        position: (map['position'] as num?)?.toDouble() ?? 50,
        horizontal: map['horizontal'] == true,
        locked: map['locked'] == true,
      );
}

/// Canvas editing aids persisted into the project file (`.ghita` deck meta):
/// user guides, snap/grid toggles and the ruler visibility (Track 27, P6).
class GuideSettings {
  final List<GuideLine> guides;
  final bool snapToGrid;
  final bool snapToShape;
  final bool showGrid;
  final double gridSize;
  final bool showRuler;
  final bool showGuides;

  const GuideSettings({
    this.guides = const [],
    this.snapToGrid = true,
    this.snapToShape = true,
    this.showGrid = false,
    this.gridSize = 5,
    this.showRuler = true,
    this.showGuides = true,
  });

  GuideSettings copyWith({
    List<GuideLine>? guides,
    bool? snapToGrid,
    bool? snapToShape,
    bool? showGrid,
    double? gridSize,
    bool? showRuler,
    bool? showGuides,
  }) =>
      GuideSettings(
        guides: guides ?? this.guides,
        snapToGrid: snapToGrid ?? this.snapToGrid,
        snapToShape: snapToShape ?? this.snapToShape,
        showGrid: showGrid ?? this.showGrid,
        gridSize: gridSize ?? this.gridSize,
        showRuler: showRuler ?? this.showRuler,
        showGuides: showGuides ?? this.showGuides,
      );

  Map<String, dynamic> toMap() => {
        'guides': [for (final g in guides) g.toMap()],
        'snapToGrid': snapToGrid,
        'snapToShape': snapToShape,
        'showGrid': showGrid,
        'gridSize': gridSize,
        'showRuler': showRuler,
        'showGuides': showGuides,
      };

  static GuideSettings fromMap(Map<String, dynamic> map) => GuideSettings(
        guides: map['guides'] is List
            ? [
                for (final e in map['guides'] as List)
                  GuideLine.fromMap(e is Map
                      ? Map<String, dynamic>.from(e)
                      : <String, dynamic>{}),
              ]
            : const [],
        snapToGrid: map['snapToGrid'] != false,
        snapToShape: map['snapToShape'] != false,
        showGrid: map['showGrid'] == true,
        gridSize: (map['gridSize'] as num?)?.toDouble() ?? 5,
        showRuler: map['showRuler'] != false,
        showGuides: map['showGuides'] != false,
      );
}
