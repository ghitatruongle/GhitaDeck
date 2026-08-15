/// Deck metadata: header/footer/slide-number/date-time (Track 19, FEAT 21, 24).
///
/// Stored in `PresentationState` alongside the slide list and exported to
/// PPTX (master placeholder shapes + `<a:fld>` dynamic fields), HTML (fixed
/// header/footer bars), and PDF (page header/footer).
library;

import 'dart:convert';
import '../models/guide_settings.dart';

class DeckMeta {
  const DeckMeta({
    this.header = '',
    this.footer = '',
    this.slideNumber = true,
    this.slideNumberFormat = 'Slide %d', // only used for HTML/PDF
    this.dateTime = false,
    this.dateTimeAuto = true, // true = dynamic (updated by PowerPoint)
    this.dateTimeFormat = 'yyyy-MM-dd',
    this.excludeFirst = true,
    this.guides = const GuideSettings(),
  });

  /// Canvas editing aids (guides / snap / grid / ruler) — Track 27, P6.
  final GuideSettings guides;

  /// Header text (left-aligned, shown on every slide).
  final String header;

  /// Footer text (centred, shown on every slide).
  final String footer;

  /// Whether to show the slide number.
  final bool slideNumber;

  /// Format string for the slide number display (HTML/PDF only).
  final String slideNumberFormat;

  /// Whether to show the date/time.
  final bool dateTime;

  /// If true, PowerPoint updates the date on open (dynamic `<a:fld>`).
  final bool dateTimeAuto;

  /// Format string for the date/time (e.g. 'yyyy-MM-dd', 'MM/dd/yy').
  final String dateTimeFormat;

  /// If true, the first slide (title slide) does not show header/footer/num.
  final bool excludeFirst;

  DeckMeta copyWith({
    String? header,
    String? footer,
    bool? slideNumber,
    String? slideNumberFormat,
    bool? dateTime,
    bool? dateTimeAuto,
    String? dateTimeFormat,
    bool? excludeFirst,
    GuideSettings? guides,
  }) =>
      DeckMeta(
        header: header ?? this.header,
        footer: footer ?? this.footer,
        slideNumber: slideNumber ?? this.slideNumber,
        slideNumberFormat: slideNumberFormat ?? this.slideNumberFormat,
        dateTime: dateTime ?? this.dateTime,
        dateTimeAuto: dateTimeAuto ?? this.dateTimeAuto,
        dateTimeFormat: dateTimeFormat ?? this.dateTimeFormat,
        excludeFirst: excludeFirst ?? this.excludeFirst,
        guides: guides ?? this.guides,
      );

  Map<String, dynamic> toMap() => {
        if (header.isNotEmpty) 'header': header,
        if (footer.isNotEmpty) 'footer': footer,
        if (!slideNumber) 'slideNumber': false,
        if (slideNumberFormat != 'Slide %d') 'slideNumberFormat': slideNumberFormat,
        if (dateTime) 'dateTime': true,
        if (!dateTimeAuto) 'dateTimeAuto': false,
        if (dateTimeFormat != 'yyyy-MM-dd') 'dateTimeFormat': dateTimeFormat,
        if (!excludeFirst) 'excludeFirst': false,
        if (guides.guides.isNotEmpty ||
            !guides.snapToGrid ||
            !guides.snapToShape ||
            guides.showGrid ||
            guides.gridSize != 5 ||
            !guides.showRuler ||
            !guides.showGuides)
          'guides': guides.toMap(),
      };

  static DeckMeta fromMap(Map<String, dynamic> map) => DeckMeta(
        header: map['header']?.toString() ?? '',
        footer: map['footer']?.toString() ?? '',
        slideNumber: map['slideNumber'] != false,
        slideNumberFormat: map['slideNumberFormat']?.toString() ?? 'Slide %d',
        dateTime: map['dateTime'] == true,
        dateTimeAuto: map['dateTimeAuto'] != false,
        dateTimeFormat: map['dateTimeFormat']?.toString() ?? 'yyyy-MM-dd',
        excludeFirst: map['excludeFirst'] != false,
        guides: map['guides'] is Map
            ? GuideSettings.fromMap(Map<String, dynamic>.from(map['guides'] as Map))
            : const GuideSettings(),
      );

  String toJson() => jsonEncode(toMap());

  static DeckMeta fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const DeckMeta();
      return fromMap(map);
    } catch (_) {
      return const DeckMeta();
    }
  }
}

class HeaderFooterService {
  HeaderFooterService._();

  /// Build the footer `<p:sp>` shapes for the PPTX slide master.
  /// Each shape carries a `<p:ph>` placeholder (type hdr/ftr/sldNum/dt) and
  /// an `<a:fld>` field when the value is dynamic (slide number, date).
  static String masterFooterShapesXml(DeckMeta meta) {
    final b = StringBuffer();
    int id = 101;
    if (meta.header.isNotEmpty) {
      b.write(_footerShapeXml(
        id: id++, name: 'Header', phType: 'hdr', text: meta.header, fld: false));
    }
    if (meta.footer.isNotEmpty) {
      b.write(_footerShapeXml(
        id: id++, name: 'Footer', phType: 'ftr', text: meta.footer, fld: false));
    }
    if (meta.slideNumber) {
      b.write(_footerShapeXml(
        id: id++, name: 'Slide Number', phType: 'sldNum', text: '<#>' , fld: true));
    }
    if (meta.dateTime) {
      final dtText = meta.dateTimeAuto ? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}' : '';
      b.write(_footerShapeXml(
        id: id++, name: 'Date', phType: 'dt', text: dtText, fld: meta.dateTimeAuto));
    }
    return b.toString();
  }

  static String _footerShapeXml({
    required int id,
    required String name,
    required String phType,
    required String text,
    required bool fld,
  }) {
    return '<p:sp>\n'
        '  <p:nvSpPr><p:cNvPr id="$id" name="$name"/><p:cNvSpPr/><p:nvPr><p:ph type="$phType"/></p:nvPr></p:nvSpPr>\n'
        '  <p:spPr><a:xfrm><a:off x="685800" y="6248400"/>'
        '<a:ext cx="7772400" cy="342900"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:noFill/></p:spPr>\n'
        '  <p:txBody><a:bodyPr/><a:lstStyle/>'
        '<a:p>${fld ? _fieldXml(phType, text) : '<a:r><a:rPr lang="en-US" sz="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill></a:rPr><a:t>${_xml(text)}</a:t></a:r>'}'
        '</a:p></p:txBody>\n'
        '</p:sp>\n';
  }

  /// Build an `<a:fld>` (dynamic field) for slide number or date.
  static String _fieldXml(String phType, String text) {
    if (phType == 'sldNum') {
      return '<a:fld type="slidenum" id="{${_guidV4()}}"><a:rPr lang="en-US" sz="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:rPr><a:t></a:t></a:fld>';
    } else if (phType == 'dt') {
      return '<a:fld type="datetime1" id="{${_guidV4()}}"><a:rPr lang="en-US" sz="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:rPr><a:t>$text</a:t></a:fld>';
    }
    return '<a:r><a:rPr lang="en-US" sz="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill></a:rPr><a:t>${_xml(text)}</a:t></a:r>';
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _guidV4() {
    final r = DateTime.now().microsecondsSinceEpoch;
    return '${r.toRadixString(16).padLeft(8, '0').substring(0, 8)}-'
        '0000-0000-0000-000000000000';
  }
}