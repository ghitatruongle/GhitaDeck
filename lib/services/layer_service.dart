import '../models/drawn_shape.dart';
import '../models/free_shape.dart';
import '../models/layer.dart';
import '../models/slide.dart';

/// Builds and manages the layer list of a slide (Track 26).
///
/// Layers are derived from `Slide.visualElements` (freeTexts + shapes) plus
/// the HTML content (images / charts / icons / video embedded as elements).
/// The presentation state (visible/locked/name) lives in
/// `visualElements['layers']` and is re-applied after every rebuild so the
/// Selection Pane stays in sync with canvas edits.
class LayerService {
  LayerService._();

  /// Stable id for a free-text element.
  static String freeTextId(FreeTextShape t) => 'ft_${t.id}';

  /// Stable id for a drawn shape.
  static String shapeId(DrawnShape s) => 'sh_${s.id}';

  /// Build the full layer list (back to front) for a slide. Presentation
  /// state stored under `visualElements['layers']` is re-applied by id.
  static List<SlideLayer> buildLayers(Slide slide) {
    final layers = <SlideLayer>[];

    final rawShapes = slide.visualElements['shapes'];
    if (rawShapes is List) {
      final shapes = rawShapes
          .map((e) => e is Map<String, dynamic>
              ? DrawnShape.fromMap(e)
              : (e is Map
                  ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                  : null))
          .whereType<DrawnShape>()
          .toList()
        ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
      for (final s in shapes) {
        layers.add(SlideLayer(
          id: shapeId(s),
          elementId: s.id,
          type: 'shape',
          name: 'Shape (${s.type.name})',
          zOrder: layers.length,
        ));
      }
    }

    final rawTexts = slide.visualElements['freeTexts'];
    if (rawTexts is List) {
      final texts = rawTexts
          .map((e) => e is Map<String, dynamic>
              ? FreeTextShape.fromMap(e)
              : (e is Map
                  ? FreeTextShape.fromMap(Map<String, dynamic>.from(e))
                  : null))
          .whereType<FreeTextShape>()
          .toList();
      for (final t in texts) {
        layers.add(SlideLayer(
          id: freeTextId(t),
          elementId: t.id,
          type: 'text',
          name: t.text.trim().isEmpty ? 'Text box' : t.text.trim(),
          zOrder: layers.length,
        ));
      }
    }

    // Re-apply persisted presentation state (visible / locked / rename).
    final rawState = slide.visualElements['layers'];
    if (rawState is List) {
      final stateMap = <String, SlideLayer>{};
      for (final e in rawState) {
        final m = e is Map<String, dynamic>
            ? e
            : (e is Map ? Map<String, dynamic>.from(e) : null);
        if (m == null) continue;
        final layer = SlideLayer.fromMap(m);
        stateMap[layer.id] = layer;
      }
      for (var i = 0; i < layers.length; i++) {
        final st = stateMap[layers[i].id];
        if (st != null) {
          layers[i] = layers[i].copyWith(
            name: st.name == 'Text box' && layers[i].name != 'Text box'
                ? layers[i].name
                : st.name,
            visible: st.visible,
            locked: st.locked,
          );
        }
      }
    }
    return layers;
  }

  /// Serialize the presentation state of [layers] for persistence.
  static List<Map<String, dynamic>> stateToMap(List<SlideLayer> layers) =>
      [for (final l in layers) l.toMap()];

  /// Reorder [layers] so the element at [from] moves to [to].
  static List<SlideLayer> reorder(List<SlideLayer> layers, int from, int to) {
    if (from < 0 || from >= layers.length || to < 0 || to >= layers.length) {
      return layers;
    }
    final copy = List<SlideLayer>.of(layers);
    final moved = copy.removeAt(from);
    copy.insert(to, moved);
    for (var i = 0; i < copy.length; i++) {
      copy[i] = copy[i].copyWith(zOrder: i);
    }
    return copy;
  }
}
