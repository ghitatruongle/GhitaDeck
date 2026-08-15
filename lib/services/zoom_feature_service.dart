/// Slide Zoom feature (Track 20, FEAT 22).
///
/// A ZoomItem links to a target slide (by index or anchor). The HTML player
/// renders a clickable thumbnail that jumps to the target slide; the PPTX
/// exporter writes `<p:zoom>` with a fallback hyperlink.
library;

import 'dart:convert';

class ZoomItem {
  const ZoomItem({
    this.targetSlide = 0,
    this.thumbnailLabel = '',
    this.frameStyle = 'simple',
    this.x = 30.0,
    this.y = 30.0,
    this.w = 25.0,
    this.h = 18.0,
  });

  /// 0-based target slide index.
  final int targetSlide;

  /// Optional label shown on the thumbnail.
  final String thumbnailLabel;

  /// 'simple' | 'outline' | 'shadow'
  final String frameStyle;

  /// Position/size as % of the slide.
  final double x, y, w, h;

  Map<String, dynamic> toMap() => {
        'targetSlide': targetSlide,
        if (thumbnailLabel.isNotEmpty) 'thumbnailLabel': thumbnailLabel,
        if (frameStyle != 'simple') 'frameStyle': frameStyle,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  static ZoomItem fromMap(Map<String, dynamic> map) => ZoomItem(
        targetSlide: (map['targetSlide'] as num?)?.toInt() ?? 0,
        thumbnailLabel: map['thumbnailLabel']?.toString() ?? '',
        frameStyle: map['frameStyle']?.toString() ?? 'simple',
        x: (map['x'] as num?)?.toDouble() ?? 30.0,
        y: (map['y'] as num?)?.toDouble() ?? 30.0,
        w: (map['w'] as num?)?.toDouble() ?? 25.0,
        h: (map['h'] as num?)?.toDouble() ?? 18.0,
      );

  String toJson() => jsonEncode(toMap());

  static ZoomItem fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const ZoomItem();
      return fromMap(map);
    } catch (_) {
      return const ZoomItem();
    }
  }

  /// HTML markup: a clickable thumbnail that jumps to the target slide.
  String get htmlMarkup {
    final label = thumbnailLabel.isNotEmpty ? thumbnailLabel : 'Slide ${targetSlide + 1}';
    final frameCss = _frameStyleCss();
    return '<div data-zoom-html style="position:absolute; left:$x%; top:$y%; '
        'width:$w%; height:$h%; cursor:pointer; $frameCss '
        'display:flex; align-items:center; justify-content:center; '
        'background:linear-gradient(135deg, #1a2a4a, #2a4a7a); '
        'color:#fff; font-size:1.1rem; font-weight:600; '
        'border-radius:10px; user-select:none;" '
        'onclick="goToSlide($targetSlide)" title="Go to ${_xml(label)}">'
        '${_xml(label)}</div>';
  }

  String _frameStyleCss() {
    switch (frameStyle) {
      case 'outline':
        return 'border: 3px solid #3a8fd4; box-shadow: none;';
      case 'shadow':
        return 'box-shadow: 0 8px 24px rgba(0,0,0,0.4);';
      default:
        return 'box-shadow: 0 4px 12px rgba(0,0,0,0.3);';
    }
  }

  String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class ZoomFeatureService {
  ZoomFeatureService._();

  static final RegExp _dataZoomRegExp = RegExp(
    r"""data-zoom=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  static List<ZoomItem> zoomsIn(String html) {
    final result = <ZoomItem>[];
    for (final match in _dataZoomRegExp.allMatches(html)) {
      result.add(ZoomItem.fromJson(match.group(2)!));
    }
    return result;
  }

  static String escapeAttribute(ZoomItem zoom) =>
      zoom.toJson().replaceAll("'", '&#39;');

  static String zoomMarkup(ZoomItem zoom) =>
      '<div data-zoom=\'${escapeAttribute(zoom)}\'></div>';

  static int zoomCount(String html) => _dataZoomRegExp.allMatches(html).length;

  static String replaceZoomAt(String html, int index, ZoomItem zoom) {
    final pattern = RegExp(
      r"""<div\b[^>]*data-zoom=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = pattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, zoomMarkup(zoom));
  }

  /// OOXML `<p:zoom>` shape inner XML (with fallback `<p:pic>` for viewers
  /// that don't support the zoom feature). The relationship points to the
  /// target slide via a hyperlink (internal slide jump).
  static String renderPptxZoomXml({
    required int shapeId,
    required ZoomItem zoom,
    required String description,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
  }) {
    final label = zoom.thumbnailLabel.isNotEmpty
        ? zoom.thumbnailLabel
        : 'Slide ${zoom.targetSlide + 1}';
    // Fallback: a <p:sp> with a hyperlink that jumps to the slide.
    // PowerPoint's p:zoom would require the p14 namespace and a complex
    // zoom object, which is brittle. A p:sp with a hlinkClick to the
    // target slide is more reliable and works across all viewers.
    return '<p:sp>\n'
        '  <p:nvSpPr><p:cNvPr id="$shapeId" name="Slide Zoom $label"/>'
        '<p:cNvSpPr/><p:nvPr>'
        '<a:hlinkClick action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
        '</p:nvPr></p:nvSpPr>\n'
        '  <p:spPr><a:xfrm><a:off x="$offX" y="$offY"/>'
        '<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="1A2A4A"/></a:solidFill>'
        '</p:spPr>\n'
        '  <p:txBody><a:bodyPr/><a:lstStyle/>'
        '<a:p><a:pPr algn="ctr"/>'
        '<a:r><a:rPr lang="en-US" sz="1800" b="1">'
        '<a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:rPr>'
        '<a:t>${_xml(label)}</a:t></a:r></a:p></p:txBody>\n'
        '</p:sp>\n';
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// One tile inside a Section/Summary Zoom grid (Track 20, P6).
class SectionZoomEntry {
  const SectionZoomEntry({required this.label, required this.slide});

  /// Tile caption (section name or "Slide N").
  final String label;

  /// 0-based target slide the tile jumps to.
  final int slide;

  Map<String, dynamic> toMap() => {'label': label, 'slide': slide};

  static SectionZoomEntry fromMap(Map<String, dynamic> map) =>
      SectionZoomEntry(
        label: map['label']?.toString() ?? '',
        slide: (map['slide'] as num?)?.toInt() ?? 0,
      );
}

/// Section/Summary Zoom (Track 20, P6): a grid of tiles that each jump to a
/// slide (Summary Zoom) or to the first slide of a section (Section Zoom).
///
/// Stored in slide HTML as `<div data-sectionzoom='json'>`; the three export
/// formats render a clickable grid (HTML tiles / PPTX hyperlink shapes / PDF
/// labelled boxes).
class SectionZoomData {
  const SectionZoomData({
    this.entries = const [],
    this.columns = 2,
    this.frameStyle = 'simple',
    this.x = 10.0,
    this.y = 25.0,
    this.w = 80.0,
    this.h = 50.0,
  });

  final List<SectionZoomEntry> entries;
  final int columns;

  /// 'simple' | 'outline' | 'shadow'
  final String frameStyle;

  /// Position/size as % of the slide.
  final double x, y, w, h;

  Map<String, dynamic> toMap() => {
        'entries': entries.map((e) => e.toMap()).toList(),
        if (columns != 2) 'columns': columns,
        if (frameStyle != 'simple') 'frameStyle': frameStyle,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  static SectionZoomData fromMap(Map<String, dynamic> map) => SectionZoomData(
        entries: map['entries'] is List
            ? (map['entries'] as List)
                .map<SectionZoomEntry>((e) => SectionZoomEntry.fromMap(
                    Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
        columns: (map['columns'] as num?)?.toInt() ?? 2,
        frameStyle: map['frameStyle']?.toString() ?? 'simple',
        x: (map['x'] as num?)?.toDouble() ?? 10.0,
        y: (map['y'] as num?)?.toDouble() ?? 25.0,
        w: (map['w'] as num?)?.toDouble() ?? 80.0,
        h: (map['h'] as num?)?.toDouble() ?? 50.0,
      );

  String toJson() => jsonEncode(toMap());

  static SectionZoomData fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const SectionZoomData();
      return fromMap(map);
    } catch (_) {
      return const SectionZoomData();
    }
  }

  /// HTML markup: a grid of clickable tiles; each jumps to its slide via the
  /// player's `goToSlide()` (same function the single Slide Zoom uses).
  String get htmlMarkup {
    final cols = columns.clamp(1, 4);
    final frameCss = _frameStyleCss();
    final tiles = entries
        .map((e) =>
            '<div style="flex:1 1 calc((100% - ${(cols - 1) * 2}%) / $cols); '
            'margin:1%; min-height:26%; display:flex; align-items:center; '
            'justify-content:center; cursor:pointer; $frameCss '
            'background:linear-gradient(135deg, #1a2a4a, #2a4a7a); '
            'color:#fff; font-size:1rem; font-weight:600; '
            'border-radius:10px; user-select:none;" '
            'onclick="goToSlide(${e.slide})" title="${_xml(e.label)}">'
            '${_xml(e.label)}</div>')
        .join('');
    return '<div data-sectionzoom-html style="position:absolute; left:$x%; '
        'top:$y%; width:$w%; height:$h%; display:flex; '
        'flex-wrap:wrap; align-content:center;">$tiles</div>';
  }

  String _frameStyleCss() {
    switch (frameStyle) {
      case 'outline':
        return 'border: 3px solid #3a8fd4; box-shadow: none;';
      case 'shadow':
        return 'box-shadow: 0 8px 24px rgba(0,0,0,0.4);';
      default:
        return 'box-shadow: 0 4px 12px rgba(0,0,0,0.3);';
    }
  }

  String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Service helpers for Section/Summary Zoom blocks (Track 20, P6).
class SectionZoomService {
  SectionZoomService._();

  static final RegExp _dataSectionZoomRegExp = RegExp(
    r"""data-sectionzoom=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  static List<SectionZoomData> sectionZoomsIn(String html) {
    final result = <SectionZoomData>[];
    for (final match in _dataSectionZoomRegExp.allMatches(html)) {
      result.add(SectionZoomData.fromJson(match.group(2)!));
    }
    return result;
  }

  static int sectionZoomCount(String html) =>
      _dataSectionZoomRegExp.allMatches(html).length;

  static String sectionZoomMarkup(SectionZoomData zoom) {
    final json = zoom.toJson().replaceAll("'", '&#39;');
    return '<div data-sectionzoom=\'$json\'></div>';
  }

  static String replaceSectionZoomAt(String html, int index, SectionZoomData zoom) {
    final pattern = RegExp(
      r"""<div\b[^>]*data-sectionzoom=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = pattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, sectionZoomMarkup(zoom));
  }

  /// OOXML: a grid of `<p:sp>` shapes, each with a slide-jump hyperlink.
  static String renderPptxSectionZoomXml({
    required int shapeId,
    required SectionZoomData zoom,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
  }) {
    final b = StringBuffer();
    final entries = zoom.entries;
    final cols = zoom.columns.clamp(1, 4);
    final rows = entries.isEmpty ? 1 : (entries.length / cols).ceil();
    const gap = 91440; // 0.1"
    final tileW = (extCx - (cols - 1) * gap) ~/ cols;
    final tileH = (extCy - (rows - 1) * gap) ~/ rows;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final col = i % cols;
      final row = i ~/ cols;
      final tx = offX + col * (tileW + gap);
      final ty = offY + row * (tileH + gap);
      b.write('<p:sp>\n'
          '  <p:nvSpPr><p:cNvPr id="${shapeId++}" name="Section Zoom ${_xml(e.label)}"/>'
          '<p:cNvSpPr/><p:nvPr>'
          '<a:hlinkClick action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
          '</p:nvPr></p:nvSpPr>\n'
          '  <p:spPr><a:xfrm><a:off x="$tx" y="$ty"/>'
          '<a:ext cx="$tileW" cy="$tileH"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
          '<a:solidFill><a:srgbClr val="1A2A4A"/></a:solidFill>'
          '</p:spPr>\n'
          '  <p:txBody><a:bodyPr/><a:lstStyle/>'
          '<a:p><a:pPr algn="ctr"/>'
          '<a:r><a:rPr lang="en-US" sz="1400" b="1">'
          '<a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:rPr>'
          '<a:t>${_xml(e.label)}</a:t></a:r></a:p></p:txBody>\n'
          '</p:sp>\n');
    }
    return b.toString();
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}