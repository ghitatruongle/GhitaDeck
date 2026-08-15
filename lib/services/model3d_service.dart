/// 3D model embed helpers (Track 14, FEAT 10).
///
/// Slides carry `<div data-model3d='{json}'>` blocks; the PPTX exporter
/// turns them into the Office 2017 `am3d:model3d` graphicFrame inside an
/// mc:AlternateContent (the exact structure PowerPoint writes — validated
/// against a Microsoft-generated golden deck AND real PowerPoint COM), the
/// HTML/PDF/app previews use the self-generated poster SVG.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/model3d_item.dart';

class Model3DService {
  Model3DService._();

  static final RegExp _dataModel3dRegExp = RegExp(
    r"""data-model3d=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  /// Find every `<div data-model3d='…'>` block in [html], in document order.
  static List<Model3DData> modelsIn(String html) {
    final models = <Model3DData>[];
    for (final match in _dataModel3dRegExp.allMatches(html)) {
      // group(1) is the quote character; group(2) carries the JSON.
      final model = Model3DData.fromJson(match.group(2)!);
      if (model.src.isNotEmpty) {
        models.add(model);
      }
    }
    return models;
  }

  /// Serialize a [model] for use inside a single-quoted HTML attribute.
  static String escapeAttribute(Model3DData model) =>
      model.toJson().replaceAll("'", '&#39;');

  /// Build the `<div data-model3d>` block inserted into the slide HTML.
  static String model3dMarkup(Model3DData model) =>
      '<div data-model3d=\'${escapeAttribute(model)}\'></div>';

  /// Replace the [index]-th model block in [html] with new markup.
  static String replaceModel3dAt(String html, int index, Model3DData model) {
    final tagPattern = RegExp(
      r"""<div\b[^>]*data-model3d=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = tagPattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, model3dMarkup(model));
  }

  /// Number of model blocks in [html].
  static int modelCount(String html) =>
      _dataModel3dRegExp.allMatches(html).length;

  // ---- Poster SVG (self-generated, no external renderer) ----------------

  /// Stylized 3D-cube poster with the model name — used by the app preview,
  /// the HTML deck and (rasterized at export time) PowerPoint.
  static String renderPosterSvg(Model3DData model) {
    final name = _xml(model.name.isEmpty ? '3D Model' : model.name);
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 240" '
        'width="400" height="240">'
        '<rect width="400" height="240" fill="#1b2a4a"/>'
        '<polygon points="200,35 350,110 200,185 50,110" '
        'fill="#3f7fd4" stroke="#9ec3ff" stroke-width="3"/>'
        '<polygon points="50,110 200,185 200,232 50,157" '
        'fill="#2a5fa8" stroke="#9ec3ff" stroke-width="2"/>'
        '<polygon points="350,110 200,185 200,232 350,157" '
        'fill="#346fbe" stroke="#9ec3ff" stroke-width="2"/>'
        '<line x1="50" y1="110" x2="50" y2="157" stroke="#9ec3ff" stroke-width="2"/>'
        '<line x1="350" y1="110" x2="350" y2="157" stroke="#9ec3ff" stroke-width="2"/>'
        '<text x="200" y="126" fill="#ffffff" font-size="20" '
        'text-anchor="middle" font-family="Segoe UI, sans-serif">$name</text>'
        '<text x="200" y="150" fill="#9ec3ff" font-size="13" '
        'text-anchor="middle" font-family="Segoe UI, sans-serif">3D</text>'
        '</svg>';
  }

  /// HTML fragment shown in the exported deck: the poster + a note that the
  /// real model plays in PowerPoint (the GLB is not embedded in HTML).
  static String renderHtmlPoster(Model3DData model, {String note = ''}) {
    final n = _xml(note.isEmpty ? '3D Model' : note);
    return '<div class="ghita-model3d">'
        '${renderPosterSvg(model)}'
        '<div class="ghita-model3d-note">$n</div>'
        '</div>';
  }

  /// Rasterized poster (PNG) for the PPTX `am3d:raster` blip — drawn with
  /// the same geometry as the SVG poster, no external renderer needed.
  static Uint8List renderPosterPng(Model3DData model) {
    final image = img.Image(width: 400, height: 240);
    img.fill(image, color: img.ColorRgb8(27, 42, 74));
    img.fillPolygon(
      image,
      vertices: [
        img.Point(200, 35),
        img.Point(350, 110),
        img.Point(200, 185),
        img.Point(50, 110),
      ],
      color: img.ColorRgb8(63, 127, 212),
    );
    img.fillPolygon(
      image,
      vertices: [
        img.Point(50, 110),
        img.Point(200, 185),
        img.Point(200, 232),
        img.Point(50, 157),
      ],
      color: img.ColorRgb8(42, 95, 168),
    );
    img.fillPolygon(
      image,
      vertices: [
        img.Point(350, 110),
        img.Point(200, 185),
        img.Point(200, 232),
        img.Point(350, 157),
      ],
      color: img.ColorRgb8(52, 111, 190),
    );
    img.drawLine(image,
        x1: 50, y1: 110, x2: 50, y2: 157, color: img.ColorRgb8(158, 195, 255));
    img.drawLine(image,
        x1: 350, y1: 110, x2: 350, y2: 157,
        color: img.ColorRgb8(158, 195, 255));
    return Uint8List.fromList(img.encodePng(image));
  }

  // ---- PPTX XML (validated against real PowerPoint) ---------------------

  /// The `<mc:AlternateContent>` block for one model: `mc:Choice` carries
  /// the `am3d:model3d` graphicFrame (poster raster + camera + transform +
  /// lights), `mc:Fallback` a plain `p:pic` of the poster for viewers
  /// without 3D support.
  ///
  /// When [rotate] is true the a3danim extension (plays the model's first
  /// embedded animation indefinitely) is added — the exact structure
  /// Microsoft's AnimatedModel3DExample writes.
  static String renderPptxModel3dXml({
    required int shapeId,
    required int fallbackShapeId,
    required String name,
    required String glbRid,
    required String posterRid,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
    required bool rotate,
    required String creationId,
  }) {
    final b = StringBuffer()
      ..write('<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">\n')
      ..write('  <mc:Choice xmlns:am3d="http://schemas.microsoft.com/office/drawing/2017/model3d" Requires="am3d">\n')
      ..write('    <p:graphicFrame>\n')
      ..write('      <p:nvGraphicFramePr>')
      ..write('<p:cNvPr id="$shapeId" name="$name" descr="$name">')
      ..write('<a:extLst><a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}">')
      ..write('<a16:creationId xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" id="$creationId"/>')
      ..write('</a:ext></a:extLst>')
      ..write('</p:cNvPr>')
      ..write('<p:cNvGraphicFramePr/>')
      ..write('<p:nvPr><p:extLst><p:ext uri="{D42A27DB-BD31-4B8C-83A1-F6EECF244321}">')
      ..write('<p14:modId xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" val="3636546711"/>')
      ..write('</p:ext></p:extLst></p:nvPr>')
      ..write('</p:nvGraphicFramePr>\n')
      ..write('      <p:xfrm><a:off x="$offX" y="$offY"/><a:ext cx="$extCx" cy="$extCy"/></p:xfrm>\n')
      ..write('      <a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/drawing/2017/model3d">\n')
      ..write('        <am3d:model3d r:embed="$glbRid">\n')
      ..write('          <am3d:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></am3d:spPr>\n')
      ..write('          <am3d:camera>\n')
      ..write('            <am3d:pos x="0" y="0" z="67740115"/>\n')
      ..write('            <am3d:up dx="0" dy="36000000" dz="0"/>\n')
      ..write('            <am3d:lookAt x="0" y="0" z="0"/>\n')
      ..write('            <am3d:perspective fov="2700000"/>\n')
      ..write('          </am3d:camera>\n')
      ..write('          <am3d:trans>\n')
      ..write('            <am3d:meterPerModelUnit n="30569" d="1000000"/>\n')
      ..write('            <am3d:preTrans dx="-98394" dy="-14223043" dz="-1124542"/>\n')
      ..write('            <am3d:scale><am3d:sx n="1000000" d="1000000"/>'
          '<am3d:sy n="1000000" d="1000000"/><am3d:sz n="1000000" d="1000000"/></am3d:scale>\n')
      ..write('            <am3d:rot/>\n')
      ..write('            <am3d:postTrans dx="0" dy="0" dz="0"/>\n')
      ..write('          </am3d:trans>\n')
      ..write('          <am3d:raster rName="Office3DRenderer" rVer="16.0.8326">\n')
      ..write('            <am3d:blip r:embed="$posterRid"/>\n')
      ..write('          </am3d:raster>\n')
      // The a3danim extension and the point lights are required — PowerPoint
      // rejects the file when both are missing (bisected against COM; the
      // golden always carries them). embedAnim plays animation 0; without a
      // timing entry it is inert ([rotate] controls the timeline).
      ..write('          <am3d:extLst>\n')
      ..write('            <a:ext uri="{9A65AA19-BECB-4387-8358-8AD5134E1D82}">')
      ..write('<a3danim:embedAnim animId="0">')
      ..write('<a3danim:animPr length="1899" count="indefinite"/>')
      ..write('</a3danim:embedAnim></a:ext>\n')
      ..write('            <a:ext uri="{E9DE012E-A134-456F-84FE-255F9AAD75C6}">')
      ..write('<a3danim:posterFrame animId="0"/>')
      ..write('</a:ext>\n')
      ..write('          </am3d:extLst>\n')
      ..write('          <am3d:objViewport viewportSz="5418666"/>\n')
      ..write('          <am3d:ambientLight><am3d:clr><a:scrgbClr r="50000" g="50000" b="50000"/></am3d:clr>'
          '<am3d:illuminance n="500000" d="1000000"/></am3d:ambientLight>\n')
      ..write('          <am3d:ptLight rad="0"><am3d:clr><a:scrgbClr r="100000" g="75000" b="50000"/></am3d:clr>'
          '<am3d:intensity n="9765625" d="1000000"/><am3d:pos x="21959998" y="70920001" z="16344003"/></am3d:ptLight>\n')
      ..write('          <am3d:ptLight rad="0"><am3d:clr><a:scrgbClr r="40000" g="60000" b="95000"/></am3d:clr>'
          '<am3d:intensity n="12250000" d="1000000"/><am3d:pos x="-37964106" y="51130435" z="57631972"/></am3d:ptLight>\n')
      ..write('          <am3d:ptLight rad="0"><am3d:clr><a:scrgbClr r="86837" g="72700" b="100000"/></am3d:clr>'
          '<am3d:intensity n="3125000" d="1000000"/><am3d:pos x="-37739122" y="58056624" z="-34769649"/></am3d:ptLight>\n')
      ..write('        </am3d:model3d>\n')
      ..write('      </a:graphicData></a:graphic>\n')
      ..write('    </p:graphicFrame>\n')
      ..write('  </mc:Choice>\n')
      ..write('  <mc:Fallback>\n')
      ..write('    <p:pic>\n')
      ..write('      <p:nvPicPr><p:cNvPr id="$fallbackShapeId" name="$name" descr="$name">'
          '<a:extLst><a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}">'
          '<a16:creationId id="$creationId"/></a:ext></a:extLst></p:cNvPr>'
          '<p:cNvPicPr><a:picLocks noGrp="1" noRot="1" noChangeAspect="1" noMove="1" noResize="1" noEditPoints="1" noAdjustHandles="1" noChangeArrowheads="1" noChangeShapeType="1" noCrop="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\n')
      ..write('      <p:blipFill><a:blip r:embed="$posterRid"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\n')
      ..write('      <p:spPr><a:xfrm><a:off x="$offX" y="$offY"/><a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n')
      ..write('    </p:pic>\n')
      ..write('  </mc:Fallback>\n')
      ..write('</mc:AlternateContent>');
    return b.toString();
  }

  /// One `<p:par>` timeline fragment that plays the model's embedded
  /// animation 0 indefinitely on slide entry (Microsoft's AnimatedModel3D
  /// timing, parameterised by the shape id). Empty when [rotate] is false.
  /// [idBase] offsets the timeline ids so the fragment never collides with
  /// the video/audio media timeline on the same slide.
  static String model3dTimingParXml(int spid,
      {bool rotate = false, int idBase = 100}) {
    if (!rotate) return '';
    final id = idBase;
    return '<p:par><p:cTn id="$id" dur="indefinite" restart="never" nodeType="tmRoot">'
        '<p:childTnLst><p:seq concurrent="1" nextAc="seek">'
        '<p:cTn id="${id + 1}" dur="indefinite" nodeType="mainSeq">'
        '<p:childTnLst><p:par><p:cTn id="${id + 2}" fill="hold">'
        '<p:stCondLst><p:cond delay="indefinite"/><p:cond evt="onBegin" delay="0"><p:tn val="${id + 1}"/></p:cond></p:stCondLst>'
        '<p:childTnLst><p:par><p:cTn id="${id + 3}" fill="hold">'
        '<p:stCondLst><p:cond delay="0"/></p:stCondLst>'
        '<p:childTnLst><p:par>'
        '<p:cTn id="${id + 4}" presetID="100" presetClass="emph" presetSubtype="1" repeatCount="indefinite" fill="hold" nodeType="withEffect">'
        '<p:stCondLst><p:cond delay="0"/></p:stCondLst>'
        '<p:childTnLst><p:anim calcmode="lin" valueType="num">'
        '<p:cBhvr><p:cTn id="${id + 5}" dur="1900" fill="hold"/><p:tgtEl><p:spTgt spid="$spid"/></p:tgtEl>'
        '<p:attrNameLst><p:attrName>embedded1</p:attrName></p:attrNameLst></p:cBhvr>'
        '<p:tavLst><p:tav tm="0"><p:val><p:fltVal val="0"/></p:val></p:tav>'
        '<p:tav tm="100000"><p:val><p:fltVal val="1"/></p:val></p:tav></p:tavLst>'
        '</p:anim></p:childTnLst></p:cTn>'
        '</p:par></p:childTnLst></p:cTn>'
        '</p:par></p:childTnLst></p:cTn>'
        '</p:par></p:childTnLst></p:cTn>'
        '<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>'
        '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>'
        '</p:seq></p:childTnLst></p:cTn></p:par>';
  }

  static String _xml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
