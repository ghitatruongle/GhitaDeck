import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/smartart.dart';
import '../../services/smartart_service.dart';

/// "Chèn SmartArt" dialog (Track 10, P5–P7): pick a layout by group, edit
/// the node texts (text pane), choose a colour theme, then insert or replace
/// a diagram — all three export formats read the same `data-smartart` block.
class SmartArtDialog extends StatefulWidget {
  const SmartArtDialog({super.key, this.currentHtml = '', this.editIndex});

  final String currentHtml;
  final int? editIndex;

  @override
  State<SmartArtDialog> createState() => _SmartArtDialogState();
}

class _SmartArtDialogState extends State<SmartArtDialog> {
  late SmartArtGraph _graph;
  late final List<TextEditingController> _nodeTexts;
  late final TextEditingController _title;
  late List<SmartArtGraph> _existing;

  @override
  void initState() {
    super.initState();
    _existing = SmartArtService.diagramsIn(widget.currentHtml);
    final initial = (widget.editIndex != null &&
            widget.editIndex! < _existing.length)
        ? _existing[widget.editIndex!]
        : SmartArtGraph.sample(SmartArtLayout.basicProcess);
    _graph = initial;
    _title = TextEditingController(text: initial.title);
    _nodeTexts = [
      for (final n in initial.orderedNodes) TextEditingController(text: n.text),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _nodeTexts) {
      c.dispose();
    }
    super.dispose();
  }

  SmartArtGraph get _draft => _graph.copyWith(
        title: _title.text.trim(),
        nodes: [
          for (var i = 0; i < _nodeTexts.length; i++)
            SmartArtNode(id: i + 1, text: _nodeTexts[i].text),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_tree_outlined),
          const SizedBox(width: 10),
          Text(widget.editIndex == null ? l.insertSmartArt : l.editSmartArt),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_existing.isNotEmpty) ...[
                Text(l.smartartExisting,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: widget.editIndex,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 0; i < _existing.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                            '${_existing[i].layout.name} — ${_existing[i].title}'),
                      ),
                  ],
                  onChanged: (i) {
                    if (i != null) Navigator.of(context).pop('edit:$i');
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l.smartartTitle,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(l.smartartLayouts,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              // Layout thumbnails grouped by the 8 PowerPoint groups.
              for (final group in SmartArtGroup.values) ...[
                Text(
                  _groupName(l, group),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final layout in SmartArtLayout.values)
                      if (layout.group == group)
                        _LayoutThumb(
                          layout: layout,
                          selected: _graph.layout == layout,
                          onTap: () => setState(() {
                            // Relayout keeps the node texts (P6).
                            _graph = _graph.relayout(layout);
                          }),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(l.smartartColorTheme,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final theme in SmartArtColorTheme.values)
                    ChoiceChip(
                      label: Text(theme.label,
                          style: const TextStyle(fontSize: 11)),
                      selected: _graph.colorTheme == theme,
                      onSelected: (_) => setState(() => _graph =
                          _graph.copyWith(colorTheme: theme)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.smartartNodes,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (var i = 0; i < _nodeTexts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${i + 1}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _nodeTexts[i],
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            hintText: '${l.smartartNode} ${i + 1}',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _nodeTexts.length > 1
                            ? () => setState(() => _nodeTexts
                                .removeAt(i)
                                .dispose())
                            : null,
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _nodeTexts
                    .add(TextEditingController(text: 'Mục ${_nodeTexts.length + 1}'))),
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.smartartAddNode),
              ),
              const SizedBox(height: 12),
              Text(l.chartPreview,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: CustomPaint(
                  painter: _SmartArtPreviewPainter(_draft),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: Text(widget.editIndex == null
              ? context.l10n.insertSmartArt
              : context.l10n.smartartUpdated),
          onPressed: () => Navigator.pop(context, _draft),
        ),
      ],
    );
  }

  static String _groupName(AppLocalizations l, SmartArtGroup group) =>
      switch (group) {
        SmartArtGroup.list => l.smartartGroupList,
        SmartArtGroup.process => l.smartartGroupProcess,
        SmartArtGroup.cycle => l.smartartGroupCycle,
        SmartArtGroup.hierarchy => l.smartartGroupHierarchy,
        SmartArtGroup.relationship => l.smartartGroupRelationship,
        SmartArtGroup.matrix => l.smartartGroupMatrix,
        SmartArtGroup.pyramid => l.smartartGroupPyramid,
        SmartArtGroup.picture => l.smartartGroupPicture,
      };
}

class _LayoutThumb extends StatelessWidget {
  const _LayoutThumb({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final SmartArtLayout layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 76,
        height: 52,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            layout.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8),
          ),
        ),
      ),
    );
  }
}

/// Live preview painted with the theme palette.
class _SmartArtPreviewPainter extends CustomPainter {
  _SmartArtPreviewPainter(this.graph);

  final SmartArtGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = graph.orderedNodes;
    if (nodes.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final n = math.max(nodes.length, 1);
    Color colorAt(int i) =>
        Color(int.parse('FF${graph.colorTheme.colorAt(i)}', radix: 16));
    final paint = Paint();

    void box(int i, double x, double y, double bw, double bh) {
      paint.color = colorAt(i);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, bw, bh), const Radius.circular(5)),
          paint);
    }

    switch (graph.layout.group) {
      case SmartArtGroup.list:
      case SmartArtGroup.relationship:
        final slotH = h / n;
        for (var i = 0; i < nodes.length; i++) {
          box(i, w * 0.1, i * slotH + 4, w * 0.8, slotH - 8);
        }
      case SmartArtGroup.process:
        final slotW = w / n;
        for (var i = 0; i < nodes.length; i++) {
          box(i, i * slotW + 4, h * 0.3, slotW - 8, h * 0.4);
        }
      case SmartArtGroup.cycle:
        final cx = w / 2;
        final cy = h / 2;
        final r = math.min(w, h) / 2 - 16;
        for (var i = 0; i < nodes.length; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / n;
          box(i, cx + math.cos(a) * r - 16, cy + math.sin(a) * r - 10, 32, 20);
        }
      case SmartArtGroup.hierarchy:
        final top = nodes.where((x) => x.parentId == null).toList();
        if (top.isNotEmpty) {
          box(0, w / 2 - 40, 8, 80, 28);
          final kids = graph.childrenOf(top.first.id);
          for (var i = 0; i < kids.length; i++) {
            box(i + 1, 10 + i * (w - 20) / math.max(kids.length, 1),
                h - 40, (w - 20) / math.max(kids.length, 1) - 8, 30);
          }
        }
      case SmartArtGroup.matrix:
        for (var i = 0; i < nodes.length; i++) {
          box(i, 8 + (i % 2) * (w / 2), h / 2 - 26 + (i ~/ 2) * 30,
              w / 2 - 16, 26);
        }
      case SmartArtGroup.pyramid:
        final slotH = h / n;
        for (var i = 0; i < nodes.length; i++) {
          final frac = (n - i) / n;
          paint.color = colorAt(i);
          final path = Path()
            ..moveTo(w / 2 - w * frac / 2, i * slotH)
            ..lineTo(w / 2 + w * frac / 2, i * slotH)
            ..lineTo(w / 2 + w * frac * 0.4, (i + 1) * slotH)
            ..lineTo(w / 2 - w * frac * 0.4, (i + 1) * slotH)
            ..close();
          canvas.drawPath(path, paint);
        }
      case SmartArtGroup.picture:
        final slotH = h / n;
        for (var i = 0; i < nodes.length; i++) {
          box(i, 8, i * slotH + 4, 40, slotH - 8);
          box(i, 56, i * slotH + 4, w - 64, slotH - 8);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _SmartArtPreviewPainter oldDelegate) =>
      oldDelegate.graph != graph;
}