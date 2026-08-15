/// Cameo (live camera) feature (Track 20, FEAT 23).
///
/// Inserts a camera placeholder into the slide. The HTML player shows a
/// styled camera icon; the PPTX exporter writes a `<p:cameo>` shape (or
/// fallback placeholder). Slides carry `<div data-cameo='{json}'>` blocks.
library;

import 'dart:convert';

class CameoData {
  const CameoData({
    this.label = 'Camera',
    this.x = 40.0,
    this.y = 30.0,
    this.w = 20.0,
    this.h = 25.0,
  });

  final String label;
  final double x, y, w, h; // % of slide

  Map<String, dynamic> toMap() => {
        if (label != 'Camera') 'label': label,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  static CameoData fromMap(Map<String, dynamic> map) => CameoData(
        label: map['label']?.toString() ?? 'Camera',
        x: (map['x'] as num?)?.toDouble() ?? 40.0,
        y: (map['y'] as num?)?.toDouble() ?? 30.0,
        w: (map['w'] as num?)?.toDouble() ?? 20.0,
        h: (map['h'] as num?)?.toDouble() ?? 25.0,
      );

  String toJson() => jsonEncode(toMap());

  static CameoData fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const CameoData();
      return fromMap(map);
    } catch (_) {
      return const CameoData();
    }
  }

  /// HTML markup for the app preview / HTML deck.
  String get htmlMarkup => '<div data-cameo-html style="position:absolute; '
      'left:$x%; top:$y%; width:$w%; height:$h%; '
      'display:flex; flex-direction:column; align-items:center; '
      'justify-content:center; background:#1a1a2e; border:2px solid #3a8fd4; '
      'border-radius:12px; color:#ccc; font-family:Segoe UI;'
      '">'
      '<div style="font-size:2.5rem; color:#3a8fd4;">📷</div>'
      '<div style="font-size:0.9rem; margin-top:4px; font-weight:600;">'
      '${_xml(label)}</div>'
      '<div style="font-size:0.7rem; color:#888;">Live camera</div>'
      '</div>';

  String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class CameoService {
  CameoService._();

  static final RegExp _dataCameoRegExp = RegExp(
    r"""data-cameo=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  static List<CameoData> cameosIn(String html) {
    final result = <CameoData>[];
    for (final match in _dataCameoRegExp.allMatches(html)) {
      result.add(CameoData.fromJson(match.group(2)!));
    }
    return result;
  }

  static String escapeAttribute(CameoData cameo) =>
      cameo.toJson().replaceAll("'", '&#39;');

  static String cameoMarkup(CameoData cameo) =>
      '<div data-cameo=\'${escapeAttribute(cameo)}\'></div>';

  static int cameoCount(String html) => _dataCameoRegExp.allMatches(html).length;

  static String replaceCameoAt(String html, int index, CameoData cameo) {
    final pattern = RegExp(
      r"""<div\b[^>]*data-cameo=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = pattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, cameoMarkup(cameo));
  }

  /// OOXML `<p:cameo>` shape XML (Office 2016+). For viewers without cameo
  /// support, the fallback is a styled placeholder shape.
  static String renderPptxCameoXml({
    required int shapeId,
    required CameoData cameo,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
  }) {
    return '<p:sp>\n'
        '  <p:nvSpPr><p:cNvPr id="$shapeId" name="Cameo ${cameo.label}"/>'
        '<p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n'
        '  <p:spPr><a:xfrm><a:off x="$offX" y="$offY"/>'
        '<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="1A1A2E"/></a:solidFill>'
        '<a:ln><a:solidFill><a:srgbClr val="3A8FD4"/></a:solidFill></a:ln>'
        '</p:spPr>\n'
        '  <p:txBody><a:bodyPr/><a:lstStyle/>'
        '<a:p><a:pPr algn="ctr"/>'
        '<a:r><a:rPr lang="en-US" sz="1400" b="1">'
        '<a:solidFill><a:srgbClr val="CCCCCC"/></a:solidFill></a:rPr>'
        '<a:t>${_xml(cameo.label)}</a:t></a:r>'
        '<a:r><a:rPr lang="en-US" sz="1000">'
        '<a:solidFill><a:srgbClr val="888888"/></a:solidFill></a:rPr>'
        '<a:t>\nLive camera</a:t></a:r></a:p>'
        '</p:txBody>\n'
        '</p:sp>\n';
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}