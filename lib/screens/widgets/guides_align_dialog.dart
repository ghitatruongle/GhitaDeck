import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drawn_shape.dart';
import '../../models/guide_settings.dart';
import '../../providers/presentation_state.dart';
import '../../services/alignment_service.dart';

/// Align & Distribute tools plus canvas aids (guides / snap / grid / ruler)
/// — Track 27. Operates on the currently selected shapes.
class GuidesAlignDialog extends StatefulWidget {
  /// Shape ids currently selected on the canvas.
  final List<String> selectedShapeIds;

  const GuidesAlignDialog({super.key, this.selectedShapeIds = const []});

  @override
  State<GuidesAlignDialog> createState() => _GuidesAlignDialogState();
}

class _GuidesAlignDialogState extends State<GuidesAlignDialog> {
  late GuideSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<PresentationState>().deckMeta.guides;
  }

  List<DrawnShape> _currentShapes(PresentationState state) {
    final raw = state.currentSlide?.visualElements['shapes'];
    if (raw is! List) return [];
    return raw
        .map((e) => e is Map<String, dynamic>
            ? DrawnShape.fromMap(e)
            : (e is Map
                ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<DrawnShape>()
        .toList();
  }

  void _applyAlign(BuildContext context, AlignKind kind, {bool toSelection = false}) {
    final state = context.read<PresentationState>();
    final shapes = _currentShapes(state);
    final targets = widget.selectedShapeIds.isEmpty
        ? shapes
        : shapes.where((s) => widget.selectedShapeIds.contains(s.id)).toList();
    if (targets.isEmpty) return;
    final items = [
      for (final s in targets)
        Alignable(id: s.id, x: s.x, y: s.y, w: s.w, h: s.h),
    ];
    final ref = toSelection ? AlignmentService.bboxOf(items) : null;
    final out = AlignmentService.align(items, kind: kind, relativeTo: ref);
    final byId = {for (final o in out) o.id: o};
    state.updateShapes([
      for (final s in shapes)
        byId.containsKey(s.id)
            ? s.copyWith(x: byId[s.id]!.x, y: byId[s.id]!.y)
            : s,
    ]);
  }

  void _applyDistribute(BuildContext context, DistributeKind kind) {
    final state = context.read<PresentationState>();
    final shapes = _currentShapes(state);
    final targets = widget.selectedShapeIds.isEmpty
        ? shapes
        : shapes.where((s) => widget.selectedShapeIds.contains(s.id)).toList();
    if (targets.length < 3) return;
    final items = [
      for (final s in targets)
        Alignable(id: s.id, x: s.x, y: s.y, w: s.w, h: s.h),
    ];
    final out = AlignmentService.distribute(items, kind: kind);
    final byId = {for (final o in out) o.id: o};
    state.updateShapes([
      for (final s in shapes)
        byId.containsKey(s.id)
            ? s.copyWith(x: byId[s.id]!.x, y: byId[s.id]!.y)
            : s,
    ]);
  }

  void _saveSettings() {
    context.read<PresentationState>().updateGuideSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Align & Guides'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Align', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _alignBtn(Icons.format_align_left, 'Left', AlignKind.left, false),
                _alignBtn(Icons.format_align_center, 'Center', AlignKind.centerH, false),
                _alignBtn(Icons.format_align_right, 'Right', AlignKind.right, false),
                _alignBtn(Icons.vertical_align_top, 'Top', AlignKind.top, false),
                _alignBtn(Icons.vertical_align_center, 'Middle', AlignKind.middle, false),
                _alignBtn(Icons.vertical_align_bottom, 'Bottom', AlignKind.bottom, false),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _alignBtn(Icons.space_bar, 'Left to selection', AlignKind.left, true),
                _alignBtn(Icons.swap_horiz, 'Center to selection', AlignKind.centerH, true),
                _alignBtn(Icons.swap_vert, 'Middle to selection', AlignKind.middle, true),
              ],
            ),
            const SizedBox(height: 12),
            Text('Distribute', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                _distBtn(Icons.view_column, 'Horizontally', DistributeKind.horizontal),
                _distBtn(Icons.view_agenda, 'Vertically', DistributeKind.vertical),
              ],
            ),
            const Divider(height: 24),
            Text('Canvas aids', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Snap to shape'),
              value: _settings.snapToShape,
              onChanged: (v) => setState(() {
                _settings = _settings.copyWith(snapToShape: v ?? true);
                _saveSettings();
              }),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Snap to grid'),
              value: _settings.snapToGrid,
              onChanged: (v) => setState(() {
                _settings = _settings.copyWith(snapToGrid: v ?? true);
                _saveSettings();
              }),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Show gridlines'),
              value: _settings.showGrid,
              onChanged: (v) => setState(() {
                _settings = _settings.copyWith(showGrid: v ?? false);
                _saveSettings();
              }),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Show ruler'),
              value: _settings.showRuler,
              onChanged: (v) => setState(() {
                _settings = _settings.copyWith(showRuler: v ?? true);
                _saveSettings();
              }),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Show guides'),
              value: _settings.showGuides,
              onChanged: (v) => setState(() {
                _settings = _settings.copyWith(showGuides: v ?? true);
                _saveSettings();
              }),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Guides', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add vertical guide at 50%',
                  onPressed: () {
                    setState(() {
                      _settings = _settings.copyWith(guides: [
                        ..._settings.guides,
                        const GuideLine(position: 50, horizontal: false),
                      ]);
                      _saveSettings();
                    });
                  },
                ),
              ],
            ),
            for (final g in _settings.guides)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  g.horizontal ? Icons.swap_vert : Icons.swap_horiz,
                  size: 16,
                ),
                title: Text(
                  '${g.horizontal ? 'Y' : 'X'} = ${g.position.toStringAsFixed(1)}%'
                  '${g.locked ? '  🔒' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(g.locked ? Icons.lock : Icons.lock_open, size: 15),
                      onPressed: () => setState(() {
                        _settings = _settings.copyWith(guides: [
                          for (final x in _settings.guides)
                            if (identical(x, g)) x.copyWith(locked: !x.locked) else x,
                        ]);
                        _saveSettings();
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 15),
                      onPressed: () => setState(() {
                        _settings = _settings.copyWith(guides: [
                          for (final x in _settings.guides)
                            if (!identical(x, g)) x,
                        ]);
                        _saveSettings();
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _alignBtn(IconData icon, String label, AlignKind kind, bool toSelection) =>
      Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: () => _applyAlign(context, kind, toSelection: toSelection),
        ),
      );

  Widget _distBtn(IconData icon, String label, DistributeKind kind) => Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: () => _applyDistribute(context, kind),
        ),
      );
}
