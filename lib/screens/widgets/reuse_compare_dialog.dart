import 'package:flutter/material.dart';
import '../../providers/presentation_state.dart';
import '../../services/reuse_slide_service.dart';
import '../../services/compare_merge_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../l10n/l10n.dart';

/// Reuse & Compare/Merge dialog (Track 51, FEAT 85/86).
///
/// Two tabs:
/// * **Reuse** — paste a `.ghita` bundle (or plain text/HTML) and insert the
///   parsed slides into the deck, keeping original formatting or re-theming.
/// * **Compare/Merge** — paste two bundle versions side by side; the diff is
///   listed per slide and the user picks A / B / both per position.
class ReuseCompareDialog extends StatefulWidget {
  final PresentationState state;

  const ReuseCompareDialog({super.key, required this.state});

  @override
  State<ReuseCompareDialog> createState() => _ReuseCompareDialogState();
}

class _ReuseCompareDialogState extends State<ReuseCompareDialog> {
  int _tab = 0;
  final _reuseController = TextEditingController();
  List<Map<String, dynamic>> _parsedReuse = [];
  bool _keepOriginal = true;
  String? _parseError;

  final _aController = TextEditingController();
  final _bController = TextEditingController();
  List<SlideDiff>? _diffs;
  final Map<int, String> _choices = {};
  String? _compareError;

  @override
  void dispose() {
    _reuseController.dispose();
    _aController.dispose();
    _bController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.file_copy_outlined),
                            label: Text('Reuse slides')),
                        ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.merge_type),
                            label: Text('Compare / Merge')),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: _tab == 0
                  ? _buildReuseTab()
                  : _buildCompareTab(),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Reuse tab
  // -------------------------------------------------------------------------

  Widget _buildReuseTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
              'Paste a .ghita bundle (JSON) or plain text/HTML. '
              'Slides are split on --- separators or h1/h2 headings.'),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _reuseController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"slides": [{"title": "...", "htmlContent": "<h1>…</h1>"}]}',
              ),
              onChanged: (_) => setState(() {
                _parsedReuse = [];
                _parseError = null;
              }),
            ),
          ),
          if (_parseError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_parseError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _keepOriginal,
                onChanged: (v) => setState(() => _keepOriginal = v ?? true),
              ),
              const Expanded(child: Text('Keep original formatting')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _parseReuse,
                child: const Text('Parse'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _parsedReuse.isEmpty
                      ? 'No slides parsed yet'
                      : '${_parsedReuse.length} slide(s) ready',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              FilledButton.icon(
                onPressed: _parsedReuse.isEmpty ? null : _insertReuse,
                icon: const Icon(Icons.add),
                label: const Text('Insert into deck'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _parseReuse() {
    final text = _reuseController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parseError = 'Paste something first.';
        _parsedReuse = [];
      });
      return;
    }
    final bundle = ReuseSlideService.parseBundle(text);
    if (bundle.error == null && bundle.slides.isNotEmpty) {
      setState(() {
        _parsedReuse = bundle.slides;
        _parseError = null;
      });
      return;
    }
    final fromText = ReuseSlideService.slidesFromText(text);
    setState(() {
      _parsedReuse = fromText;
      _parseError = fromText.isEmpty ? 'Could not parse any slides.' : null;
    });
  }

  void _insertReuse() {
    final state = widget.state;
    var inserted = 0;
    for (final raw in _parsedReuse) {
      final slide = _keepOriginal
          ? ReuseSlideService.keepOriginal(raw)
          : ReuseSlideService.useCurrentTheme(raw);
      state.addSlide(Slide(
        title: (slide['title'] ?? 'Imported').toString(),
        htmlContent: (slide['htmlContent'] ?? '<h1></h1>').toString(),
      ));
      inserted++;
    }
    showAppSnackBar(context, context.l10n.reuseInsertedNotice(inserted));
    Navigator.pop(context);
  }

  // -------------------------------------------------------------------------
  // Compare / Merge tab
  // -------------------------------------------------------------------------

  Widget _buildCompareTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Version A (.ghita JSON)',
                  ),
                  onChanged: (_) => setState(() => _diffs = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _bController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Version B (.ghita JSON)',
                  ),
                  onChanged: (_) => setState(() => _diffs = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _compare,
                child: const Text('Compare'),
              ),
              const Spacer(),
              if (_diffs != null)
                Text(
                  '${_diffs!.where((d) => d.kind != 'same').length} '
                  'difference(s)',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          if (_compareError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_compareError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _diffs == null
                ? const Center(child: Text('Paste two versions and press Compare'))
                : ListView(
                    children: [
                      for (final d in _diffs!)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              switch (d.kind) {
                                'added' => Icons.add_circle_outline,
                                'removed' => Icons.remove_circle_outline,
                                'changed' => Icons.edit_outlined,
                                _ => Icons.check_circle_outline,
                              },
                              color: switch (d.kind) {
                                'added' => Colors.green,
                                'removed' => Colors.red,
                                'changed' => Colors.orange,
                                _ => Colors.grey,
                              },
                            ),
                            title: Text(
                              '#${d.index + 1} '
                              '${switch (d.kind) {
                                'added' => 'added: ${d.titleB}',
                                'removed' => 'removed: ${d.titleA}',
                                'changed' => '"${d.titleA}" → "${d.titleB}"',
                                _ => 'same: ${d.titleA}',
                              }}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: d.kind == 'changed'
                                ? Text(
                                    '+${d.addedCount} / -${d.removedCount} words',
                                    style: const TextStyle(fontSize: 11))
                                : null,
                            trailing: d.kind == 'same'
                                ? const Text('—')
                                : DropdownButton<String>(
                                    value: _choices[d.index] ?? 'A',
                                    isDense: true,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'A', child: Text('A')),
                                      DropdownMenuItem(
                                          value: 'B', child: Text('B')),
                                      DropdownMenuItem(
                                          value: 'both', child: Text('Both')),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _choices[d.index] = v ?? 'A'),
                                  ),
                          ),
                        ),
                    ],
                  ),
          ),
          FilledButton.icon(
            onPressed: _diffs == null ? null : _merge,
            icon: const Icon(Icons.merge),
            label: const Text('Merge into deck'),
          ),
        ],
      ),
    );
  }

  void _compare() {
    final a = CompareMergeService.parseBundleSlides(_aController.text);
    final b = CompareMergeService.parseBundleSlides(_bController.text);
    if (a.isEmpty || b.isEmpty) {
      setState(() {
        _compareError = 'Both fields need valid .ghita bundles with slides.';
        _diffs = null;
      });
      return;
    }
    final diffs = CompareMergeService.compare(a, b);
    setState(() {
      _diffs = diffs;
      _compareError = null;
      _choices.clear();
    });
  }

  void _merge() {
    final a = CompareMergeService.parseBundleSlides(_aController.text);
    final b = CompareMergeService.parseBundleSlides(_bController.text);
    if (a.isEmpty || b.isEmpty) return;
    final result = CompareMergeService.merge(a, b, _choices);
    final state = widget.state;
    for (final slide in result.slides) {
      state.addSlide(Slide(
        title: (slide['title'] ?? 'Merged').toString(),
        htmlContent: (slide['htmlContent'] ?? '').toString(),
      ));
    }
    showAppSnackBar(context, context.l10n.m9MergedSummaryNotice(
        result.slides.length, result.fromA, result.fromB, result.both));
    Navigator.pop(context);
  }
}
