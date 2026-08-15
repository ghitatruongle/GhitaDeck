import '../models/object_animation.dart';

/// Builds the OOXML `<p:timing>` tree for a slide's object animations
/// (Track 32, FEAT 43-export).
///
/// The generated tree follows the ISO/IEC 29500 PresentationML timing model:
///
/// ```xml
/// <p:timing><p:tnLst><p:par><p:cTn nodeType="tmRoot" ...>
///   <p:childTnLst><p:seq concurrent="1" nextAc="seek">
///     <p:cTn nodeType="mainSeq" ...><p:childTnLst>… behaviours …</p:childTnLst></p:cTn>
///     <p:prevCondLst>…</p:prevCondLst><p:nextCondLst>…</p:nextCondLst>
///   </p:seq></p:childTnLst>
/// </p:cTn></p:par></p:tnLst></p:timing>
/// ```
///
/// Effects that cannot be mapped to a valid OOXML behaviour are skipped and
/// reported through [warnings] so the export dialog can surface them
/// (Track 33, OPT 50 style fallback).
/// Mutable cTn id allocator so every timing node gets a unique positive id.
class _IdCounter {
  int _next;
  _IdCounter(this._next);
  int call() => _next++;
}

class AnimationOoxml {
  AnimationOoxml._();

  /// Effects PowerPoint understands natively (preset id / behaviour).
  static const Map<AnimationEffect, ({int preset, String kind})> _preset = {
    AnimationEffect.fadeIn: (preset: 10, kind: 'entr'),
    AnimationEffect.flyIn: (preset: 48, kind: 'entr'),
    AnimationEffect.zoomIn: (preset: 22, kind: 'entr'),
    AnimationEffect.wipeIn: (preset: 32, kind: 'entr'),
    AnimationEffect.bounceIn: (preset: 33, kind: 'entr'),
    AnimationEffect.pulse: (preset: 21, kind: 'emph'),
    AnimationEffect.spin: (preset: 15, kind: 'emph'),
    AnimationEffect.growShrink: (preset: 8, kind: 'emph'),
    AnimationEffect.teeter: (preset: 7, kind: 'emph'),
    AnimationEffect.colorPulse: (preset: 10, kind: 'emph'),
    AnimationEffect.fadeOut: (preset: 11, kind: 'exit'),
    AnimationEffect.flyOut: (preset: 49, kind: 'exit'),
    AnimationEffect.zoomOut: (preset: 23, kind: 'exit'),
  };

  /// Build the timing XML for [animations].
  ///
  /// [spidMap] maps the app's shape ids ('sh_x' / 'ft_x') to the numeric
  /// `<p:cNvPr id>` used inside the slide's spTree.
  static ({String xml, List<String> warnings}) buildTimingXml(
    List<ObjectAnimation> animations, {
    required Map<String, int> spidMap,
  }) {
    if (animations.isEmpty) return (xml: '', warnings: const []);
    final warnings = <String>[];

    final body = StringBuffer();
    var ctnId = 100;

    for (final a in animations) {
      final spid = spidMap[a.shapeId];
      if (spid == null) {
        warnings.add('Shape "${a.shapeId}" is not exported — animation skipped');
        continue;
      }
      final durMs = (a.duration * 1000).round();
      final delayMs = (a.delay * 1000).round();
      final repeatStr = a.repeat == -1 ? 'indefinite' : '${a.repeat + 1}';

      final nodeType = switch (a.start) {
        AnimationStart.onClick => 'clickEffect',
        AnimationStart.withPrevious => 'withEffect',
        AnimationStart.afterPrevious => 'afterEffect',
      };
      final condDelay = a.start == AnimationStart.afterPrevious
          ? 'indefinite'
          : '$delayMs';
      final triggerCond = a.triggerShapeId != null &&
              spidMap[a.triggerShapeId] != null
          ? '<p:tgtEl><p:spTgt spid="${spidMap[a.triggerShapeId]}"/></p:tgtEl>'
          : '';

      final preset = _preset[a.effect];
      final behaviour = _behaviourXml(a, spid, durMs, repeatStr, _IdCounter(ctnId));
      ctnId += 100; // keep the outer ids far apart from behaviour ids
      final presetClass = switch (a.group) {
        AnimationGroup.entrance => 'entr',
        AnimationGroup.emphasis => 'emph',
        AnimationGroup.exit => 'exit',
        AnimationGroup.motion => 'motion',
      };

      body.write('''
                <p:par>
                  <p:cTn id="${ctnId++}" fill="hold">
                    <p:stCondLst><p:cond delay="$condDelay"$triggerCond/></p:stCondLst>
                    <p:childTnLst>
                      <p:par>
                        <p:cTn id="${ctnId++}" presetID="${preset?.preset ?? 0}" presetClass="$presetClass" presetSubtype="0" fill="hold" nodeType="$nodeType">
                          <p:stCondLst><p:cond delay="0"/></p:stCondLst>
                          <p:childTnLst>
                            $behaviour
                          </p:childTnLst>
                        </p:cTn>
                      </p:par>
                    </p:childTnLst>
                  </p:cTn>
                </p:par>
''');
    }

    final xml = '''
  <p:timing>
    <p:tnLst>
      <p:par>
        <p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot">
          <p:childTnLst>
            <p:seq concurrent="1" nextAc="seek">
              <p:cTn id="2" dur="indefinite" nodeType="mainSeq">
                <p:childTnLst>
$body                </p:childTnLst>
              </p:cTn>
              <p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>
              <p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>
            </p:seq>
          </p:childTnLst>
        </p:cTn>
      </p:par>
    </p:tnLst>
  </p:timing>
''';
    return (xml: xml, warnings: warnings);
  }

  /// The behaviour element inside one animation's childTnLst: a `p:set`
  /// visibility toggle (entrance/exit) plus the effect behaviour.
  /// [nextId] is the mutable cTn id counter — every node gets a unique id
  /// so PowerPoint never repairs the timing tree.
  static String _behaviourXml(
    ObjectAnimation a,
    int spid,
    int durMs,
    String repeatStr,
    _IdCounter nextId,
  ) {
    final b = StringBuffer();
    final tgt = '<p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl>';
    final durAttr = 'dur="$durMs"';
    final repeatAttr = ' repeatCount="$repeatStr"';

    // Entrance/exit first toggle visibility so the shape is hidden until the
    // effect fires (PowerPoint behaviour).
    if (a.group == AnimationGroup.entrance || a.group == AnimationGroup.exit) {
      final visible = a.group == AnimationGroup.entrance ? 'visible' : 'hidden';
      b.write('''
                          <p:set>
                            <p:cBhvr>
                              <p:cTn id="${nextId()}" dur="1" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst></p:cTn>
                              $tgt
                              <p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst>
                            </p:cBhvr>
                            <p:to><p:strVal val="$visible"/></p:to>
                          </p:set>
''');
    }

    switch (a.group) {
      case AnimationGroup.entrance:
        final filter = a.effect == AnimationEffect.flyIn ? 'fly' : 'fade';
        final direction = switch (a.direction) {
          'right' => ' dir="rtl"',
          'top' => ' dir="up"',
          'bottom' => ' dir="down"',
          _ => '',
        };
        b.write('''
                          <p:animEffect transition="in" filter="$filter"$direction>
                            <p:cBhvr>
                              <p:cTn id="${nextId()}" $durAttr$repeatAttr/>
                              $tgt
                            </p:cBhvr>
                          </p:animEffect>
''');
      case AnimationGroup.emphasis:
        switch (a.effect) {
          case AnimationEffect.spin:
            b.write('''
                          <p:animRot by="360000">
                            <p:cBhvr><p:cTn id="${nextId()}" $durAttr$repeatAttr/>$tgt</p:cBhvr>
                          </p:animRot>
''');
          case AnimationEffect.growShrink:
            b.write('''
                          <p:animScale>
                            <p:cBhvr><p:cTn id="${nextId()}" $durAttr$repeatAttr/>$tgt</p:cBhvr>
                            <p:by x="50000" y="50000"/>
                          </p:animScale>
''');
          case AnimationEffect.colorPulse:
            b.write('''
                          <p:animClr clrSpc="rgb" dir="1">
                            <p:cBhvr><p:cTn id="${nextId()}" $durAttr$repeatAttr/>$tgt</p:cBhvr>
                            <p:by><a:srgbClr val="FFD400"/></p:by>
                          </p:animClr>
''');
          default:
            // pulse/teeter have no direct behaviour — scale fallback.
            b.write('''
                          <p:animScale>
                            <p:cBhvr><p:cTn id="${nextId()}" $durAttr$repeatAttr/>$tgt</p:cBhvr>
                            <p:by x="80000" y="80000"/>
                          </p:animScale>
''');
        }
      case AnimationGroup.exit:
        final filter = a.effect == AnimationEffect.flyOut ? 'fly' : 'fade';
        final direction = switch (a.direction) {
          'right' => ' dir="rtl"',
          'top' => ' dir="up"',
          'bottom' => ' dir="down"',
          _ => '',
        };
        b.write('''
                          <p:animEffect transition="out" filter="$filter"$direction>
                            <p:cBhvr>
                              <p:cTn id="${nextId()}" $durAttr$repeatAttr/>
                              $tgt
                            </p:cBhvr>
                          </p:animEffect>
''');
      case AnimationGroup.motion:
        final points = a.pathPoints ?? const [];
        if (points.length >= 2) {
          final pathBuf = StringBuffer();
          for (var i = 0; i < points.length; i++) {
            final x = (points[i].x * 100000).round();
            final y = (points[i].y * 100000).round();
            pathBuf.write('<a:pt x="$x" y="$y"/>');
          }
          b.write('''
                          <p:animMotion origin="layout" path="m">
                            <p:cBhvr><p:cTn id="${nextId()}" $durAttr$repeatAttr/>$tgt</p:cBhvr>
                            <p:path><a:ptLst>$pathBuf</a:ptLst></p:path>
                          </p:animMotion>
''');
        }
    }
    return b.toString();
  }
}
