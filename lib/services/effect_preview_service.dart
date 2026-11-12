import '../models/slide.dart';

/// Service that generates CSS keyframe animations and transition styles
/// for slide effects in HTML export and preview.
class EffectPreviewService {
  /// Generate the CSS @keyframes and transition class for a given effect.
  static String generateEffectCss(SlideEffect effect, {double duration = 0.5}) {
    if (effect == SlideEffect.none) return '';

    final durationStr = '${duration}s';
    final keyframes = _keyframesForEffect(effect);
    final className = _classNameForEffect(effect);

    return '''
  @keyframes $className {
    $keyframes
  }
  .slide-transition-$className {
    animation: $className $durationStr ${_easingForEffect(effect)} forwards;
  }
''';
  }

  /// Generate CSS for exactly [effects] (Track 07, P2): only the effects
  /// actually used in the deck are emitted, and identical keyframe bodies
  /// are written once — every other class aliases the canonical
  /// `@keyframes` name instead of duplicating it.
  static String generateEffectsCss(
    Iterable<SlideEffect> effects, {
    double duration = 0.5,
  }) {
    final canonicalByBody = <String, String>{}; // keyframe body → name
    final keyframes = <String>[];
    final classes = <String>[];
    for (final effect in effects) {
      if (effect == SlideEffect.none) continue;
      final body = _keyframesForEffect(effect);
      final className = _classNameForEffect(effect);
      final canonical = canonicalByBody.putIfAbsent(body, () => className);
      if (canonical == className) {
        keyframes.add('@keyframes $className{$body}');
      }
      classes.add(
          '.slide-transition-$className{animation:$canonical var(--st-duration,${duration}s) ${_easingForEffect(effect)} forwards}');
    }
    return [...keyframes, ...classes].join('\n');
  }

  /// Generate CSS for all effects (included once in the HTML deck).
  static String generateAllEffectsCss({double duration = 0.5}) =>
      generateEffectsCss(SlideEffect.values, duration: duration);

  /// Get the CSS class name for a slide's transition.
  static String getTransitionClass(SlideEffect? effect) {
    if (effect == null || effect == SlideEffect.none) return '';
    return 'slide-transition-${_classNameForEffect(effect)}';
  }

  // ---- Keyframe definitions ----

  static String _keyframesForEffect(SlideEffect effect) {
    switch (effect) {
      // Original effects
      case SlideEffect.fade:
        return 'from { opacity: 0; } to { opacity: 1; }';
      case SlideEffect.pushLeft:
        return 'from { transform: translateX(100%); } to { transform: translateX(0); }';
      case SlideEffect.pushRight:
        return 'from { transform: translateX(-100%); } to { transform: translateX(0); }';
      case SlideEffect.pushUp:
        return 'from { transform: translateY(100%); } to { transform: translateY(0); }';
      case SlideEffect.pushDown:
        return 'from { transform: translateY(-100%); } to { transform: translateY(0); }';
      case SlideEffect.wipe:
        return 'from { clip-path: inset(0 100% 0 0); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.splitIn:
        return 'from { clip-path: inset(0 50% 0 50%); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.splitOut:
        return 'from { clip-path: inset(0 0 0 0); } to { clip-path: inset(0 50% 0 50%); }';
      case SlideEffect.randomBar:
        return 'from { clip-path: inset(0 100% 0 0); opacity: 0; } to { clip-path: inset(0 0 0 0); opacity: 1; }';
      case SlideEffect.checkerboard:
        return 'from { opacity: 0; transform: scale(0.8); } 50% { opacity: 0.5; } to { opacity: 1; transform: scale(1); }';
      case SlideEffect.blinds:
        return 'from { clip-path: inset(0 0 100% 0); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.clock:
        return 'from { clip-path: polygon(50% 50%, 50% 0%, 50% 0%, 50% 50%, 50% 50%, 50% 50%, 50% 50%, 50% 50%); } to { clip-path: polygon(50% 50%, 50% 0%, 100% 0%, 100% 100%, 0% 100%, 0% 0%, 50% 0%, 50% 50%); }';
      case SlideEffect.zoom:
        return 'from { transform: scale(0); opacity: 0; } to { transform: scale(1); opacity: 1; }';

      // New entrance effects
      case SlideEffect.flyInLeft:
        return 'from { transform: translateX(-150%); opacity: 0; } to { transform: translateX(0); opacity: 1; }';
      case SlideEffect.flyInRight:
        return 'from { transform: translateX(150%); opacity: 0; } to { transform: translateX(0); opacity: 1; }';
      case SlideEffect.flyInTop:
        return 'from { transform: translateY(-150%); opacity: 0; } to { transform: translateY(0); opacity: 1; }';
      case SlideEffect.flyInBottom:
        return 'from { transform: translateY(150%); opacity: 0; } to { transform: translateY(0); opacity: 1; }';
      case SlideEffect.appear:
        return 'from { opacity: 0; } to { opacity: 1; }';
      case SlideEffect.basicZoom:
        return 'from { transform: scale(3); opacity: 0; } to { transform: scale(1); opacity: 1; }';
      case SlideEffect.swivel:
        return 'from { transform: perspective(800px) rotateY(90deg); opacity: 0; } to { transform: perspective(800px) rotateY(0deg); opacity: 1; }';
      case SlideEffect.boomerang:
        return '0% { transform: translateX(-100%) rotate(-20deg); opacity: 0; } 60% { transform: translateX(5%) rotate(3deg); opacity: 1; } 100% { transform: translateX(0) rotate(0deg); opacity: 1; }';

      // New emphasis effects
      case SlideEffect.pulse:
        return '0% { transform: scale(1); } 50% { transform: scale(1.05); } 100% { transform: scale(1); }';
      case SlideEffect.growShrink:
        return '0% { transform: scale(0.5); opacity: 0; } 100% { transform: scale(1); opacity: 1; }';
      case SlideEffect.spin:
        return 'from { transform: rotate(0deg); opacity: 0; } to { transform: rotate(360deg); opacity: 1; }';
      case SlideEffect.teeter:
        return '0% { transform: rotate(0deg); } 25% { transform: rotate(3deg); } 50% { transform: rotate(-3deg); } 75% { transform: rotate(1deg); } 100% { transform: rotate(0deg); }';
      case SlideEffect.flicker:
        return '0% { opacity: 0; } 10% { opacity: 1; } 20% { opacity: 0.3; } 30% { opacity: 1; } 40% { opacity: 0.7; } 50% { opacity: 1; } 100% { opacity: 1; }';
      case SlideEffect.colorPulse:
        return '0% { filter: hue-rotate(0deg) brightness(1); } 50% { filter: hue-rotate(30deg) brightness(1.2); } 100% { filter: hue-rotate(0deg) brightness(1); }';

      // New exit effects
      case SlideEffect.flyOutLeft:
        return 'from { transform: translateX(0); opacity: 1; } to { transform: translateX(-150%); opacity: 0; }';
      case SlideEffect.flyOutRight:
        return 'from { transform: translateX(0); opacity: 1; } to { transform: translateX(150%); opacity: 0; }';
      case SlideEffect.disappear:
        return 'from { opacity: 1; } to { opacity: 0; }';

      // Motion path effects
      case SlideEffect.arc:
        return 'from { transform: translateX(-50%) translateY(50%); opacity: 0; } 50% { transform: translateX(0) translateY(-20%); opacity: 1; } to { transform: translateX(50%) translateY(50%); opacity: 1; }';
      case SlideEffect.customPath:
        return 'from { transform: translate(-30%, 30%); opacity: 0; } 33% { transform: translate(20%, -10%); opacity: 1; } 66% { transform: translate(-10%, 20%); opacity: 1; } to { transform: translate(0, 0); opacity: 1; }';

      case SlideEffect.dissolve:
        return '0% { opacity: 0; } 20% { opacity: 0.3; } 40% { opacity: 0.15; } 60% { opacity: 0.6; } 80% { opacity: 0.8; } 100% { opacity: 1; }';
      case SlideEffect.coverLeft:
        return 'from { transform: translateX(100%); box-shadow: -40px 0 80px rgba(0, 0, 0, 0.45); } to { transform: translateX(0); box-shadow: -40px 0 80px rgba(0, 0, 0, 0); }';
      case SlideEffect.coverRight:
        return 'from { transform: translateX(-100%); box-shadow: 40px 0 80px rgba(0, 0, 0, 0.45); } to { transform: translateX(0); box-shadow: 40px 0 80px rgba(0, 0, 0, 0); }';
      case SlideEffect.coverUp:
        return 'from { transform: translateY(100%); box-shadow: 0 -40px 80px rgba(0, 0, 0, 0.45); } to { transform: translateY(0); box-shadow: 0 -40px 80px rgba(0, 0, 0, 0); }';
      case SlideEffect.coverDown:
        return 'from { transform: translateY(-100%); box-shadow: 0 40px 80px rgba(0, 0, 0, 0.45); } to { transform: translateY(0); box-shadow: 0 40px 80px rgba(0, 0, 0, 0); }';
      case SlideEffect.uncoverLeft:
        return 'from { clip-path: inset(0 0 0 100%); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.uncoverRight:
        return 'from { clip-path: inset(0 100% 0 0); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.uncoverUp:
        return 'from { clip-path: inset(100% 0 0 0); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.uncoverDown:
        return 'from { clip-path: inset(0 0 100% 0); } to { clip-path: inset(0 0 0 0); }';
      case SlideEffect.curtain:
        return 'from { transform: scaleY(0.04); opacity: 0.6; } 60% { transform: scaleY(1); opacity: 1; } to { transform: scaleY(1); opacity: 1; }';
      case SlideEffect.cedar:
        return 'from { clip-path: polygon(0 0, 0 0, 0 100%); } to { clip-path: polygon(0 0, 300% 0, 0 300%); }';
      case SlideEffect.pageCurl:
        return 'from { transform: perspective(1200px) rotateY(-100deg); transform-origin: right center; opacity: 0.3; } to { transform: perspective(1200px) rotateY(0deg); transform-origin: right center; opacity: 1; }';
      case SlideEffect.ripple:
        return '0% { transform: scale(0.6); opacity: 0; filter: blur(8px); } 60% { transform: scale(1.04); opacity: 1; filter: blur(1px); } 100% { transform: scale(1); filter: blur(0); }';
      case SlideEffect.vortex:
        return '0% { transform: rotate(-180deg) scale(2.2); opacity: 0; } 60% { transform: rotate(20deg) scale(0.92); opacity: 1; } 100% { transform: rotate(0deg) scale(1); opacity: 1; }';
      case SlideEffect.shred:
        return '0% { clip-path: inset(0 0 100% 0); transform: translateX(-3%); } 30% { clip-path: inset(0 0 60% 0); } 60% { clip-path: inset(0 0 25% 0); transform: translateX(2%); } 100% { clip-path: inset(0 0 0 0); transform: translateX(0); }';
      case SlideEffect.diamond:
        return 'from { clip-path: polygon(50% 50%, 50% 50%, 50% 50%, 50% 50%); } to { clip-path: polygon(50% -100%, -100% 50%, 50% 200%, 200% 50%); }';
      case SlideEffect.wedge:
        return 'from { clip-path: polygon(50% 0, 50% 0, 50% 0); } to { clip-path: polygon(0 0, 100% 0, 50% 200%); }';
      case SlideEffect.newsflash:
        return '0% { opacity: 0; filter: brightness(3) blur(6px); } 35% { opacity: 1; filter: brightness(2.2) blur(2px); } 60% { filter: brightness(0.7) blur(0); } 100% { filter: brightness(1); }';
      case SlideEffect.ferris:
        return '0% { transform: rotate(-360deg) scale(0.3); opacity: 0; } 70% { opacity: 1; } 100% { transform: rotate(0deg) scale(1); opacity: 1; }';
      case SlideEffect.flip:
        return 'from { transform: perspective(1000px) rotateX(90deg) scale(0.8); opacity: 0.3; } to { transform: perspective(1000px) rotateX(0deg) scale(1); opacity: 1; }';
      case SlideEffect.gallery:
        return 'from { transform: translateX(60%) scale(0.9); opacity: 0; } to { transform: translateX(0) scale(1); opacity: 1; }';
      case SlideEffect.honeycomb:
        return 'from { clip-path: polygon(50% 46%, 54% 48%, 54% 52%, 50% 54%, 46% 52%, 46% 48%); } to { clip-path: polygon(50% -150%, 250% 0%, 250% 100%, 50% 250%, -150% 100%, -150% 0%); }';
      case SlideEffect.invert:
        return '0% { filter: invert(1); opacity: 0.4; } 50% { filter: invert(0) brightness(1.4); } 100% { filter: invert(0); opacity: 1; }';
      case SlideEffect.orbit:
        return '0% { transform: translateX(-80%) rotate(-45deg) scale(0.7); opacity: 0; } 60% { transform: translateX(8%) rotate(6deg) scale(1.02); opacity: 1; } 100% { transform: translateX(0) rotate(0deg) scale(1); opacity: 1; }';
      case SlideEffect.origami:
        return 'from { transform: perspective(900px) rotate3d(1, 1, 0, 90deg); opacity: 0.2; } to { transform: perspective(900px) rotate3d(1, 1, 0, 0deg); opacity: 1; }';
      case SlideEffect.reveal:
        return 'from { clip-path: inset(0 100% 0 0); transform: scaleX(1.02); } to { clip-path: inset(0 0 0 0); transform: scaleX(1); }';

      default:
        return 'from { opacity: 0; } to { opacity: 1; }';
    }
  }

  static String _easingForEffect(SlideEffect effect) {
    return switch (effect) {
      SlideEffect.pageCurl ||
      SlideEffect.flip ||
      SlideEffect.origami =>
        'cubic-bezier(0.22, 1, 0.36, 1)',
      SlideEffect.vortex ||
      SlideEffect.ferris ||
      SlideEffect.orbit ||
      SlideEffect.ripple ||
      SlideEffect.newsflash ||
      SlideEffect.invert =>
        'cubic-bezier(0.34, 1.56, 0.64, 1)',
      SlideEffect.dissolve => 'steps(6, end)',
      _ => 'ease',
    };
  }

  static String _classNameForEffect(SlideEffect effect) {
    return effect.name;
  }

  /// Get effect category for UI grouping.
  static String getEffectCategory(SlideEffect effect) {
    switch (effect) {
      case SlideEffect.none:
        return 'None';
      case SlideEffect.fade:
      case SlideEffect.pushLeft:
      case SlideEffect.pushRight:
      case SlideEffect.pushUp:
      case SlideEffect.pushDown:
      case SlideEffect.wipe:
      case SlideEffect.splitIn:
      case SlideEffect.splitOut:
      case SlideEffect.randomBar:
      case SlideEffect.checkerboard:
      case SlideEffect.blinds:
      case SlideEffect.clock:
      case SlideEffect.zoom:
        return 'Basic';
      case SlideEffect.flyInLeft:
      case SlideEffect.flyInRight:
      case SlideEffect.flyInTop:
      case SlideEffect.flyInBottom:
      case SlideEffect.appear:
      case SlideEffect.basicZoom:
      case SlideEffect.swivel:
      case SlideEffect.boomerang:
        return 'Entrance';
      case SlideEffect.pulse:
      case SlideEffect.growShrink:
      case SlideEffect.spin:
      case SlideEffect.teeter:
      case SlideEffect.flicker:
      case SlideEffect.colorPulse:
        return 'Emphasis';
      case SlideEffect.flyOutLeft:
      case SlideEffect.flyOutRight:
      case SlideEffect.disappear:
        return 'Exit';      case SlideEffect.arc:
      case SlideEffect.customPath:
        return 'Motion Path';
      case SlideEffect.dissolve:
      case SlideEffect.coverLeft:
      case SlideEffect.coverRight:
      case SlideEffect.coverUp:
      case SlideEffect.coverDown:
      case SlideEffect.uncoverLeft:
      case SlideEffect.uncoverRight:
      case SlideEffect.uncoverUp:
      case SlideEffect.uncoverDown:
      case SlideEffect.curtain:
      case SlideEffect.cedar:
      case SlideEffect.pageCurl:
      case SlideEffect.ripple:
      case SlideEffect.vortex:
      case SlideEffect.shred:
      case SlideEffect.diamond:
      case SlideEffect.wedge:
      case SlideEffect.newsflash:
      case SlideEffect.ferris:
      case SlideEffect.flip:
      case SlideEffect.gallery:
      case SlideEffect.honeycomb:
      case SlideEffect.invert:
      case SlideEffect.orbit:
      case SlideEffect.origami:
      case SlideEffect.reveal:
        return 'Track 33';
    }


  }

  /// Get icon for effect category.
  static String getCategoryIcon(String category) {
    switch (category) {
      case 'Entrance':
        return '🟢';
      case 'Emphasis':
        return '🟡';
      case 'Exit':
        return '🔴';
      case 'Motion Path':
        return '🔵';
      default:
        return '⚪';
    }
  }

  /// Get effects filtered by category.
  static List<SlideEffect> getEffectsByCategory(String category) {
    return SlideEffect.values
        .where((e) => getEffectCategory(e) == category)
        .toList();
  }

  /// Get all categories.
  static List<String> get categories => [
        'Basic',
        'Entrance',
        'Emphasis',
        'Exit',
        'Motion Path',
      ];

  /// Convert SlideEffect to PPTX transition XML type name.
  static String toPptxTransitionType(SlideEffect effect) {
    switch (effect) {
      case SlideEffect.fade:
        return 'fade';
      case SlideEffect.pushLeft:
      case SlideEffect.pushRight:
      case SlideEffect.pushUp:
      case SlideEffect.pushDown:
        return 'push';
      case SlideEffect.wipe:
        return 'wipe';
      case SlideEffect.splitIn:
      case SlideEffect.splitOut:
        return 'split';
      case SlideEffect.randomBar:
        return 'randomBar';
      case SlideEffect.checkerboard:
        return 'checkerboard';
      case SlideEffect.blinds:
        return 'blinds';
      case SlideEffect.clock:
        return 'clock';
      case SlideEffect.dissolve:
        return 'dissolve';
      case SlideEffect.zoom:
        return 'zoom';
      // New effects map to closest PPTX equivalent
      case SlideEffect.flyInLeft:
      case SlideEffect.flyInRight:
      case SlideEffect.flyInTop:
      case SlideEffect.flyInBottom:
        return 'fly';
      case SlideEffect.appear:
      case SlideEffect.growShrink:
        return 'appear';
      case SlideEffect.swivel:
      case SlideEffect.spin:
        return 'rotate';
      case SlideEffect.pulse:
      case SlideEffect.teeter:
      case SlideEffect.flicker:
      case SlideEffect.colorPulse:
        return 'fade';
      case SlideEffect.disappear:
      case SlideEffect.flyOutLeft:
      case SlideEffect.flyOutRight:
        return 'fly';
      default:
        return 'fade';
    }
  }

  static bool degradesOnPptxExport(SlideEffect effect) =>
      effect != SlideEffect.none &&
      effect != SlideEffect.fade &&
      toPptxTransitionType(effect) == 'fade';
}
