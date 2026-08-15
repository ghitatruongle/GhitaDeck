import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/layer.dart';
import '../../providers/presentation_state.dart';
import '../../services/layer_service.dart';

/// Selection Pane — right-dock panel listing every editable object on the
/// current slide (back → front), with hide/lock/rename/reorder controls
/// (Track 26, P2/P3).
///
/// Selection in the pane mirrors the canvas: clicking an entry highlights it
/// (via [onSelectLayer]) and the canvas overlay selection is reflected back
/// through [selectedIds].
class SelectionPane extends StatefulWidget {
  /// Called when the user clicks a layer row (or its label) — lets the
  /// canvas overlay select that element.
  final void Function(String elementId)? onSelectLayer;

  /// Currently selected element ids (from the canvas) to highlight.
  final Set<String> selectedIds;

  const SelectionPane({super.key, this.onSelectLayer, this.selectedIds = const {}});

  @override
  State<SelectionPane> createState() => _SelectionPaneState();
}

class _SelectionPaneState extends State<SelectionPane> {
  List<SlideLayer> _layers = const [];

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);
    // Rebuild whenever the slide content changes.
    final slide = presentationState.currentSlide;
    _layers = slide == null ? const [] : LayerService.buildLayers(slide);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: const Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Selection Pane',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text('${_layers.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    )),
              ],
            ),
          ),
          Expanded(
            child: _layers.isEmpty
                ? Center(
                    child: Text(
                      'No objects on this slide',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: _layers.length,
                    onReorderItem: (oldIndex, newIndex) {
                      presentationState.reorderLayer(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final layer = _layers[index];
                      final selected = widget.selectedIds.contains(layer.elementId);
                      return _LayerRow(
                        key: ValueKey(layer.id),
                        layer: layer,
                        selected: selected,
                        onSelect: () => widget.onSelectLayer?.call(layer.elementId),
                        onToggleVisible: () => presentationState
                            .setLayersVisible([layer.id], !layer.visible),
                        onToggleLocked: () =>
                            presentationState.setLayersLocked([layer.id], !layer.locked),
                        onRename: (name) => presentationState.renameLayer(layer.id, name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final SlideLayer layer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleLocked;
  final ValueChanged<String> onRename;

  const _LayerRow({
    super.key,
    required this.layer,
    required this.selected,
    required this.onSelect,
    required this.onToggleVisible,
    required this.onToggleLocked,
    required this.onRename,
  });

  IconData get _typeIcon => switch (layer.type) {
        'text' => Icons.text_fields,
        'shape' => Icons.category_outlined,
        'image' => Icons.image_outlined,
        'chart' => Icons.bar_chart,
        'icon' => Icons.star_outline,
        'video' => Icons.videocam_outlined,
        'audio' => Icons.audiotrack,
        _ => Icons.crop_square,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onSelect,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: layer.zOrder,
              child: Icon(
                Icons.drag_indicator,
                size: 16,
                color: theme.colorScheme.outline,
              ),
            ),
            IconButton(
              icon: Icon(
                layer.visible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: layer.visible ? null : theme.colorScheme.outline,
              ),
              tooltip: layer.visible ? 'Hide' : 'Show',
              visualDensity: VisualDensity.compact,
              onPressed: onToggleVisible,
            ),
            IconButton(
              icon: Icon(
                layer.locked ? Icons.lock : Icons.lock_open,
                size: 15,
                color: layer.locked ? theme.colorScheme.error : theme.colorScheme.outline,
              ),
              tooltip: layer.locked ? 'Unlock' : 'Lock',
              visualDensity: VisualDensity.compact,
              onPressed: onToggleLocked,
            ),
            Icon(_typeIcon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: () => _promptRename(context),
                child: Text(
                  layer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    decoration: layer.visible ? null : TextDecoration.lineThrough,
                    color: layer.visible ? null : theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptRename(BuildContext context) async {
    final controller = TextEditingController(text: layer.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Layer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Layer name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      onRename(result.trim());
    }
  }
}
