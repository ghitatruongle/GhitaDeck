/// Shape & text effects (Track 25, FEAT 34).
///
/// Covers inline style effects: shadow, glow, reflection, soft edge, bevel
/// and 3D rotation presets. Pure data — generates both the CSS used by the
/// HTML exporter and the OOXML `<a:effectLst>` / `<a:sp3d>` used by the
/// PPTX exporter so every format renders the same effect.
library;

import 'dart:convert';

/// The 12 bevel/3D rotation presets offered in the Effects UI.
const List<String> kBevelPresets = [
  'none',
  'angle',
  'artDeco',
  'coolSlant',
  'divot',
  'hardEdge',
  'relaxedInset',
  'rim',
  'round',
  'softRound',
  'slope',
  'convex',
];

/// Quick shadow presets (P7): No / Soft / Hard / Glow / Neumorphism.
enum EffectPreset { none, soft, hard, glow, neumorphism }

class ShapeEffect {
  /// Shadow
  final bool shadow;
  final double shadowOffsetX; // % of shape width (positive = right/down)
  final double shadowOffsetY;
  final double shadowBlur; // % of shape size
  final String shadowColor; // #RRGGBB
  final double shadowAlpha; // 0..1

  /// Glow
  final bool glow;
  final String glowColor;
  final double glowSize; // % of shape size

  /// Reflection
  final bool reflection;
  final double reflectionOffset; // % gap below the shape
  final double reflectionAlpha; // 0..1 at the top of the reflection
  final double reflectionScale; // 0..1 height of the reflection

  /// Soft edge (radius in % of shape size; 0 = none)
  final double softEdge;

  /// Bevel preset (one of [kBevelPresets]); 'none' disables.
  final String bevel;

  /// 3D rotation in degrees (all zero = none).
  final double rot3dX;
  final double rot3dY;
  final double rot3dZ;

  const ShapeEffect({
    this.shadow = false,
    this.shadowOffsetX = 3,
    this.shadowOffsetY = 3,
    this.shadowBlur = 6,
    this.shadowColor = '#000000',
    this.shadowAlpha = 0.5,
    this.glow = false,
    this.glowColor = '#FFD700',
    this.glowSize = 8,
    this.reflection = false,
    this.reflectionOffset = 2,
    this.reflectionAlpha = 0.35,
    this.reflectionScale = 0.3,
    this.softEdge = 0,
    this.bevel = 'none',
    this.rot3dX = 0,
    this.rot3dY = 0,
    this.rot3dZ = 0,
  });

  bool get isEmpty =>
      !shadow && !glow && !reflection && softEdge == 0 && bevel == 'none' &&
      rot3dX == 0 && rot3dY == 0 && rot3dZ == 0;

  static const ShapeEffect none = ShapeEffect();

  ShapeEffect copyWith({
    bool? shadow,
    double? shadowOffsetX,
    double? shadowOffsetY,
    double? shadowBlur,
    String? shadowColor,
    double? shadowAlpha,
    bool? glow,
    String? glowColor,
    double? glowSize,
    bool? reflection,
    double? reflectionOffset,
    double? reflectionAlpha,
    double? reflectionScale,
    double? softEdge,
    String? bevel,
    double? rot3dX,
    double? rot3dY,
    double? rot3dZ,
  }) =>
      ShapeEffect(
        shadow: shadow ?? this.shadow,
        shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
        shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
        shadowBlur: shadowBlur ?? this.shadowBlur,
        shadowColor: shadowColor ?? this.shadowColor,
        shadowAlpha: shadowAlpha ?? this.shadowAlpha,
        glow: glow ?? this.glow,
        glowColor: glowColor ?? this.glowColor,
        glowSize: glowSize ?? this.glowSize,
        reflection: reflection ?? this.reflection,
        reflectionOffset: reflectionOffset ?? this.reflectionOffset,
        reflectionAlpha: reflectionAlpha ?? this.reflectionAlpha,
        reflectionScale: reflectionScale ?? this.reflectionScale,
        softEdge: softEdge ?? this.softEdge,
        bevel: bevel ?? this.bevel,
        rot3dX: rot3dX ?? this.rot3dX,
        rot3dY: rot3dY ?? this.rot3dY,
        rot3dZ: rot3dZ ?? this.rot3dZ,
      );

  /// Apply a quick preset (P7).
  ShapeEffect withPreset(EffectPreset preset) {
    return switch (preset) {
      EffectPreset.none => ShapeEffect.none,
      EffectPreset.soft => copyWith(
          shadow: true, shadowBlur: 10, shadowAlpha: 0.4, shadowOffsetY: 4),
      EffectPreset.hard => copyWith(
          shadow: true, shadowBlur: 1, shadowAlpha: 0.6, shadowOffsetY: 2),
      EffectPreset.glow => copyWith(glow: true, glowColor: '#00BFFF', glowSize: 12),
      EffectPreset.neumorphism => copyWith(
          shadow: true,
          shadowBlur: 14,
          shadowAlpha: 0.35,
          shadowOffsetX: 6,
          shadowOffsetY: 6,
          shadowColor: '#888888'),
    };
  }

  // ---- CSS (HTML exporter) ---------------------------------------------

  /// Box-level CSS (for shapes): box-shadow + filter + transform + mask.
  String toCss({required double wPercent, required double hPercent}) {
    final parts = <String>[];
    // Resolve %-based sizes against the shape box (used at render time).
    final blurPx = (shadowBlur * wPercent / 100).toStringAsFixed(1);
    final offXPx = (shadowOffsetX * wPercent / 100).toStringAsFixed(1);
    final offYPx = (shadowOffsetY * hPercent / 100).toStringAsFixed(1);
    if (shadow) {
      final alphaHex = (shadowAlpha * 255).round().toRadixString(16).padLeft(2, '0');
      parts.add('box-shadow: ${offXPx}px ${offYPx}px ${blurPx}px $shadowColor$alphaHex');
    }
    if (glow) {
      final gPx = (glowSize * wPercent / 100).toStringAsFixed(1);
      parts.add('filter: drop-shadow(0 0 ${gPx}px $glowColor)');
    }
    if (softEdge > 0) {
      final sePx = (softEdge * wPercent / 100).toStringAsFixed(1);
      // Soft edge approximated with a large blur mask — falls back gracefully
      // in browsers without mask support.
      parts.add('filter: blur(${sePx}px)');
    }
    if (rot3dX != 0 || rot3dY != 0 || rot3dZ != 0) {
      parts.add(
          'transform: perspective(800px) rotateX(${rot3dX.toStringAsFixed(1)}deg) rotateY(${rot3dY.toStringAsFixed(1)}deg) rotateZ(${rot3dZ.toStringAsFixed(1)}deg)');
    }
    return parts.join('; ');
  }

  /// Text-level CSS (for free text boxes): text-shadow + letter effects.
  String toTextCss() {
    final parts = <String>[];
    if (shadow) {
      final alphaHex = (shadowAlpha * 255).round().toRadixString(16).padLeft(2, '0');
      parts.add(
          'text-shadow: ${shadowOffsetX.toStringAsFixed(1)}px ${shadowOffsetY.toStringAsFixed(1)}px ${shadowBlur.toStringAsFixed(1)}px $shadowColor$alphaHex');
    }
    if (softEdge > 0) {
      parts.add('filter: blur(${softEdge.toStringAsFixed(1)}px)');
    }
    if (glow) {
      parts.add('text-shadow: 0 0 ${glowSize.toStringAsFixed(1)}px $glowColor');
    }
    return parts.join('; ');
  }

  // ---- OOXML (PPTX exporter) -------------------------------------------

  /// `<a:effectLst>…</a:effectLst>` fragment (empty string when no effects).
  /// All sizes are in EMU-friendly thousandths of a percent per OOXML spec
  /// (e.g. blurRad 38100 = 0.03 cm-ish safe value PowerPoint accepts).
  String toEffectLstXml() {
    final parts = <String>[];
    if (shadow) {
      final alpha = (shadowAlpha * 100000).round();
      final dist = (shadowOffsetY * 1270).round(); // ~pt-scale, kept small
      final blur = (shadowBlur * 12700).round();
      parts.add(
          '<a:outerShdw blurRad="${blur.clamp(0, 50800)}" dist="${dist.clamp(0, 50800)}" dir="5400000" rotWithShape="0">'
          '<a:srgbClr val="${_cleanHex(shadowColor)}"><a:alpha val="${alpha.clamp(0, 100000)}"/></a:srgbClr>'
          '</a:outerShdw>');
    }
    if (glow) {
      final rad = (glowSize * 12700).round().clamp(12700, 50800);
      parts.add(
          '<a:glow rad="$rad"><a:srgbClr val="${_cleanHex(glowColor)}"><a:alpha val="50000"/></a:srgbClr></a:glow>');
    }
    if (reflection) {
      final stA = (reflectionAlpha * 100000).round();
      parts.add(
          '<a:reflection blurRad="20066" stA="$stA" endA="0" dist="0" dir="5400000" algn="tl" rotWithShape="0" sx="100000" sy="100000" kx="0" ky="0"/>');
    }
    if (softEdge > 0) {
      final rad = (softEdge * 12700).round().clamp(1270, 50800);
      parts.add('<a:softEdge rad="$rad"/>');
    }
    if (parts.isEmpty) return '';
    return '<a:effectLst>${parts.join()}</a:effectLst>';
  }

  /// `<a:sp3d>…</a:sp3d>` for bevel (empty when none).
  String toSp3dXml() {
    if (bevel == 'none' || bevel.isEmpty) return '';
    final preset = _bevelPptx(bevel);
    return '<a:sp3d prstMaterial="warmMatte">'
        '<a:bevelT w="${preset.$1}" h="${preset.$2}"/>'
        '</a:sp3d>';
  }

  Map<String, dynamic> toMap() => {
        if (shadow) ...{
          'shadow': true,
          'shadowOffsetX': shadowOffsetX,
          'shadowOffsetY': shadowOffsetY,
          'shadowBlur': shadowBlur,
          'shadowColor': shadowColor,
          'shadowAlpha': shadowAlpha,
        },
        if (glow) ...{'glow': true, 'glowColor': glowColor, 'glowSize': glowSize},
        if (reflection) ...{
          'reflection': true,
          'reflectionOffset': reflectionOffset,
          'reflectionAlpha': reflectionAlpha,
          'reflectionScale': reflectionScale,
        },
        if (softEdge > 0) 'softEdge': softEdge,
        if (bevel != 'none' && bevel.isNotEmpty) 'bevel': bevel,
        if (rot3dX != 0 || rot3dY != 0 || rot3dZ != 0)
          'rot3d': [rot3dX, rot3dY, rot3dZ],
      };

  static ShapeEffect fromMap(dynamic raw) {
    if (raw == null) return ShapeEffect.none;
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final rot = map['rot3d'];
    return ShapeEffect(
      shadow: map['shadow'] == true,
      shadowOffsetX: (map['shadowOffsetX'] as num?)?.toDouble() ?? 3,
      shadowOffsetY: (map['shadowOffsetY'] as num?)?.toDouble() ?? 3,
      shadowBlur: (map['shadowBlur'] as num?)?.toDouble() ?? 6,
      shadowColor: map['shadowColor']?.toString() ?? '#000000',
      shadowAlpha: (map['shadowAlpha'] as num?)?.toDouble() ?? 0.5,
      glow: map['glow'] == true,
      glowColor: map['glowColor']?.toString() ?? '#FFD700',
      glowSize: (map['glowSize'] as num?)?.toDouble() ?? 8,
      reflection: map['reflection'] == true,
      reflectionOffset: (map['reflectionOffset'] as num?)?.toDouble() ?? 2,
      reflectionAlpha: (map['reflectionAlpha'] as num?)?.toDouble() ?? 0.35,
      reflectionScale: (map['reflectionScale'] as num?)?.toDouble() ?? 0.3,
      softEdge: (map['softEdge'] as num?)?.toDouble() ?? 0,
      bevel: map['bevel']?.toString() ?? 'none',
      rot3dX: rot is List && rot.isNotEmpty ? (rot[0] as num).toDouble() : 0,
      rot3dY: rot is List && rot.length > 1 ? (rot[1] as num).toDouble() : 0,
      rot3dZ: rot is List && rot.length > 2 ? (rot[2] as num).toDouble() : 0,
    );
  }

  String toJsonString() => jsonEncode(toMap());

  static ShapeEffect fromJsonString(String? s) {
    if (s == null || s.isEmpty) return ShapeEffect.none;
    try {
      return fromMap(jsonDecode(s));
    } catch (_) {
      return ShapeEffect.none;
    }
  }

  static String _cleanHex(String hex) =>
      hex.replaceFirst('#', '').toUpperCase().padRight(6, '0').substring(0, 6);

  /// Map bevel preset → (w, h) in EMU thousandths (OOXML `<a:bevelT>`).
  static (int, int) _bevelPptx(String bevel) => switch (bevel) {
        'angle' => (50800, 12700),
        'artDeco' => (38100, 38100),
        'coolSlant' => (50800, 25400),
        'divot' => (25400, 50800),
        'hardEdge' => (12700, 12700),
        'relaxedInset' => (25400, 12700),
        'rim' => (12700, 25400),
        'round' => (38100, 25400),
        'softRound' => (25400, 25400),
        'slope' => (50800, 50800),
        'convex' => (38100, 50800),
        _ => (25400, 25400),
      };
}
