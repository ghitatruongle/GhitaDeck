/// Per-object animation attached to a slide element (Track 29, FEAT 43).
///
/// Stored under `Slide.visualElements['animations']` as a list of maps so it
/// survives project persistence, undo/redo and PPTX/HTML export.
library;

/// The four PowerPoint animation groups.
enum AnimationGroup { entrance, emphasis, exit, motion }

/// How an animation starts.
enum AnimationStart { onClick, withPrevious, afterPrevious }

/// A named effect inside a group. The engine maps each to CSS keyframes and
/// OOXML behaviours.
enum AnimationEffect {
  // Entrance
  fadeIn,
  flyIn,
  zoomIn,
  wipeIn,
  bounceIn,
  // Emphasis
  pulse,
  spin,
  growShrink,
  teeter,
  colorPulse,
  // Exit
  fadeOut,
  flyOut,
  zoomOut,
  // Motion
  line,
  arc,
  circle,
  zigzag,
  curve,
  heart,
  star,
  turn,
  wave,
  spiral,
  swish,
  boomerang,
  customPath,
}

/// One animation applied to one shape.
class ObjectAnimation {
  /// Id of the target shape ('sh_...' or freeText id 'ft_...').
  final String shapeId;

  final AnimationEffect effect;
  final AnimationGroup group;

  /// Delay before the animation starts (seconds).
  final double delay;

  /// Duration of the animation (seconds).
  final double duration;

  /// Number of repeats (0 = once, -1 = infinite).
  final int repeat;

  /// Whether the animation plays backwards after each repeat.
  final bool autoReverse;

  final AnimationStart start;

  /// Trigger: when non-null, the animation only starts when the user clicks
  /// this shape id (Track 31, P1).
  final String? triggerShapeId;

  /// Motion path waypoints in % of the shape's box (Track 31, P3/P4).
  final List<({double x, double y})>? pathPoints;

  /// Direction parameter (e.g. 'left'/'right' for flyIn, 'in'/'out').
  final String? direction;

  const ObjectAnimation({
    required this.shapeId,
    required this.effect,
    required this.group,
    this.delay = 0,
    this.duration = 0.5,
    this.repeat = 0,
    this.autoReverse = false,
    this.start = AnimationStart.onClick,
    this.triggerShapeId,
    this.pathPoints,
    this.direction,
  });

  ObjectAnimation copyWith({
    String? shapeId,
    AnimationEffect? effect,
    AnimationGroup? group,
    double? delay,
    double? duration,
    int? repeat,
    bool? autoReverse,
    AnimationStart? start,
    String? triggerShapeId,
    bool clearTrigger = false,
    List<({double x, double y})>? pathPoints,
    String? direction,
  }) =>
      ObjectAnimation(
        shapeId: shapeId ?? this.shapeId,
        effect: effect ?? this.effect,
        group: group ?? this.group,
        delay: delay ?? this.delay,
        duration: duration ?? this.duration,
        repeat: repeat ?? this.repeat,
        autoReverse: autoReverse ?? this.autoReverse,
        start: start ?? this.start,
        triggerShapeId: clearTrigger ? null : (triggerShapeId ?? this.triggerShapeId),
        pathPoints: pathPoints ?? this.pathPoints,
        direction: direction ?? this.direction,
      );

  Map<String, dynamic> toMap() => {
        'shapeId': shapeId,
        'effect': effect.name,
        'group': group.name,
        'delay': delay,
        'duration': duration,
        'repeat': repeat,
        'autoReverse': autoReverse,
        'start': start.name,
        if (triggerShapeId != null) 'triggerShapeId': triggerShapeId,
        if (pathPoints != null)
          'pathPoints': [
            for (final p in pathPoints!) {'x': p.x, 'y': p.y},
          ],
        if (direction != null) 'direction': direction,
      };

  static ObjectAnimation fromMap(Map<String, dynamic> map) {
    AnimationGroup group;
    try {
      group = AnimationGroup.values.byName(map['group']?.toString() ?? 'entrance');
    } catch (_) {
      group = AnimationGroup.entrance;
    }
    AnimationEffect effect;
    try {
      effect = AnimationEffect.values.byName(map['effect']?.toString() ?? 'fadeIn');
    } catch (_) {
      effect = AnimationEffect.fadeIn;
    }
    AnimationStart start;
    try {
      start = AnimationStart.values.byName(map['start']?.toString() ?? 'onClick');
    } catch (_) {
      start = AnimationStart.onClick;
    }
    final rawPath = map['pathPoints'];
    final pathPoints = rawPath is List
        ? [
            for (final e in rawPath)
              if (e is Map)
                (
                  x: (e['x'] as num?)?.toDouble() ?? 0,
                  y: (e['y'] as num?)?.toDouble() ?? 0,
                ),
          ]
        : null;
    return ObjectAnimation(
      shapeId: map['shapeId']?.toString() ?? '',
      effect: effect,
      group: group,
      delay: (map['delay'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0.5,
      repeat: (map['repeat'] as num?)?.toInt() ?? 0,
      autoReverse: map['autoReverse'] == true,
      start: start,
      triggerShapeId: map['triggerShapeId']?.toString(),
      pathPoints: (pathPoints == null || pathPoints.isEmpty) ? null : pathPoints,
      direction: map['direction']?.toString(),
    );
  }
}
