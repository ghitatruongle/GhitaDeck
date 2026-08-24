import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/mermaid_diagram_service.dart';

/// Accent presets offered in the diagram dialog (Track: T05).
const _accentPresets = <String>[
  '#3B82F6', // blue
  '#10B981', // green
  '#8B5CF6', // purple
  '#F59E0B', // amber
];

enum _DiagramMode { flowchart, mindmap }

/// "Insert Diagram" dialog (T05): build a flowchart or a mindmap block with
/// themed accents, preview its structure live, then hand the generated HTML
/// back to the caller (the ribbon pipes it into the editor via insertHtml).
class DiagramDialog extends StatefulWidget {
  const DiagramDialog({super.key});

  @override
  State<DiagramDialog> createState() => _DiagramDialogState();
}

class _DiagramDialogState extends State<DiagramDialog> {
  _DiagramMode _mode = _DiagramMode.flowchart;
  String _accent = _accentPresets.first;
  final _topic = TextEditingController(text: 'Chủ đề');
  final _steps = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final _subtopics = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  List<TextEditingController> get _activeFields =>
      _mode == _DiagramMode.flowchart ? _steps : _subtopics;

  String get _previewHtml => _mode == _DiagramMode.flowchart
      ? MermaidDiagramService()
          .generateFlowchartHtml(_nonEmpty(_steps), accentColor: _accent)
      : MermaidDiagramService()
          .generateMindmapHtml(_topic.text, _nonEmpty(_subtopics),
              accentColor: _accent);

  List<String> _nonEmpty(List<TextEditingController> controllers) =>
      controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

  void _addField() {
    setState(() => _activeFields.add(TextEditingController()));
  }

  // Removed fields retire here so their controllers are disposed exactly
  // once, after the outgoing TextField has fully unmounted.
  final _retired = <TextEditingController>[];

  void _removeLastField() {
    if (_activeFields.length <= 2) return;
    setState(() => _retired.add(_activeFields.removeLast()));
  }

  @override
  void dispose() {
    _topic.dispose();
    for (final c in [..._steps, ..._subtopics, ..._retired]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.diagramDialogTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_DiagramMode>(
                segments: [
                  ButtonSegment(
                    value: _DiagramMode.flowchart,
                    icon: const Icon(Icons.account_tree),
                    label: Text(l10n.diagramModeFlowchart),
                  ),
                  ButtonSegment(
                    value: _DiagramMode.mindmap,
                    icon: const Icon(Icons.hub),
                    label: Text(l10n.diagramModeMindmap),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 12),
              if (_mode == _DiagramMode.mindmap) ...[
                TextField(
                  controller: _topic,
                  decoration:
                      InputDecoration(labelText: l10n.diagramTopicLabel),
                ),
                const SizedBox(height: 8),
              ],
              Text(l10n.diagramAccentLabel,
                  style: const TextStyle(fontSize: 12)),
              Row(
                children: [
                  for (final preset in _accentPresets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        key: Key('accent-$preset'),
                        onTap: () => setState(() => _accent = preset),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(int.parse(preset.substring(1),
                                    radix: 16) |
                                0xFF000000),
                            shape: BoxShape.circle,
                            border: _accent == preset
                                ? Border.all(width: 3, color: Colors.black87)
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_mode == _DiagramMode.flowchart)
                Text(l10n.diagramStepsLabel,
                    style: const TextStyle(fontSize: 12))
              else
                Text(l10n.diagramSubtopicsLabel,
                    style: const TextStyle(fontSize: 12)),
              for (final field in _activeFields)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextField(
                    controller: field,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: _mode == _DiagramMode.flowchart
                          ? const Icon(Icons.looks_one, size: 18)
                          : const Icon(Icons.label_outline, size: 18),
                    ),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _addField,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(_mode == _DiagramMode.flowchart
                        ? l10n.diagramAddStep
                        : l10n.diagramAddSubtopic),
                  ),
                  TextButton.icon(
                    onPressed: _removeLastField,
                    icon: const Icon(Icons.remove, size: 18),
                    label: Text(l10n.diagramRemoveField),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(l10n.diagramPreviewLabel,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              _StructurePreview(
                html: _previewHtml,
                mode: _mode,
                accent: _accent,
                items: _nonEmpty(_activeFields),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton.icon(
          // Dead-looking clicks confuse users: with no content the button
          // stays visibly disabled instead of silently doing nothing.
          onPressed:
              _previewHtml.isEmpty ? null : () => Navigator.of(context).pop(_previewHtml),
          icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
          label: Text(l10n.diagramInsert),
        ),
      ],
    );
  }
}

/// Structural mirror of the generated block: same numbering and accent as
/// the HTML that will be inserted, rendered with native widgets so the user
/// previews exactly what exports will carry.
class _StructurePreview extends StatelessWidget {
  const _StructurePreview({
    required this.html,
    required this.mode,
    required this.accent,
    required this.items,
  });

  final String html;
  final _DiagramMode mode;
  final String accent;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        Color(int.parse(accent.substring(1), radix: 16) | 0xFF000000);
    Widget content;
    if (items.isEmpty || html.isEmpty) {
      content = Text('—',
          style: TextStyle(color: Theme.of(context).hintColor));
    } else if (mode == _DiagramMode.flowchart) {
      content = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Chip(
              backgroundColor: accentColor,
              labelStyle: const TextStyle(color: Colors.white),
              label: Text('${i + 1}. ${items[i]}'),
            ),
            if (i < items.length - 1) const Text('➔'),
          ],
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            backgroundColor: Colors.blueGrey,
            labelStyle: const TextStyle(color: Colors.white),
            label: Text(context.l10n.diagramCentralChip),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final item in items)
                Chip(
                  backgroundColor: accentColor,
                  labelStyle: const TextStyle(color: Colors.white),
                  label: Text(item),
                ),
            ],
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}
