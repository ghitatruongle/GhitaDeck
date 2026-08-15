import '../models/slide.dart';

/// Shared helper for effect display names.
/// Used by ribbon_toolbar, effects_screen, and editor_state.
class EffectHelpers {
  EffectHelpers._();

  static String effectName(SlideEffect effect) {
    switch (effect) {
      case SlideEffect.none: return 'None';
      case SlideEffect.fade: return 'Fade';
      case SlideEffect.pushLeft: return 'Push Left';
      case SlideEffect.pushRight: return 'Push Right';
      case SlideEffect.pushUp: return 'Push Up';
      case SlideEffect.pushDown: return 'Push Down';
      case SlideEffect.wipe: return 'Wipe';
      case SlideEffect.splitIn: return 'Split In';
      case SlideEffect.splitOut: return 'Split Out';
      case SlideEffect.randomBar: return 'Random Bars';
      case SlideEffect.checkerboard: return 'Checkerboard';
      case SlideEffect.blinds: return 'Blinds';
      case SlideEffect.clock: return 'Clock';
      case SlideEffect.zoom: return 'Zoom';
      case SlideEffect.flyInLeft: return 'Fly In Left';
      case SlideEffect.flyInRight: return 'Fly In Right';
      case SlideEffect.flyInTop: return 'Fly In Top';
      case SlideEffect.flyInBottom: return 'Fly In Bottom';
      case SlideEffect.appear: return 'Appear';
      case SlideEffect.basicZoom: return 'Basic Zoom';
      case SlideEffect.swivel: return 'Swivel';
      case SlideEffect.boomerang: return 'Boomerang';
      case SlideEffect.pulse: return 'Pulse';
      case SlideEffect.growShrink: return 'Grow/Shrink';
      case SlideEffect.spin: return 'Spin';
      case SlideEffect.teeter: return 'Teeter';
      case SlideEffect.flicker: return 'Flicker';
      case SlideEffect.colorPulse: return 'Color Pulse';
      case SlideEffect.flyOutLeft: return 'Fly Out Left';
      case SlideEffect.flyOutRight: return 'Fly Out Right';
      case SlideEffect.disappear: return 'Disappear';
      case SlideEffect.arc: return 'Arc';
      case SlideEffect.customPath: return 'Custom Path';
      case SlideEffect.dissolve: return 'Dissolve';
      case SlideEffect.coverLeft: return 'Cover Left';
      case SlideEffect.coverRight: return 'Cover Right';
      case SlideEffect.coverUp: return 'Cover Up';
      case SlideEffect.coverDown: return 'Cover Down';
      case SlideEffect.uncoverLeft: return 'Uncover Left';
      case SlideEffect.uncoverRight: return 'Uncover Right';
      case SlideEffect.uncoverUp: return 'Uncover Up';
      case SlideEffect.uncoverDown: return 'Uncover Down';
      case SlideEffect.curtain: return 'Curtain';
      case SlideEffect.cedar: return 'Cedar';
      case SlideEffect.pageCurl: return 'Page Curl';
      case SlideEffect.ripple: return 'Ripple';
      case SlideEffect.vortex: return 'Vortex';
      case SlideEffect.shred: return 'Shred';
      case SlideEffect.diamond: return 'Diamond';
      case SlideEffect.wedge: return 'Wedge';
      case SlideEffect.newsflash: return 'Newsflash';
      case SlideEffect.ferris: return 'Ferris';
      case SlideEffect.flip: return 'Flip';
      case SlideEffect.gallery: return 'Gallery';
      case SlideEffect.honeycomb: return 'Honeycomb';
      case SlideEffect.invert: return 'Invert';
      case SlideEffect.orbit: return 'Orbit';
      case SlideEffect.origami: return 'Origami';
      case SlideEffect.reveal: return 'Reveal';
    }
  }
}
