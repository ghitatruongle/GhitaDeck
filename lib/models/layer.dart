/// A single editable object on a slide (Track 26, P1).
///
/// Layers are derived from the slide content (free text boxes, drawn shapes,
/// images, charts, icons, video...) and their presentation state (visible /
/// locked / name) is persisted back into `Slide.visualElements['layers']`.
library;

class SlideLayer {
  final String id;

  /// Stable element key — matches the element's own id where one exists
  /// (freeText.id / shape.id) or the hash of the element's raw map.
  final String elementId;

  /// Layer type for the icon/label ('text', 'shape', 'image', 'chart',
  /// 'icon', 'video', 'audio', 'unknown').
  final String type;

  /// Display name (defaults to a type-based label; user can rename).
  final String name;

  /// Z-order (lower = further back). Derived from the element order.
  final int zOrder;

  /// Hidden layers stay editable in the app but are excluded from exports.
  final bool visible;

  /// Locked layers cannot be selected or moved on the canvas.
  final bool locked;

  const SlideLayer({
    required this.id,
    required this.elementId,
    required this.type,
    required this.name,
    required this.zOrder,
    this.visible = true,
    this.locked = false,
  });

  SlideLayer copyWith({String? name, bool? visible, bool? locked, int? zOrder}) =>
      SlideLayer(
        id: id,
        elementId: elementId,
        type: type,
        name: name ?? this.name,
        zOrder: zOrder ?? this.zOrder,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'elementId': elementId,
        'type': type,
        'name': name,
        'zOrder': zOrder,
        'visible': visible,
        'locked': locked,
      };

  static SlideLayer fromMap(Map<String, dynamic> map) => SlideLayer(
        id: map['id']?.toString() ?? '',
        elementId: map['elementId']?.toString() ?? '',
        type: map['type']?.toString() ?? 'unknown',
        name: map['name']?.toString() ?? 'Layer',
        zOrder: (map['zOrder'] as num?)?.toInt() ?? 0,
        visible: map['visible'] != false,
        locked: map['locked'] == true,
      );
}
