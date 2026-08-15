import '../models/object_animation.dart';

/// Animation engine (Track 29, FEAT 43/46/47/48 + Track 31 FEAT 45/49).
///
/// Turns `ObjectAnimation` instances into:
///  * CSS keyframes + animation declarations the HTML/WebView2 player runs
///    (with the same timing model as the PPTX export),
///  * motion-path waypoints for the 12 presets + custom paths,
///  * metadata for the Animation Pane UI.
class AnimationEngine {
  AnimationEngine._();

  /// Compiled once — `cssClass` runs per animated shape per deck build.
  static final RegExp _cssClassSanitizeRe = RegExp(r'[^a-zA-Z0-9]');
  /// Trims trailing zeros from formatted seconds (shared by `_sec`).
  static final RegExp _trailingZeroRe = RegExp(r'0+$');

  /// Localizable-ish display names (English keys; UI looks them up in l10n).
  static const Map<AnimationEffect, String> effectNames = {
    AnimationEffect.fadeIn: 'Fade In',
    AnimationEffect.flyIn: 'Fly In',
    AnimationEffect.zoomIn: 'Zoom In',
    AnimationEffect.wipeIn: 'Wipe In',
    AnimationEffect.bounceIn: 'Bounce In',
    AnimationEffect.pulse: 'Pulse',
    AnimationEffect.spin: 'Spin',
    AnimationEffect.growShrink: 'Grow/Shrink',
    AnimationEffect.teeter: 'Teeter',
    AnimationEffect.colorPulse: 'Color Pulse',
    AnimationEffect.fadeOut: 'Fade Out',
    AnimationEffect.flyOut: 'Fly Out',
    AnimationEffect.zoomOut: 'Zoom Out',
    AnimationEffect.line: 'Line',
    AnimationEffect.arc: 'Arc',
    AnimationEffect.circle: 'Circle',
    AnimationEffect.zigzag: 'Zigzag',
    AnimationEffect.curve: 'Curve',
    AnimationEffect.heart: 'Heart',
    AnimationEffect.star: 'Star',
    AnimationEffect.turn: 'Turn',
    AnimationEffect.wave: 'Wave',
    AnimationEffect.spiral: 'Spiral',
    AnimationEffect.swish: 'Swish',
    AnimationEffect.boomerang: 'Boomerang',
    AnimationEffect.customPath: 'Custom Path',
  };

  /// Which group an effect belongs to (single source of truth).
  static AnimationGroup groupOf(AnimationEffect e) => switch (e) {
        AnimationEffect.fadeIn ||
        AnimationEffect.flyIn ||
        AnimationEffect.zoomIn ||
        AnimationEffect.wipeIn ||
        AnimationEffect.bounceIn =>
          AnimationGroup.entrance,
        AnimationEffect.pulse ||
        AnimationEffect.spin ||
        AnimationEffect.growShrink ||
        AnimationEffect.teeter ||
        AnimationEffect.colorPulse =>
          AnimationGroup.emphasis,
        AnimationEffect.fadeOut ||
        AnimationEffect.flyOut ||
        AnimationEffect.zoomOut =>
          AnimationGroup.exit,
        AnimationEffect.line ||
        AnimationEffect.arc ||
        AnimationEffect.circle ||
        AnimationEffect.zigzag ||
        AnimationEffect.curve ||
        AnimationEffect.heart ||
        AnimationEffect.star ||
        AnimationEffect.turn ||
        AnimationEffect.wave ||
        AnimationEffect.spiral ||
        AnimationEffect.swish ||
        AnimationEffect.boomerang ||
        AnimationEffect.customPath =>
          AnimationGroup.motion,
      };

  /// 12 motion-path presets (Track 31, P3) as relative waypoints in a
  /// 0..100 box. Each list starts at (0,0) = the shape's origin.
  static Map<AnimationEffect, List<({double x, double y})>> motionPresets() => {
        AnimationEffect.line: [
          (x: 0, y: 0),
          (x: 0, y: 100),
        ],
        AnimationEffect.zigzag: [
          (x: 0, y: 0),
          (x: 20, y: 80),
          (x: 40, y: 0),
          (x: 60, y: 80),
          (x: 80, y: 0),
          (x: 100, y: 80),
        ],
        // ---- Track 31, P3: 12 motion-path presets ----
        AnimationEffect.turn: [
          (x: 0, y: 0),
          (x: 50, y: 0),
          (x: 100, y: 50),
          (x: 100, y: 100),
        ],
        AnimationEffect.wave: [
          (x: 0, y: 50),
          (x: 20, y: 0),
          (x: 40, y: 100),
          (x: 60, y: 0),
          (x: 80, y: 100),
          (x: 100, y: 50),
        ],
        AnimationEffect.spiral: [
          (x: 50, y: 50),
          (x: 90, y: 10),
          (x: 90, y: 90),
          (x: 10, y: 90),
          (x: 10, y: 30),
          (x: 50, y: 30),
          (x: 50, y: 50),
        ],
        AnimationEffect.swish: [
          (x: 0, y: 100),
          (x: 40, y: 40),
          (x: 60, y: 60),
          (x: 100, y: 0),
        ],
        AnimationEffect.boomerang: [
          (x: 0, y: 0),
          (x: 100, y: -60),
          (x: 50, y: -30),
          (x: 0, y: 0),
        ],
        AnimationEffect.arc: [
          (x: 0, y: 0),
          (x: 25, y: 60),
          (x: 50, y: 80),
          (x: 75, y: 60),
          (x: 100, y: 0),
        ],
        AnimationEffect.circle: [
          (x: 50, y: 0),
          (x: 100, y: 50),
          (x: 50, y: 100),
          (x: 0, y: 50),
          (x: 50, y: 0),
        ],
        AnimationEffect.curve: [
          (x: 0, y: 0),
          (x: 30, y: 10),
          (x: 70, y: 90),
          (x: 100, y: 100),
        ],
        AnimationEffect.heart: [
          (x: 50, y: 0),
          (x: 100, y: 40),
          (x: 50, y: 100),
          (x: 0, y: 40),
          (x: 50, y: 0),
        ],
        AnimationEffect.star: [
          (x: 50, y: 0),
          (x: 62, y: 38),
          (x: 100, y: 38),
          (x: 68, y: 62),
          (x: 80, y: 100),
          (x: 50, y: 76),
          (x: 20, y: 100),
          (x: 32, y: 62),
          (x: 0, y: 38),
          (x: 38, y: 38),
          (x: 50, y: 0),
        ],
      };

  /// Default effects exposed by the pane grouped for the picker.
  static Map<AnimationGroup, List<AnimationEffect>> effectsByGroup() => {
        AnimationGroup.entrance: [
          AnimationEffect.fadeIn,
          AnimationEffect.flyIn,
          AnimationEffect.zoomIn,
          AnimationEffect.wipeIn,
          AnimationEffect.bounceIn,
        ],
        AnimationGroup.emphasis: [
          AnimationEffect.pulse,
          AnimationEffect.spin,
          AnimationEffect.growShrink,
          AnimationEffect.teeter,
          AnimationEffect.colorPulse,
        ],
        AnimationGroup.exit: [
          AnimationEffect.fadeOut,
          AnimationEffect.flyOut,
          AnimationEffect.zoomOut,
        ],
        AnimationGroup.motion: [
          AnimationEffect.line,
          AnimationEffect.arc,
          AnimationEffect.circle,
          AnimationEffect.zigzag,
          AnimationEffect.curve,
          AnimationEffect.heart,
          AnimationEffect.star,
          AnimationEffect.turn,
          AnimationEffect.wave,
          AnimationEffect.spiral,
          AnimationEffect.swish,
          AnimationEffect.boomerang,
          AnimationEffect.customPath,
        ],
      };

  /// Unique CSS class for one animation.
  static String cssClass(ObjectAnimation a) =>
      'ghita-anim-${a.shapeId.replaceAll(_cssClassSanitizeRe, '_')}-${a.effect.name}';

  /// CSS keyframes for [effect] (the [direction] parameter, e.g. fly-in
  /// direction, is baked in). [name] overrides the keyframe name so two
  /// animations of the same effect with different directions do not collide.
  static String keyframesFor(AnimationEffect effect, {String? direction, String? name}) {
    final dir = direction ?? 'left';
    final (from, to) = switch (effect) {
      AnimationEffect.fadeIn => ('opacity: 0', 'opacity: 1'),
      AnimationEffect.flyIn => switch (dir) {
          'right' => ('transform: translateX(-120%)', 'transform: translateX(0)'),
          'top' => ('transform: translateY(-120%)', 'transform: translateY(0)'),
          'bottom' => ('transform: translateY(120%)', 'transform: translateY(0)'),
          _ => ('transform: translateX(120%)', 'transform: translateX(0)'),
        },
      AnimationEffect.zoomIn => ('transform: scale(0.1); opacity: 0', 'transform: scale(1); opacity: 1'),
      AnimationEffect.wipeIn => ('clip-path: inset(0 100% 0 0)', 'clip-path: inset(0 0 0 0)'),
      AnimationEffect.bounceIn => (
          'transform: translateY(-100%); opacity: 0',
          'transform: translateY(0); opacity: 1'
        ),
      AnimationEffect.pulse => ('transform: scale(1)', 'transform: scale(1.08)'),
      AnimationEffect.spin => ('transform: rotate(0deg)', 'transform: rotate(360deg)'),
      AnimationEffect.growShrink => ('transform: scale(0.5)', 'transform: scale(1.25)'),
      AnimationEffect.teeter => ('transform: rotate(0deg)', 'transform: rotate(6deg)'),
      AnimationEffect.colorPulse => ('filter: brightness(1)', 'filter: brightness(2)'),
      AnimationEffect.fadeOut => ('opacity: 1', 'opacity: 0'),
      AnimationEffect.flyOut => switch (dir) {
          'right' => ('transform: translateX(0)', 'transform: translateX(120%)'),
          'top' => ('transform: translateY(0)', 'transform: translateY(-120%)'),
          'bottom' => ('transform: translateY(0)', 'transform: translateY(120%)'),
          _ => ('transform: translateX(0)', 'transform: translateX(-120%)'),
        },
      AnimationEffect.zoomOut => ('transform: scale(1); opacity: 1', 'transform: scale(0.1); opacity: 0'),
      // Motion paths use the keyframe list built separately.
      AnimationEffect.line ||
      AnimationEffect.arc ||
      AnimationEffect.circle ||
      AnimationEffect.zigzag ||
      AnimationEffect.curve ||
      AnimationEffect.heart ||
      AnimationEffect.star ||
      AnimationEffect.turn ||
      AnimationEffect.wave ||
      AnimationEffect.spiral ||
      AnimationEffect.swish ||
      AnimationEffect.boomerang ||
      AnimationEffect.customPath =>
        ('transform: translate(0, 0)', 'transform: translate(0, 0)'),
    };

    final kfName = name ?? effect.name;
    // Bounce needs a springy middle keyframe.
    if (effect == AnimationEffect.bounceIn) {
      return '''
@keyframes $kfName {
  0% { $from }
  60% { transform: translateY(-14%); opacity: 1 }
  100% { $to }
}''';
    }
    if (effect == AnimationEffect.teeter || effect == AnimationEffect.colorPulse) {
      return '''
@keyframes $kfName {
  0% { $from }
  25% { $to }
  50% { $from }
  75% { $to }
  100% { $from }
}''';
    }
    return '''
@keyframes $kfName {
  0% { $from }
  100% { $to }
}''';
  }

  /// Motion-path keyframes (Track 31) — translate the shape through
  /// [points] (relative % of its own box).
  static String motionKeyframes(
    String name,
    List<({double x, double y})> points,
  ) {
    final buf = StringBuffer()..writeln('@keyframes $name {');
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final pct = (i * 100 / (n - 1)).toStringAsFixed(1);
      buf.writeln(
        '  $pct% { transform: translate(${_fmt(points[i].x)}%, ${_fmt(points[i].y)}%); }',
      );
    }
    buf.write('}');
    return buf.toString();
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(2);

  /// The `animation` shorthand for one animation. [keyframeName] overrides
  /// the default keyframe name (needed when cssFor disambiguates directions).
  static String animationShorthand(ObjectAnimation a, {String? keyframeName}) {
    final name = a.group == AnimationGroup.motion
        ? '${cssClass(a)}_path'
        : (keyframeName ?? a.effect.name);
    final iters = a.repeat == -1 ? 'infinite' : '${a.repeat + 1}';
    final direction = a.autoReverse ? 'alternate' : 'normal';
    final fill = a.group == AnimationGroup.entrance ? 'both' : 'forwards';
    return '$name ${_sec(a.duration)}s ease ${_sec(a.delay)}s '
        '$iters $direction $fill';
  }

  static String _sec(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    final s = v.toStringAsFixed(2).replaceFirst(_trailingZeroRe, '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  /// Full `<style>` block for a list of animations.
  static String cssFor(List<ObjectAnimation> animations) {
    final buf = StringBuffer();
    // Keyframe names must be unique per (effect, direction): two flyIn
    // animations with different directions would otherwise collide.
    final usedNames = <String, int>{};
    for (final a in animations) {
      String? kfName;
      if (a.group == AnimationGroup.motion) {
        final points = a.pathPoints ?? motionPresets()[a.effect] ?? const [];
        if (points.length >= 2) {
          buf.writeln(motionKeyframes('${cssClass(a)}_path', points));
        }
      } else {
        final base = a.direction == null
            ? a.effect.name
            : '${a.effect.name}_${a.direction}';
        final n = usedNames[base] ?? 0;
        usedNames[base] = n + 1;
        final kfName = n == 0 ? base : '${base}_$n';
        buf.writeln(
          keyframesFor(a.effect, direction: a.direction, name: kfName),
        );
      }
      buf.writeln(
        '.${cssClass(a)} { animation: ${animationShorthand(a, keyframeName: kfName)}; }',
      );
    }
    return buf.toString();
  }

  /// CSS selector for a shape element (id based).
  static String selectorFor(ObjectAnimation a) => '[data-ghita-id="${a.shapeId}"]';

  /// Sort key for the animation pane (start order: after → with → click,
  /// then delay).
  static int orderIndex(ObjectAnimation a) => switch (a.start) {
        AnimationStart.onClick => 2,
        AnimationStart.withPrevious => 1,
        AnimationStart.afterPrevious => 0,
      };
}
