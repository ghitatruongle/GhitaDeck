/// SmartArt model (Track 10, FEAT 4).
///
/// Pure Dart + serializable; a SmartArt diagram lives inside slide HTML as
/// `<div data-smartart='…json…'>` and is rendered by all three export
/// formats (PPTX `<dgm:>` package, HTML/PDF shapes).
library;

import 'dart:convert';

/// The 8 PowerPoint SmartArt groups (Track 10, P1).
enum SmartArtGroup { list, process, cycle, hierarchy, relationship, matrix, pyramid, picture }

/// Concrete layouts (26 across the 8 groups).
enum SmartArtLayout {
  // List
  basicBlockList(SmartArtGroup.list),
  horizontalList(SmartArtGroup.list),
  verticalBulletList(SmartArtGroup.list),
  groupedList(SmartArtGroup.list),
  // Process
  basicProcess(SmartArtGroup.process),
  chevronProcess(SmartArtGroup.process),
  arrowProcess(SmartArtGroup.process),
  circularBendProcess(SmartArtGroup.process),
  alternatingFlow(SmartArtGroup.process),
  funnelProcess(SmartArtGroup.process),
  // Cycle
  basicCycle(SmartArtGroup.cycle),
  continuousCycle(SmartArtGroup.cycle),
  radialCycle(SmartArtGroup.cycle),
  gearCycle(SmartArtGroup.cycle),
  // Hierarchy
  orgChart(SmartArtGroup.hierarchy),
  hierarchyList(SmartArtGroup.hierarchy),
  horizontalHierarchy(SmartArtGroup.hierarchy),
  tableHierarchy(SmartArtGroup.hierarchy),
  // Relationship
  basicRelationship(SmartArtGroup.relationship),
  balance(SmartArtGroup.relationship),
  equation(SmartArtGroup.relationship),
  overlapping(SmartArtGroup.relationship),
  // Matrix
  basicMatrix(SmartArtGroup.matrix),
  gridMatrix(SmartArtGroup.matrix),
  // Pyramid
  basicPyramid(SmartArtGroup.pyramid),
  segmentedPyramid(SmartArtGroup.pyramid),
  // Picture
  pictureAccentBlocks(SmartArtGroup.picture),
  pictureList(SmartArtGroup.picture);

  const SmartArtLayout(this.group);

  final SmartArtGroup group;
}

/// SmartArt colour themes (Track 10, P6).
enum SmartArtColorTheme {
  office('Office', ['4472C4', 'ED7D31', 'A5A5A5', 'FFC000', '5B9BD5', '70AD47']),
  colorful('Sắc màu', ['B4C7E7', 'F8CBAD', 'C5E0B4', 'FFE699', 'D9D2E9', 'F4CCCC']),
  gradient('Đậm', ['1F4E79', '2E75B6', '9DC3E6', '548235', '375623', '7F6000']);

  const SmartArtColorTheme(this.label, this.colors);

  final String label;
  final List<String> colors;

  String colorAt(int index) => colors[index % colors.length];
}

/// One diagram node; [parentId] null → top-level.
class SmartArtNode {
  const SmartArtNode({required this.id, required this.text, this.parentId});

  final int id;
  final String text;
  final int? parentId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        if (parentId != null) 'parentId': parentId,
      };

  static SmartArtNode fromMap(Map<String, dynamic> map) => SmartArtNode(
        id: (map['id'] as num).toInt(),
        text: (map['text'] ?? '').toString(),
        parentId: (map['parentId'] as num?)?.toInt(),
      );
}

/// A complete SmartArt diagram definition.
class SmartArtGraph {
  const SmartArtGraph({
    required this.layout,
    required this.nodes,
    this.title = '',
    this.colorTheme = SmartArtColorTheme.office,
  });

  final SmartArtLayout layout;
  final List<SmartArtNode> nodes;
  final String title;
  final SmartArtColorTheme colorTheme;

  /// Nodes in tree order (parents before children).
  List<SmartArtNode> get orderedNodes {
    final result = <SmartArtNode>[];
    void walk(int? parentId) {
      for (final n in nodes) {
        if (n.parentId == parentId) {
          result.add(n);
          walk(n.id);
        }
      }
    }

    walk(null);
    return result;
  }

  List<SmartArtNode> childrenOf(int id) =>
      nodes.where((n) => n.parentId == id).toList();

  SmartArtGraph copyWith({
    SmartArtLayout? layout,
    List<SmartArtNode>? nodes,
    String? title,
    SmartArtColorTheme? colorTheme,
  }) {
    return SmartArtGraph(
      layout: layout ?? this.layout,
      nodes: nodes ?? this.nodes,
      title: title ?? this.title,
      colorTheme: colorTheme ?? this.colorTheme,
    );
  }

  /// Relayout (P6): same nodes/text, new layout.
  SmartArtGraph relayout(SmartArtLayout newLayout) =>
      copyWith(layout: newLayout);

  String toJson() => const JsonEncoder().convert(toMap());

  Map<String, dynamic> toMap() => {
        'layout': layout.name,
        'title': title,
        'colorTheme': colorTheme.name,
        'nodes': nodes.map((n) => n.toMap()).toList(),
      };

  static SmartArtGraph? fromJson(String json) {
    try {
      return fromMap(const JsonDecoder().convert(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static SmartArtGraph fromMap(Map<String, dynamic> map) {
    final layoutName = (map['layout'] ?? 'basicProcess').toString();
    return SmartArtGraph(
      layout: SmartArtLayout.values.firstWhere(
        (l) => l.name == layoutName,
        orElse: () => SmartArtLayout.basicProcess,
      ),
      title: (map['title'] ?? '').toString(),
      colorTheme: SmartArtColorTheme.values.firstWhere(
        (c) => c.name == (map['colorTheme'] ?? 'office'),
        orElse: () => SmartArtColorTheme.office,
      ),
      nodes: (map['nodes'] as List? ?? const [])
          .map((e) => SmartArtNode.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// Default graph for a layout: 3–5 top-level nodes.
  static SmartArtGraph sample(SmartArtLayout layout) {
    final count = switch (layout.group) {
      SmartArtGroup.hierarchy => 4,
      SmartArtGroup.matrix => 4,
      SmartArtGroup.pyramid => 4,
      SmartArtGroup.cycle => 4,
      _ => 3,
    };
    return SmartArtGraph(
      layout: layout,
      title: 'SmartArt',
      nodes: [
        for (var i = 1; i <= count; i++)
          SmartArtNode(id: i, text: 'Mục $i'),
      ],
    );
  }
}