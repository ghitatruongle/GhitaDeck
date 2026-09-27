import '../html/html_parser.dart';

enum DocBlockKind {
  text,
  list,
  image,
  table,
  video,
  icon,
  smartart,
  model3d,
  chart,
  action,
  equation,
  ole,
  zoom,
  sectionzoom,
  cameo,
  unknown,
}

class InlineRun {
  final String text;
  final String bold;
  final String italic;
  final String? underline;
  final String? strike;
  final String? color;
  final String? highlight;
  final String? size;
  final String? font;
  final String? align;
  final String? href;
  final String? isBreak;
  final String? paragraphStart;
  final String? itemStart;
  final Map<String, String> extra;

  const InlineRun({
    required this.text,
    this.bold = 'false',
    this.italic = 'false',
    this.underline,
    this.strike,
    this.color,
    this.highlight,
    this.size,
    this.font,
    this.align,
    this.href,
    this.isBreak,
    this.paragraphStart,
    this.itemStart,
    this.extra = const {},
  });

  static const _knownKeys = {
    'text',
    'bold',
    'italic',
    'underline',
    'strike',
    'color',
    'highlight',
    'size',
    'font',
    'align',
    'href',
    'isBreak',
    'paragraphStart',
    'itemStart',
  };

  factory InlineRun.fromLegacy(Map<String, String> run) {
    final extra = <String, String>{};
    run.forEach((key, value) {
      if (!InlineRun._knownKeys.contains(key)) extra[key] = value;
    });
    return InlineRun(
      text: run['text'] ?? '',
      bold: run['bold'] ?? 'false',
      italic: run['italic'] ?? 'false',
      underline: run['underline'],
      strike: run['strike'],
      color: run['color'],
      highlight: run['highlight'],
      size: run['size'],
      font: run['font'],
      align: run['align'],
      href: run['href'],
      isBreak: run['isBreak'],
      paragraphStart: run['paragraphStart'],
      itemStart: run['itemStart'],
      extra: extra,
    );
  }

  Map<String, String> toLegacyRun() {
    return {
      'text': text,
      'bold': bold,
      'italic': italic,
      if (underline != null) 'underline': underline!,
      if (strike != null) 'strike': strike!,
      if (color != null) 'color': color!,
      if (highlight != null) 'highlight': highlight!,
      if (size != null) 'size': size!,
      if (font != null) 'font': font!,
      if (align != null) 'align': align!,
      if (href != null) 'href': href!,
      if (isBreak != null) 'isBreak': isBreak!,
      if (paragraphStart != null) 'paragraphStart': paragraphStart!,
      if (itemStart != null) 'itemStart': itemStart!,
      ...extra,
    };
  }
}

class DocBlock {
  final DocBlockKind kind;
  final List<InlineRun> paragraphs;
  final List<InlineRun> items;
  final bool ordered;
  final String src;
  final String poster;
  final String payload;
  final List<List<InlineRun>> rows;
  final bool headerRow;
  final Map<String, dynamic> raw;

  const DocBlock({
    required this.kind,
    this.paragraphs = const [],
    this.items = const [],
    this.ordered = false,
    this.src = '',
    this.poster = '',
    this.payload = '',
    this.rows = const [],
    this.headerRow = false,
    this.raw = const {},
  });

  static const _kindByType = {
    'text': DocBlockKind.text,
    'list': DocBlockKind.list,
    'image': DocBlockKind.image,
    'table': DocBlockKind.table,
    'video': DocBlockKind.video,
    'icon': DocBlockKind.icon,
    'smartart': DocBlockKind.smartart,
    'model3d': DocBlockKind.model3d,
    'chart': DocBlockKind.chart,
    'action': DocBlockKind.action,
    'equation': DocBlockKind.equation,
    'ole': DocBlockKind.ole,
    'zoom': DocBlockKind.zoom,
    'sectionzoom': DocBlockKind.sectionzoom,
    'cameo': DocBlockKind.cameo,
  };

  static const _attrByKind = {
    DocBlockKind.video: 'data-video',
    DocBlockKind.icon: 'data-icon',
    DocBlockKind.smartart: 'data-smartart',
    DocBlockKind.model3d: 'data-model3d',
    DocBlockKind.chart: 'data-chart',
    DocBlockKind.action: 'data-action',
    DocBlockKind.equation: 'data-equation',
    DocBlockKind.ole: 'data-ole',
    DocBlockKind.zoom: 'data-zoom',
    DocBlockKind.sectionzoom: 'data-sectionzoom',
    DocBlockKind.cameo: 'data-cameo',
  };

  static String? attrNameFor(DocBlockKind kind) => _attrByKind[kind];

  factory DocBlock.fromLegacy(Map<String, dynamic> map) {
    final typeName = (map['type'] ?? '').toString();
    final kind = DocBlock._kindByType[typeName] ?? DocBlockKind.unknown;
    List<InlineRun> runsOf(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => InlineRun.fromLegacy(Map<String, String>.from(
              m.map((k, v) => MapEntry(k.toString(), v.toString())))))
          .toList();
    }

    List<List<InlineRun>> rowsOf(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<List>()
          .map((row) => row.whereType<Map>().map((m) {
                final typed = Map<String, String>.from(
                    m.map((k, v) => MapEntry(k.toString(), v.toString())));
                return InlineRun.fromLegacy(typed);
              }).toList())
          .toList();
    }

    final attr = DocBlock.attrNameFor(kind);
    return DocBlock(
      kind: kind,
      paragraphs:
          kind == DocBlockKind.text ? runsOf(map['paragraphs']) : const [],
      items: kind == DocBlockKind.list ? runsOf(map['items']) : const [],
      ordered: map['ordered'] == true,
      src: (map['src'] ?? '').toString(),
      poster: (map['poster'] ?? '').toString(),
      payload: attr == null ? '' : (map[attr] ?? '').toString(),
      rows: kind == DocBlockKind.table ? rowsOf(map['rows']) : const [],
      headerRow: map['headerRow'] == true,
      raw: kind == DocBlockKind.unknown ? map : const {},
    );
  }

  Map<String, dynamic> toLegacy() {
    if (kind == DocBlockKind.unknown) return Map<String, dynamic>.of(raw);
    final attr = DocBlock.attrNameFor(kind);
    switch (kind) {
      case DocBlockKind.text:
        return {
          'type': 'text',
          'paragraphs': paragraphs.map((r) => r.toLegacyRun()).toList()
        };
      case DocBlockKind.list:
        return {
          'type': 'list',
          'items': items.map((r) => r.toLegacyRun()).toList(),
          'ordered': ordered,
        };
      case DocBlockKind.image:
        return {'type': 'image', 'src': src};
      case DocBlockKind.table:
        return {
          'type': 'table',
          'rows': rows
              .map((row) => row.map((r) => r.toLegacyRun()).toList())
              .toList(),
          'headerRow': headerRow,
        };
      case DocBlockKind.video:
        return {
          'type': 'video',
          'data-video': payload,
          'poster': poster,
          'src': src,
        };
      default:
        return {'type': kind.name, attr!: payload};
    }
  }
}

class DocSlideAttributes {
  final String? bgColor;
  final List<String> smartart;
  final List<String> chart;
  final List<String> video;
  final List<String> icon;
  final List<String> model3d;
  final List<String> action;
  final List<String> equation;
  final List<String> ole;
  final List<String> zoom;
  final List<String> sectionZoom;
  final List<String> cameo;

  const DocSlideAttributes({
    this.bgColor,
    this.smartart = const [],
    this.chart = const [],
    this.video = const [],
    this.icon = const [],
    this.model3d = const [],
    this.action = const [],
    this.equation = const [],
    this.ole = const [],
    this.zoom = const [],
    this.sectionZoom = const [],
    this.cameo = const [],
  });

  List<String> payloadsFor(DocBlockKind kind) {
    switch (kind) {
      case DocBlockKind.smartart:
        return smartart;
      case DocBlockKind.chart:
        return chart;
      case DocBlockKind.video:
        return video;
      case DocBlockKind.icon:
        return icon;
      case DocBlockKind.model3d:
        return model3d;
      case DocBlockKind.action:
        return action;
      case DocBlockKind.equation:
        return equation;
      case DocBlockKind.ole:
        return ole;
      case DocBlockKind.zoom:
        return zoom;
      case DocBlockKind.sectionzoom:
        return sectionZoom;
      case DocBlockKind.cameo:
        return cameo;
      default:
        return const [];
    }
  }
}

class SlideDocument {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String sourceHtml;
  final String notes;
  final String subtitle;
  final String? bgColor;
  final List<DocBlock> blocks;
  final DocSlideAttributes attributes;

  const SlideDocument({
    this.schemaVersion = SlideDocument.currentSchemaVersion,
    required this.sourceHtml,
    this.notes = '',
    this.subtitle = '',
    this.bgColor,
    this.blocks = const [],
    this.attributes = const DocSlideAttributes(),
  });

  List<Map<String, dynamic>> toLegacyBlocks() =>
      blocks.map((b) => b.toLegacy()).toList();

  static DocSlideAttributes attributesFromBlocks(
    List<Map<String, dynamic>> legacyBlocks, {
    String? bgColor,
  }) {
    final buckets = <DocBlockKind, List<String>>{};
    for (final map in legacyBlocks) {
      final block = DocBlock.fromLegacy(map);
      final attr = DocBlock.attrNameFor(block.kind);
      if (attr == null || block.payload.isEmpty) continue;
      buckets.putIfAbsent(block.kind, () => []).add(block.payload);
    }
    String? bg = bgColor;
    if (bg == null) {
      for (final map in legacyBlocks) {
        final raw = map['bgColor'];
        if (raw != null && raw.toString().isNotEmpty) {
          bg = raw.toString();
          break;
        }
      }
    }
    return DocSlideAttributes(
      bgColor: bg,
      smartart: buckets[DocBlockKind.smartart] ?? const [],
      chart: buckets[DocBlockKind.chart] ?? const [],
      video: buckets[DocBlockKind.video] ?? const [],
      icon: buckets[DocBlockKind.icon] ?? const [],
      model3d: buckets[DocBlockKind.model3d] ?? const [],
      action: buckets[DocBlockKind.action] ?? const [],
      equation: buckets[DocBlockKind.equation] ?? const [],
      ole: buckets[DocBlockKind.ole] ?? const [],
      zoom: buckets[DocBlockKind.zoom] ?? const [],
      sectionZoom: buckets[DocBlockKind.sectionzoom] ?? const [],
      cameo: buckets[DocBlockKind.cameo] ?? const [],
    );
  }

  static SlideDocument fromParts({
    required String html,
    required String notes,
    required String? subtitle,
    required List<Map<String, dynamic>> legacyBlocks,
    String? bgColor,
  }) {
    return SlideDocument(
      sourceHtml: html,
      notes: notes,
      subtitle: subtitle ?? '',
      bgColor: bgColor,
      blocks: legacyBlocks.map(DocBlock.fromLegacy).toList(),
      attributes: attributesFromBlocks(legacyBlocks, bgColor: bgColor),
    );
  }
}

class SlideDocumentParser {
  SlideDocumentParser._();

  static SlideDocument fromHtml(String html, {HtmlParseCache? cache}) {
    final effective = cache ?? HtmlParseCache.shared;
    final entry = effective.entryFor(html);
    return SlideDocument.fromParts(
      html: html,
      notes: entry.notes,
      subtitle: entry.subtitle,
      legacyBlocks: entry.blocks,
      bgColor: entry.bgColor,
    );
  }
}
