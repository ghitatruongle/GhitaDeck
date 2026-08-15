/// OLE object embedding service (Track 18, FEAT 20).
///
/// Embeds an external file (Excel, Word, PDF) into the PPTX package as
/// `ppt/embeddings/oleObject{n}.bin` (a copy of the original file) with a
/// `<p:oleObj>` shape + an icon PNG + a double-click hyperlink that opens the
/// embedded file. The slide carries `<div data-ole='{json}'>` blocks.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class OleData {
  const OleData({
    this.fileName = '',
    this.fileBytes = const [],
    this.iconLabel = 'Document',
    this.x = 40.0,
    this.y = 40.0,
    this.w = 20.0,
    this.h = 15.0,
  });

  final String fileName;
  final List<int> fileBytes;
  final String iconLabel;
  final double x, y, w, h; // % of slide

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'iconLabel': iconLabel,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        // The binary payload travels as base64 so the JSON attribute stays
        // safe for HTML/attribute embedding. PPTX reads fileBytes back.
        if (fileBytes.isNotEmpty) 'fileBase64': base64Encode(fileBytes),
      };

  static OleData fromMap(Map<String, dynamic> map) => OleData(
        fileName: map['fileName']?.toString() ?? '',
        iconLabel: map['iconLabel']?.toString() ?? 'Document',
        x: (map['x'] as num?)?.toDouble() ?? 40.0,
        y: (map['y'] as num?)?.toDouble() ?? 40.0,
        w: (map['w'] as num?)?.toDouble() ?? 20.0,
        h: (map['h'] as num?)?.toDouble() ?? 15.0,
        fileBytes: map['fileBytes'] is List
            ? List<int>.from(map['fileBytes'] as List)
            : (map['fileBase64'] is String
                ? base64Decode(map['fileBase64'] as String)
                : []),
      );

  String toJson() => jsonEncode(toMap());

  static OleData fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const OleData();
      return fromMap(map);
    } catch (_) {
      return const OleData();
    }
  }

  /// HTML markup for the app preview / HTML deck.
  String get htmlMarkup => '<div data-ole-html style="position:absolute; '
      'left:$x%; top:$y%; width:$w%; height:$h%; '
      'display:flex; flex-direction:column; align-items:center; '
      'justify-content:center; background:#f0f4f8; border:1px solid #b0c4de; '
      'border-radius:8px; cursor:pointer; font-family:Segoe UI;'
      '">'
      '<div style="font-size:2rem; color:#3a8fd4;">📄</div>'
      '<div style="font-size:0.85rem; color:#333; margin-top:4px; '
      'font-weight:600;">${_xml(iconLabel)}</div>'
      '<div style="font-size:0.7rem; color:#888;">'
      '${_xml(fileName)}</div>'
      '</div>';

  String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class OleService {
  OleService._();

  static final RegExp _dataOleRegExp = RegExp(
    r"""data-ole=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  static List<OleData> olesIn(String html) {
    final result = <OleData>[];
    for (final match in _dataOleRegExp.allMatches(html)) {
      result.add(OleData.fromJson(match.group(2)!));
    }
    return result;
  }

  static String escapeAttribute(OleData ole) =>
      ole.toJson().replaceAll("'", '&#39;');

  static String oleMarkup(OleData ole) =>
      '<div data-ole=\'${escapeAttribute(ole)}\'></div>';

  static int oleCount(String html) => _dataOleRegExp.allMatches(html).length;

  static String replaceOleAt(String html, int index, OleData ole) {
    final pattern = RegExp(
      r"""<div\b[^>]*data-ole=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = pattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, oleMarkup(ole));
  }

  /// OOXML `<p:oleObj>` shape for an embedded file.
  ///
  /// The file is embedded as `ppt/embeddings/oleObject{n}.bin` (a raw copy),
  /// an icon PNG is generated and placed in `ppt/media/`, and the shape
  /// carries a double-click action (`a:hlinkClick`) to open the file.
  /// The relationship `rId` is for the oleObject part.
  static String renderPptxOleShape({
    required int shapeId,
    required OleData ole,
    required String oleRid,
    required String iconRid,
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
  }) {
    final ext = ole.fileName.contains('.') ? ole.fileName.split('.').last : 'bin';
    final progId = _progIdFor(ext);
    return '<p:sp>\n'
        '  <p:nvSpPr><p:cNvPr id="$shapeId" name="OLE Object ${ole.iconLabel}"/>'
        '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
        '<p:nvPr/>'
        '<p:oleObj name="${ole.iconLabel}"'
        ' r:id="$oleRid"'
        ' progId="$progId"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
        '/></p:nvSpPr>\n'
        '  <p:spPr><a:xfrm><a:off x="$offX" y="$offY"/>'
        '<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="F0F4F8"/></a:solidFill>'
        '<a:ln><a:solidFill><a:srgbClr val="B0C4DE"/></a:solidFill></a:ln>'
        '</p:spPr>\n'
        '  <p:txBody><a:bodyPr/><a:lstStyle/>'
        '<a:p><a:pPr algn="ctr"/>'
        '<a:r><a:rPr lang="en-US" sz="1400" b="1">'
        '<a:solidFill><a:srgbClr val="333333"/></a:solidFill></a:rPr>'
        '<a:t>${_xml(ole.iconLabel)}</a:t></a:r>'
        '<a:r><a:rPr lang="en-US" sz="1000">'
        '<a:solidFill><a:srgbClr val="888888"/></a:solidFill></a:rPr>'
        '<a:t>\n${_xml(ole.fileName)}</a:t></a:r></a:p>'
        '</p:txBody>\n'
        '</p:sp>\n'
        // Also a <p:pic> icon overlay (the document icon).
        '<p:pic>\n'
        '  <p:nvPicPr><p:cNvPr id="${shapeId + 1}" name="OLE Icon ${ole.iconLabel}"/>'
        '<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>'
        '<p:nvPr/></p:nvPicPr>\n'
        '  <p:blipFill><a:blip r:embed="$iconRid"/>'
        '<a:stretch><a:fillRect/></a:stretch></p:blipFill>\n'
        '  <p:spPr><a:xfrm><a:off x="$offX" y="$offY"/>'
        '<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n'
        '</p:pic>\n';
  }

  /// Generate a simple document-icon PNG (48×48) for the OLE shape.
  static Uint8List renderIconPng(OleData ole) {
    final image = img.Image(width: 48, height: 48);
    img.fill(image, color: img.ColorRgb8(240, 244, 248));
    // Document body
    img.fillRect(image, x1: 8, y1: 6, x2: 40, y2: 42, color: img.ColorRgb8(58, 143, 212));
    // Folded corner
    img.fillRect(image, x1: 32, y1: 6, x2: 40, y2: 14, color: img.ColorRgb8(100, 170, 230));
    // Lines
    img.drawLine(image, x1: 14, y1: 20, x2: 34, y2: 20, color: img.ColorRgb8(255, 255, 255));
    img.drawLine(image, x1: 14, y1: 26, x2: 34, y2: 26, color: img.ColorRgb8(255, 255, 255));
    img.drawLine(image, x1: 14, y1: 32, x2: 28, y2: 32, color: img.ColorRgb8(255, 255, 255));
    return Uint8List.fromList(img.encodePng(image));
  }

  static String _progIdFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'xlsx': return 'Excel.Sheet';
      case 'xls': return 'Excel.Sheet.8';
      case 'docx': return 'Word.Document.12';
      case 'doc': return 'Word.Document.8';
      case 'pdf': return 'Acrobat.Document';
      case 'pptx': return 'PowerPoint.Show.12';
      default: return 'Package';
    }
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}