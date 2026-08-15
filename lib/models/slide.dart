// Slide transition effects that map to PPTX transitions and CSS animations.
enum SlideEffect {
  // Original effects (v0.x)
  none,
  fade,
  pushLeft,
  pushRight,
  pushUp,
  pushDown,
  wipe,
  splitIn,
  splitOut,
  randomBar,
  checkerboard,
  blinds,
  clock,
  zoom,

  // New entrance effects (v1.0)
  flyInLeft,
  flyInRight,
  flyInTop,
  flyInBottom,
  appear,
  basicZoom,
  swivel,
  boomerang,

  // New emphasis effects (v1.0)
  pulse,
  growShrink,
  spin,
  teeter,
  flicker,
  colorPulse,

  // New exit effects (v1.0)
  flyOutLeft,
  flyOutRight,
  disappear,

  // New motion path effects (v1.0)
  arc,
  customPath,

  // Track 33: 26 new transitions (ISO + PowerPoint 2010 p14 set)
  dissolve,
  coverLeft,
  coverRight,
  coverUp,
  coverDown,
  uncoverLeft,
  uncoverRight,
  uncoverUp,
  uncoverDown,
  curtain,
  cedar,
  pageCurl,
  ripple,
  vortex,
  shred,
  diamond,
  wedge,
  newsflash,
  ferris,
  flip,
  gallery,
  honeycomb,
  invert,
  orbit,
  origami,
  reveal,
}

/// A typed presentation slide.
///
/// Replaces the loose `Map<String, dynamic>` slide representation.
/// [toMap]/[fromMap] stay backward compatible with previously persisted maps
/// (missing fields fall back to sensible defaults).
class Slide {
  final String title;
  final String htmlContent;

  /// Speaker notes exported to the PPTX notes slide (empty = none).
  final String notes;

  /// Per-slide transition override; null means "use the deck-wide effect".
  final SlideEffect? effect;

  /// Creation timestamp used as a stable list key in the UI.
  final int timestamp;

  /// Per-slide background color override (hex e.g. #FFFFFF or data-bg-color).
  final String? bgColor;

  /// Custom inline CSS style overrides for this specific slide.
  final String? customCss;

  /// Layout structure classification (e.g. 'standard', 'grid2', 'grid3', 'hero', 'quote', 'kpi').
  final String layoutType;

  /// Hidden slides are excluded from exported PDFs unless explicitly
  /// included (Track 06, P6).
  final bool hidden;

  /// Tags associated with the slide (e.g. ['intro', 'chart', 'summary']).
  final List<String> tags;

  /// Visual elements metadata for Drag-and-Drop overlay editing.
  final Map<String, dynamic> visualElements;

  /// Narration audio file (m4a/wav) attached to this slide (Track 13).
  /// An empty path means the slide has no narration. The file may live in
  /// the project bundle (`media/audioN.m4a`, [audioEmbedded] = true) or in
  /// the local audio directory after a bundle load.
  final String audioPath;

  /// Whether [audioPath] refers to an entry inside the `.ghita` bundle
  /// (true after a bundle save) rather than a local file.
  final bool audioEmbedded;

  /// Narration playback options (Track 13, P6–P7): durationMs, autoplay,
  /// loop, acrossSlides, hideIcon, trimStart, trimEnd (seconds).
  final Map<String, dynamic> audioOptions;

  Slide({
    required this.title,
    required this.htmlContent,
    this.notes = '',
    this.effect,
    int? timestamp,
    this.bgColor,
    this.customCss,
    this.layoutType = 'standard',
    this.hidden = false,
    List<String>? tags,
    Map<String, dynamic>? visualElements,
    this.audioPath = '',
    this.audioEmbedded = false,
    Map<String, dynamic>? audioOptions,
    this.transitionDurationMs = 500,
    this.transitionSound = '',
    this.autoAdvanceMs = 0,
    this.morphFromPrevious = false,
  })  : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
        tags = tags ?? const [],
        visualElements = visualElements ?? const {},
        audioOptions = audioOptions ?? const {};

  /// Track 33: transition duration in ms (0.1–3s), per-slide override.
  final int transitionDurationMs;

  /// Track 33: optional transition sound name ('' = none).
  final String transitionSound;

  /// Track 33: auto-advance after N ms (0 = off) — per-slide override that
  /// wins over the deck-wide auto-advance.
  final int autoAdvanceMs;

  /// Track 34: when true, this slide morphs from the previous slide
  /// (FLIP animation in HTML, p14:morph transition in PPTX).
  final bool morphFromPrevious;

  Slide copyWith({
    String? title,
    String? htmlContent,
    String? notes,
    SlideEffect? effect,
    bool clearEffect = false,
    int? timestamp,
    String? bgColor,
    String? customCss,
    String? layoutType,
    bool? hidden,
    List<String>? tags,
    Map<String, dynamic>? visualElements,
    String? audioPath,
    bool clearAudio = false,
    bool? audioEmbedded,
    Map<String, dynamic>? audioOptions,
    int? transitionDurationMs,
    String? transitionSound,
    int? autoAdvanceMs,
    bool? morphFromPrevious,
  }) {
    return Slide(
      title: title ?? this.title,
      htmlContent: htmlContent ?? this.htmlContent,
      notes: notes ?? this.notes,
      effect: clearEffect ? null : (effect ?? this.effect),
      timestamp: timestamp ?? this.timestamp,
      bgColor: bgColor ?? this.bgColor,
      customCss: customCss ?? this.customCss,
      layoutType: layoutType ?? this.layoutType,
      hidden: hidden ?? this.hidden,
      // Deep-copy the containers: history/undo reuses copyWith for snapshots,
      // and aliasing the same mutable List/Map would let an in-place mutation
      // corrupt every stored snapshot at once.
      tags: List.of(tags ?? this.tags),
      visualElements: Map<String, dynamic>.of(visualElements ?? this.visualElements),
      audioPath: clearAudio ? '' : (audioPath ?? this.audioPath),
      audioEmbedded: clearAudio ? false : (audioEmbedded ?? this.audioEmbedded),
      audioOptions: clearAudio
          ? const {}
          : Map<String, dynamic>.of(audioOptions ?? this.audioOptions),
      transitionDurationMs: transitionDurationMs ?? this.transitionDurationMs,
      transitionSound: transitionSound ?? this.transitionSound,
      autoAdvanceMs: autoAdvanceMs ?? this.autoAdvanceMs,
      morphFromPrevious: morphFromPrevious ?? this.morphFromPrevious,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'htmlContent': htmlContent,
      if (notes.isNotEmpty) 'notes': notes,
      if (effect != null) 'effect': effect!.name,
      'timestamp': timestamp,
      if (bgColor != null) 'bgColor': bgColor,
      if (customCss != null) 'customCss': customCss,
      'layoutType': layoutType,
      if (hidden) 'hidden': hidden,
      if (tags.isNotEmpty) 'tags': tags,
      if (visualElements.isNotEmpty) 'visualElements': visualElements,
      if (audioPath.isNotEmpty) 'audioPath': audioPath,
      if (audioEmbedded) 'audioEmbedded': true,
      if (audioOptions.isNotEmpty) 'audioOptions': audioOptions,
      if (transitionDurationMs != 500) 'transitionDurationMs': transitionDurationMs,
      if (transitionSound.isNotEmpty) 'transitionSound': transitionSound,
      if (autoAdvanceMs > 0) 'autoAdvanceMs': autoAdvanceMs,
      if (morphFromPrevious) 'morphFromPrevious': true,
    };
  }

  factory Slide.fromMap(Map<String, dynamic> map) {
    SlideEffect? effect;
    final effectName = map['effect'];
    if (effectName is String && effectName.isNotEmpty) {
      try {
        effect = SlideEffect.values.byName(effectName);
      } catch (_) {
        effect = null;
      }
    }
    final rawTags = map['tags'];
    final tagsList = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    final rawVisual = map['visualElements'];
    final visualMap = rawVisual is Map<String, dynamic>
        ? rawVisual
        : (rawVisual is Map
            ? Map<String, dynamic>.from(rawVisual)
            : <String, dynamic>{});

    // Track 13: narration audio (backward compatible — absent = no audio).
    final rawAudioOptions = map['audioOptions'];
    final audioOptionsMap = rawAudioOptions is Map<String, dynamic>
        ? rawAudioOptions
        : (rawAudioOptions is Map
            ? Map<String, dynamic>.from(rawAudioOptions)
            : <String, dynamic>{});

    return Slide(
      title: (map['title'] ?? 'Untitled Slide').toString(),
      htmlContent: (map['htmlContent'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      effect: effect,
      timestamp: map['timestamp'] is int
          ? map['timestamp'] as int
          : DateTime.now().millisecondsSinceEpoch,
      bgColor: map['bgColor']?.toString(),
      customCss: map['customCss']?.toString(),
      layoutType: map['layoutType']?.toString() ?? 'standard',
      hidden: map['hidden'] == true,
      tags: tagsList,
      visualElements: visualMap,
      audioPath: map['audioPath']?.toString() ?? '',
      audioEmbedded: map['audioEmbedded'] == true,
      audioOptions: audioOptionsMap,
      transitionDurationMs: (map['transitionDurationMs'] as num?)?.toInt() ?? 500,
      transitionSound: map['transitionSound']?.toString() ?? '',
      autoAdvanceMs: (map['autoAdvanceMs'] as num?)?.toInt() ?? 0,
      morphFromPrevious: map['morphFromPrevious'] == true,
    );
  }
}
