/// Action buttons service (Track 18, FEAT 17).
///
/// 12 PowerPoint-style action buttons (home, next, back, end, info, help,
/// movie, sound, document, begin, end, custom) each with an action:
/// slide jump (next/previous/first/last), URL, file, program, or sound.
/// Slides carry `<div data-action='{json}'>` blocks; the PPTX exporter
/// turns them into `p:sp` with `a:hlinkClick`/`p:action` (slideJump).
library;

import 'dart:convert';

enum ActionButtonKind {
  home,
  next,
  back,
  end,
  info,
  help,
  movie,
  sound,
  document,
  begin,
  custom,
}

enum ActionType { slideNext, slidePrev, slideFirst, slideLast, url, file, program }

class ActionButton {
  const ActionButton({
    this.kind = ActionButtonKind.custom,
    this.action = ActionType.slideNext,
    this.label = '',
    this.url = '',
    this.x = 40.0,
    this.y = 85.0,
    this.w = 10.0,
    this.h = 6.0,
    this.color = '#4472C4',
  });

  final ActionButtonKind kind;
  final ActionType action;
  final String label;
  final String url; // for url/file/program actions
  final double x, y, w, h; // % of slide
  final String color;

  /// Built-in label for the button kind (i18n applied by the caller).
  String get defaultLabel {
    switch (kind) {
      case ActionButtonKind.home: return 'Home';
      case ActionButtonKind.next: return 'Next';
      case ActionButtonKind.back: return 'Back';
      case ActionButtonKind.end: return 'End';
      case ActionButtonKind.info: return 'Info';
      case ActionButtonKind.help: return 'Help';
      case ActionButtonKind.movie: return 'Movie';
      case ActionButtonKind.sound: return 'Sound';
      case ActionButtonKind.document: return 'Document';
      case ActionButtonKind.begin: return 'Begin';
      case ActionButtonKind.custom: return 'Custom';
    }
  }

  /// The shape preset geometry name for the button kind (OOXML prstGeom).
  String get presetGeom {
    switch (kind) {
      case ActionButtonKind.home: return 'homePlate';
      case ActionButtonKind.next: return 'chevron';
      case ActionButtonKind.back: return 'chevron';
      case ActionButtonKind.end: return 'chevron';
      case ActionButtonKind.info: return 'info';
      case ActionButtonKind.help: return 'question';
      case ActionButtonKind.movie: return 'movie';
      case ActionButtonKind.sound: return 'speaker';
      case ActionButtonKind.document: return 'folder';
      case ActionButtonKind.begin: return 'actionButtonBlank';
      case ActionButtonKind.custom: return 'rect';
    }
  }

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'action': action.name,
        if (label.isNotEmpty) 'label': label,
        if (url.isNotEmpty) 'url': url,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        if (color != '#4472C4') 'color': color,
      };

  static ActionButton fromMap(Map<String, dynamic> map) => ActionButton(
        kind: ActionButtonKind.values.asNameMap()[map['kind']] ??
            ActionButtonKind.custom,
        action: ActionType.values.asNameMap()[map['action']] ??
            ActionType.slideNext,
        label: map['label']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
        x: (map['x'] as num?)?.toDouble() ?? 40.0,
        y: (map['y'] as num?)?.toDouble() ?? 85.0,
        w: (map['w'] as num?)?.toDouble() ?? 10.0,
        h: (map['h'] as num?)?.toDouble() ?? 6.0,
        color: map['color']?.toString() ?? '#4472C4',
      );

  String toJson() => jsonEncode(toMap());

  static ActionButton fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const ActionButton();
      return fromMap(map);
    } catch (_) {
      return const ActionButton();
    }
  }

  /// HTML markup for the app preview / HTML deck (a styled button).
  String get htmlMarkup {
    final label = this.label.isEmpty ? defaultLabel : this.label;
    return '<div data-action-html style="position:absolute; left:$x%; top:$y%; '
        'width:$w%; height:$h%; display:flex; align-items:center; '
        'justify-content:center; background:$color; color:#fff; '
        'border-radius:6px; font-size:0.9rem; font-weight:600; '
        'cursor:pointer; box-shadow:0 1px 4px rgba(0,0,0,0.25);">'
        '${_xml(label)}</div>';
  }

  String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class ActionButtonService {
  ActionButtonService._();

  static final RegExp _dataActionRegExp = RegExp(
    r"""data-action=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );

  /// Find every action button block in [html].
  static List<ActionButton> actionsIn(String html) {
    final result = <ActionButton>[];
    for (final match in _dataActionRegExp.allMatches(html)) {
      final button = ActionButton.fromJson(match.group(2)!);
      result.add(button);
    }
    return result;
  }

  static String escapeAttribute(ActionButton button) =>
      button.toJson().replaceAll("'", '&#39;');

  /// Build the `<div data-action>` block inserted into slide HTML.
  static String actionMarkup(ActionButton button) =>
      '<div data-action=\'${escapeAttribute(button)}\'></div>';

  static int actionCount(String html) => _dataActionRegExp.allMatches(html).length;

  /// Replace the [index]-th action block in [html].
  static String replaceActionAt(String html, int index, ActionButton button) {
    final pattern = RegExp(
      r"""<div\b[^>]*data-action=(['"])(.*?)\1[^>]*>.*?</div>""",
      caseSensitive: false,
      dotAll: true,
    );
    final matches = pattern.allMatches(html).toList();
    if (index < 0 || index >= matches.length) return html;
    final match = matches[index];
    return html.replaceRange(match.start, match.end, actionMarkup(button));
  }

  /// OOXML `<p:sp>` for an action button with the given relationship id.
  ///
  /// [slideAction] is the `p:action`/`a:hlinkClick` payload:
  ///  * slide jump: `<a:hlinkClick action="ppaction://hlinksldjump"><a:extLst>...<p14:action id="..."/>...`
  ///  * URL: `<a:hlinkClick r:id="rId" tooltip="...">`
  static String renderPptxActionShape({
    required int shapeId,
    required ActionButton button,
    required String actionXml, // the a:hlinkClick inner XML (or empty)
    required int offX,
    required int offY,
    required int extCx,
    required int extCy,
    String? tooltip,
  }) {
    final geom = button.presetGeom;
    final label = button.label.isEmpty ? button.defaultLabel : button.label;
    final colorHex = button.color.replaceAll('#', '');
    final b = StringBuffer();
    b.write('<p:sp>\n');
    b.write(
        '  <p:nvSpPr><p:cNvPr id="$shapeId" name="ActionButton ${button.kind.name}"/><p:cNvSpPr/><p:nvPr/>'
        '<p:nvPr>${actionXml.isEmpty ? '' : '<a:hlinkClick $actionXml/>'}'
        '<p:extLst><p:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}">'
        '<a16:creationId xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" id="{$shapeId-0000-0000-0000-000000000000}"/>'
        '</p:ext></p:extLst></p:nvPr></p:nvSpPr>\n');
    b.write(
        '  <p:spPr><a:xfrm><a:off x="$offX" y="$offY"/><a:ext cx="$extCx" cy="$extCy"/></a:xfrm>'
        '<a:prstGeom prst="$geom"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="$colorHex"/></a:solidFill>'
        '<a:ln><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
        '</p:spPr>\n');
    b.write(
        '  <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr algn="ctr"/>'
        '<a:r><a:rPr lang="en-US" sz="1200" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:rPr>'
        '<a:t>${_xml(label)}</a:t></a:r></a:p></p:txBody>\n');
    b.write('</p:sp>\n');
    return b.toString();
  }

  /// Build the `a:hlinkClick` payload for an action.
  static String actionHlinkXml(ActionButton button, {String? rid}) {
    switch (button.action) {
      case ActionType.slideNext:
        return 'action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:extLst><a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}"><a16:action xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" action="ppaction://hlinksldjump"/></a:ext></a:extLst>';
      case ActionType.slidePrev:
        return 'action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:extLst><a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}"><a16:action xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" action="ppaction://hlinksldjump"/></a:ext></a:extLst>';
      case ActionType.slideFirst:
        return 'action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:extLst><a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}"><a16:action xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" action="ppaction://hlinksldjump"/></a:ext></a:extLst>';
      case ActionType.slideLast:
        return 'action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><a:extLst><a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}"><a16:action xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" action="ppaction://hlinksldjump"/></a:ext></a:extLst>';
      case ActionType.url:
        return 'r:id="$rid" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
      case ActionType.file:
        return 'r:id="$rid" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
      case ActionType.program:
        return 'r:id="$rid" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
    }
  }

  /// The `p:action` slide-jump target string for a button (used in tests).
  static String slideJumpFor(ActionButton button) {
    switch (button.action) {
      case ActionType.slideNext: return 'nextslide';
      case ActionType.slidePrev: return 'previousslide';
      case ActionType.slideFirst: return 'firstslide';
      case ActionType.slideLast: return 'lastslide';
      default: return '';
    }
  }

  static String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}