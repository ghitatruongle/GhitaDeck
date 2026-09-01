import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/object_animation.dart';
import '../../providers/presentation_state.dart';
import '../../services/animation_engine.dart';
import '../../utils/snackbar_helper.dart';
import '../../l10n/l10n.dart';

/// Animation Pane (Track 30, FEAT 44/50) — dock panel listing every
/// animation of the current slide in timeline order with add/remove,
/// reorder, start/duration/repeat editing, clear-all and the Animation
/// Painter (copy an animation onto another shape).
class AnimationPane extends StatefulWidget {
  /// Shape ids currently selected on the canvas (painter target/source).
  final List<String> selectedShapeIds;

  const AnimationPane({super.key, this.selectedShapeIds = const []});

  @override
  State<AnimationPane> createState() => _AnimationPaneState();
}

class _AnimationPaneState extends State<AnimationPane> {
  List<ObjectAnimation> _animations = const [];
  ObjectAnimation? _copied;

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);
    _animations = presentationState.currentAnimations;
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
                Icon(Icons.animation, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Animation Pane', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: 'Add animation',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addAnimation(context, presentationState),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  tooltip: 'Clear all',
                  visualDensity: VisualDensity.compact,
                  onPressed: _animations.isEmpty
                      ? null
                      : () => presentationState.updateAnimations([]),
                ),
                IconButton(
                  icon: Icon(
                    _copied != null ? Icons.content_copy : Icons.copy_all,
                    size: 16,
                    color: _copied != null ? theme.colorScheme.primary : null,
                  ),
                  tooltip: _copied != null
                      ? 'Painter armed — click a shape'
                      : 'Animation Painter (copy from selected shape)',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _armPainter(presentationState),
                ),
              ],
            ),
          ),
          Expanded(
            child: _animations.isEmpty
                ? Center(
                    child: Text(
                      'No animations on this slide',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: _animations.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final list = List<ObjectAnimation>.of(_animations);
                      final moved = list.removeAt(oldIndex);
                      list.insert(newIndex, moved);
                      presentationState.updateAnimations(list);
                    },
                    itemBuilder: (context, index) {
                      final a = _animations[index];
                      return _AnimationRow(
                        key: ValueKey('${a.shapeId}-${a.effect.name}-$index'),
                        animation: a,
                        index: index,
                        total: _animations.length,
                        onUp: index == 0
                            ? null
                            : () => presentationState.updateAnimations(
                                  _move(_animations, index, index - 1),
                                ),
                        onDown: index == _animations.length - 1
                            ? null
                            : () => presentationState.updateAnimations(
                                  _move(_animations, index, index + 1),
                                ),
                        onDelete: () => presentationState
                            .updateAnimations(_remove(_animations, index)),
                        onEdit: () => _editAnimation(
                            context, presentationState, a, index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<ObjectAnimation> _move(List<ObjectAnimation> list, int from, int to) {
    final copy = List<ObjectAnimation>.of(list);
    final moved = copy.removeAt(from);
    copy.insert(to, moved);
    return copy;
  }

  List<ObjectAnimation> _remove(List<ObjectAnimation> list, int index) {
    final copy = List<ObjectAnimation>.of(list)..removeAt(index);
    return copy;
  }

  Future<void> _armPainter(PresentationState state) async {
    final selected = widget.selectedShapeIds;
    final anims = _animations;
    if (selected.isEmpty) {
      showAppSnackBar(context, context.l10n.animeSelectShapeNotice);
      return;
    }
    final source = anims
        .where((a) => selected.contains(a.shapeId))
        .toList();
    if (source.isEmpty) {
      showAppSnackBar(context, context.l10n.animeNoneNotice);
      return;
    }
    final copied = source.first;
    // Build the target list from every animated + selectable shape.
    final targets = <String>{
      for (final a in anims) a.shapeId,
      ...selected,
    }.toList()..sort();
    final targetId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Animation Painter — target shape'),
        children: [
          for (final id in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, id),
              child: Text(id),
            ),
        ],
      ),
    );
    if (targetId != null && targetId.isNotEmpty && mounted) {
      state.upsertAnimation(copied.copyWith(shapeId: targetId));
      showAppSnackBar(context, context.l10n.animeCopiedNotice);
    }
  }

  Future<void> _addAnimation(
      BuildContext context, PresentationState state) async {
    final result = await showDialog<ObjectAnimation>(
      context: context,
      builder: (context) => _AnimationPickerDialog(
        selectedShapeIds: widget.selectedShapeIds,
      ),
    );
    if (result != null) {
      state.upsertAnimation(result);
    }
  }

  Future<void> _editAnimation(BuildContext context, PresentationState state,
      ObjectAnimation a, int index) async {
    final result = await showDialog<ObjectAnimation>(
      context: context,
      builder: (context) => _AnimationEditDialog(animation: a),
    );
    if (result != null) {
      final list = List<ObjectAnimation>.of(_animations);
      list[index] = result;
      state.updateAnimations(list);
    }
  }
}

class _AnimationRow extends StatelessWidget {
  final ObjectAnimation animation;
  final int index;
  final int total;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AnimationRow({
    super.key,
    required this.animation,
    required this.index,
    required this.total,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupColor = switch (animation.group) {
      AnimationGroup.entrance => Colors.green,
      AnimationGroup.emphasis => Colors.orange,
      AnimationGroup.exit => Colors.red,
      AnimationGroup.motion => Colors.blue,
    };
    final startLabel = switch (animation.start) {
      AnimationStart.onClick => 'Click',
      AnimationStart.withPrevious => 'With',
      AnimationStart.afterPrevious => 'After',
    };
    return InkWell(
      onTap: onEdit,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator,
                  size: 16, color: theme.colorScheme.outline),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: groupColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${AnimationEngine.effectNames[animation.effect]}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Text(
                  '$startLabel · ${animation.duration.toStringAsFixed(1)}s'
                  '${animation.repeat != 0 ? ' · x${animation.repeat == -1 ? '∞' : animation.repeat + 1}' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: onUp,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: onDown,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimationPickerDialog extends StatefulWidget {
  final List<String> selectedShapeIds;
  const _AnimationPickerDialog({required this.selectedShapeIds});

  @override
  State<_AnimationPickerDialog> createState() => _AnimationPickerDialogState();
}

class _AnimationPickerDialogState extends State<_AnimationPickerDialog> {
  AnimationEffect _effect = AnimationEffect.fadeIn;
  AnimationGroup _group = AnimationGroup.entrance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add Animation'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 4,
              children: [
                for (final g in AnimationGroup.values)
                  ChoiceChip(
                    label: Text(g.name),
                    selected: _group == g,
                    onSelected: (_) => setState(() {
                      _group = g;
                      _effect = AnimationEngine.effectsByGroup()[g]!.first;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Effect', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in AnimationEngine.effectsByGroup()[_group]!)
                  ChoiceChip(
                    label: Text(AnimationEngine.effectNames[e]!),
                    selected: _effect == e,
                    onSelected: (_) => setState(() => _effect = e),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final shapeId = widget.selectedShapeIds.isNotEmpty
                ? widget.selectedShapeIds.first
                : 'sh_1';
            Navigator.pop(
              context,
              ObjectAnimation(
                shapeId: shapeId,
                effect: _effect,
                group: _group,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AnimationEditDialog extends StatefulWidget {
  final ObjectAnimation animation;
  const _AnimationEditDialog({required this.animation});

  @override
  State<_AnimationEditDialog> createState() => _AnimationEditDialogState();
}

class _AnimationEditDialogState extends State<_AnimationEditDialog> {
  late double _duration = widget.animation.duration;
  late double _delay = widget.animation.delay;
  late int _repeat = widget.animation.repeat;
  late bool _autoReverse = widget.animation.autoReverse;
  late AnimationStart _start = widget.animation.start;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Animation'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<AnimationStart>(
              initialValue: _start,
              decoration: const InputDecoration(labelText: 'Start'),
              items: const [
                DropdownMenuItem(value: AnimationStart.onClick, child: Text('On click')),
                DropdownMenuItem(
                    value: AnimationStart.withPrevious, child: Text('With previous')),
                DropdownMenuItem(
                    value: AnimationStart.afterPrevious, child: Text('After previous')),
              ],
              onChanged: (v) => setState(() => _start = v ?? _start),
            ),
            const SizedBox(height: 8),
            Text('Duration: ${_duration.toStringAsFixed(1)}s'),
            Slider(
              value: _duration,
              min: 0.1,
              max: 5,
              onChanged: (v) => setState(() => _duration = v),
            ),
            Text('Delay: ${_delay.toStringAsFixed(1)}s'),
            Slider(
              value: _delay,
              min: 0,
              max: 10,
              onChanged: (v) => setState(() => _delay = v),
            ),
            Row(
              children: [
                const Text('Repeat'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _repeat,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Once')),
                    DropdownMenuItem(value: 1, child: Text('Twice')),
                    DropdownMenuItem(value: 2, child: Text('3 times')),
                    DropdownMenuItem(value: -1, child: Text('Until end')),
                  ],
                  onChanged: (v) => setState(() => _repeat = v ?? 0),
                ),
              ],
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto reverse'),
              value: _autoReverse,
              onChanged: (v) => setState(() => _autoReverse = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.animation.copyWith(
              start: _start,
              duration: _duration,
              delay: _delay,
              repeat: _repeat,
              autoReverse: _autoReverse,
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
