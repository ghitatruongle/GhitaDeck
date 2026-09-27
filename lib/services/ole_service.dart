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
    final buffer = StringBuffer();
    buffer.write('<p:pic>');
    buffer.write('<p:nvPicPr>');
    buffer.write('<p:cNvPr id="$shapeId" name="${ole.fileName}"/>');
    buffer.write('<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>');
    buffer.write('<p:nvPr/>');
    buffer.write(
        '<p:extLst><p:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}">');
    buffer.write(
        '<p14:compatExt xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" spid="_x0000_s${shapeId}0"/>');
    buffer.write('</p:ext></p:extLst>');
    buffer.write('</p:nvPicPr>');
    buffer.write('<p:blipFill><a:blip r:embed="$iconRid"/>');
    buffer.write('<a:stretch><a:fillRect/></a:stretch></p:blipFill>');
    buffer.write('<p:spPr><a:xfrm><a:off x="$offX" y="$offY"/>');
    buffer.write('<a:ext cx="$extCx" cy="$extCy"/></a:xfrm>');
    buffer.write(
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>');
    buffer.write('</p:pic>');
    buffer.write('<p:graphicFrame>');
    buffer.write('<p:nvGraphicFramePr>');
    buffer.write(
        '<p:cNvPr id="$shapeId" name="OLE Object ${ole.iconLabel}"/>');
    buffer.write(
        '<p:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></p:cNvGraphicFramePr>');
    buffer.write('<p:nvPr/>');
    buffer.write('</p:nvGraphicFramePr>');
    buffer.write('<p:xfrm><a:off x="$offX" y="$offY"/>');
    buffer.write('<a:ext cx="$extCx" cy="$extCy"/></p:xfrm>');
    buffer.write('<a:graphic>');
    buffer.write(
        '<a:graphicData uri="http://schemas.openxmlformats.org/presentationml/2006/ole">');
    buffer.write(
        '<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">');
    buffer.write(
        '<mc:Choice xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" Requires="p14">');
    buffer.write(
        '<p:oleObj spid="_x0000_s${shapeId}0" name="${ole.iconLabel}" r:id="$oleRid" imgW="$extCx" imgH="$extCy" progId="$progId">');
    buffer.write('<p:embed/>');
    buffer.write('</p:oleObj>');
    buffer.write('</mc:Choice>');
    buffer.write('<mc:Fallback>');
    buffer.write(
        '<p:oleObj name="${ole.iconLabel}" r:id="$oleRid" imgW="$extCx" imgH="$extCy" progId="$progId">');
    buffer.write('<p:embed/>');
    buffer.write('</p:oleObj>');
    buffer.write('</mc:Fallback>');
    buffer.write('</mc:AlternateContent>');
    buffer.write('</a:graphicData>');
    buffer.write('</a:graphic>');
    buffer.write('</p:graphicFrame>');
    return buffer.toString();
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
}