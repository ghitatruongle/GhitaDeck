import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/zoom_feature_service.dart';

/// "Chèn Slide Zoom / Section Zoom" dialog (Track 20, P5/P6): two modes.
///
///  * **Slide Zoom** returns a [ZoomItem] (single target slide).
///  * **Section/Summary Zoom** returns a [SectionZoomData] — a grid of tiles
///    built from the slides the user checks.
///
/// Returns null when cancelled.
class ZoomDialog extends StatefulWidget {
  final int slideCount;
  const ZoomDialog({super.key, required this.slideCount});

  @override
  State<ZoomDialog> createState() => _ZoomDialogState();
}

class _ZoomDialogState extends State<ZoomDialog> {
  bool _sectionMode = false;
  int _targetSlide = 0;
  String _frameStyle = 'simple';
  String _label = '';
  int _columns = 2;
  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();
    // Pre-select the first two slides so the grid is never empty.
    if (widget.slideCount >= 1) _selected.add(0);
    if (widget.slideCount >= 2) _selected.add(1);
  }

  Object? _buildResult() {
    if (!_sectionMode) {
      return ZoomItem(
        targetSlide: _targetSlide,
        frameStyle: _frameStyle,
        thumbnailLabel: _label,
      );
    }
    final sorted = _selected.toList()..sort();
    return SectionZoomData(
      entries: [
        for (final s in sorted)
          SectionZoomEntry(label: 'Slide ${s + 1}', slide: s),
      ],
      columns: _columns,
      frameStyle: _frameStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.zoom_in_outlined),
        const SizedBox(width: 10),
        Text(l.zoom),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode toggle
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l.zoomSlide),
                  icon: const Icon(Icons.center_focus_strong, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l.zoomSection),
                  icon: const Icon(Icons.dashboard, size: 16),
                ),
              ],
              selected: {_sectionMode},
              onSelectionChanged: (s) =>
                  setState(() => _sectionMode = s.first),
            ),
            const SizedBox(height: 12),
            if (!_sectionMode) ...[
              // Target slide
              DropdownButtonFormField<int>(
                initialValue: _targetSlide,
                decoration: InputDecoration(
                  labelText: l.zoomTargetSlide,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (var i = 0; i < widget.slideCount; i++)
                    DropdownMenuItem(value: i, child: Text('Slide ${i + 1}')),
                ],
                onChanged: (v) => setState(() => _targetSlide = v ?? 0),
              ),
            ] else ...[
              Text(l.zoomPickSlides,
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
              const SizedBox(height: 6),
              // Slide multi-select (compact list)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.slideCount; i++)
                        CheckboxListTile(
                          value: _selected.contains(i),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text('Slide ${i + 1}',
                              style: const TextStyle(fontSize: 13)),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(i);
                            } else {
                              _selected.remove(i);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Columns
              Row(children: [
                Text(l.zoomColumns, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 10),
                for (final c in [1, 2, 3, 4])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$c'),
                      selected: _columns == c,
                      onSelected: (_) => setState(() => _columns = c),
                    ),
                  ),
              ]),
            ],
            const SizedBox(height: 10),
            // Frame style (both modes)
            DropdownButtonFormField<String>(
              initialValue: _frameStyle,
              decoration: InputDecoration(
                labelText: l.zoomFrameStyle,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'simple', child: Text('Simple')),
                DropdownMenuItem(value: 'outline', child: Text('Outline')),
                DropdownMenuItem(value: 'shadow', child: Text('Shadow')),
              ],
              onChanged: (v) => setState(() => _frameStyle = v ?? 'simple'),
            ),
            if (!_sectionMode) ...[
              const SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: _label),
                decoration: InputDecoration(
                  labelText: l.zoomLabel,
                  hintText: l.zoomLabelHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _label = v,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _sectionMode && _selected.length < 2
              ? null
              : () => Navigator.pop(context, _buildResult()),
          child: Text(l.zoomInsert),
        ),
      ],
    );
  }
}
