import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/presentation_state.dart';
import '../../services/accessibility_service.dart';
import '../../services/addin_service.dart';
import '../../services/read_aloud_service.dart';
import '../../services/search_service.dart';
import '../../services/spellcheck_service.dart';
import '../../utils/snackbar_helper.dart';

/// Find & Replace dialog (Track 57, FEAT 94) — Ctrl+F.
class FindReplaceDialog extends StatefulWidget {
  final PresentationState state;

  const FindReplaceDialog({super.key, required this.state});

  @override
  State<FindReplaceDialog> createState() => _FindReplaceDialogState();
}

class _FindReplaceDialogState extends State<FindReplaceDialog> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  bool _caseSensitive = false;
  bool _wholeWord = false;
  List<SearchMatch> _matches = const [];

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  void _run() {
    final slides = _slideMaps();
    final matches = SearchService.findAll(slides, _find.text,
        caseSensitive: _caseSensitive, wholeWord: _wholeWord);
    setState(() {
      _matches = matches;
    });
    if (matches.isNotEmpty) _jump(matches.first.slideIndex);
  }

  List<Map<String, dynamic>> _slideMaps() =>
      [for (final s in widget.state.slides) s.toMap()];

  void _jump(int index) {
    if (index < 0 || index >= widget.state.slides.length) return;
    widget.state.selectSlide(index);
    if (mounted) setState(() {});
  }

  void _replaceAll() {
    if (_find.text.isEmpty) return;
    final slides = _slideMaps();
    final result = SearchService.replaceAll(slides, _find.text, _replace.text,
        caseSensitive: _caseSensitive, wholeWord: _wholeWord);
    if (result.count == 0) {
      if (mounted) {
        showAppSnackBar(context, context.l10n.m9NoMatchesNotice);
      }
      return;
    }
    final state = widget.state;
    for (var i = 0; i < result.slides.length && i < state.slides.length; i++) {
      state.updateSlide(i, Slide.fromMap(result.slides[i]));
    }
    setState(() => _matches = const []);
    if (mounted) {
      showAppSnackBar(context, context.l10n.m9ReplacedCountNotice(result.count));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Find & Replace (Ctrl+F)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _find,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Find',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _run,
                  ),
                ),
                onSubmitted: (_) => _run(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _replace,
                decoration: const InputDecoration(
                  labelText: 'Replace with',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _replaceAll(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  Checkbox(
                    value: _caseSensitive,
                    onChanged: (v) =>
                        setState(() => _caseSensitive = v ?? false),
                  ),
                  const Text('Case sensitive', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: _wholeWord,
                    onChanged: (v) => setState(() => _wholeWord = v ?? false),
                  ),
                  const Text('Whole word', style: TextStyle(fontSize: 12)),
                ],
              ),
              if (_matches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_matches.length} match(es) — slide ${_matches.first.slideIndex + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.find_in_page, size: 16),
                    label: const Text('Find'),
                    onPressed: _run,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Replace all'),
                    onPressed: _replaceAll,
                  ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spellcheck dialog (Track 57, FEAT 92) — scans the current slide.
class SpellcheckDialog extends StatefulWidget {
  final PresentationState state;

  const SpellcheckDialog({super.key, required this.state});

  @override
  State<SpellcheckDialog> createState() => _SpellcheckDialogState();
}

class _SpellcheckDialogState extends State<SpellcheckDialog> {
  List<SpellError> _errors = const [];
  final Map<int, String> _fixes = {};
  final Set<int> _ignores = {};

  void _scan() {
    final slide = widget.state.slides[widget.state.currentSlideIndex];
    final text = slide.htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    setState(() {
      _errors = SpellcheckService.checkText(text);
      _fixes.clear();
      _ignores.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Spell check — ${_errors.length} error(s)',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Scan current slide',
                      onPressed: _scan),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _errors.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_errors.isEmpty
                            ? 'No spelling issues in this slide.'
                            : ''),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _errors.length,
                      itemBuilder: (context, i) {
                        final error = _errors[i];
                        if (_ignores.contains(i)) {
                          return const SizedBox.shrink();
                        }
                        final fix = _fixes[i];
                        return ListTile(
                          dense: true,
                          title: Text(error.word,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  decoration: TextDecoration.underline,
                                  decorationColor:
                                      Theme.of(context).colorScheme.error)),
                          subtitle: fix != null
                              ? Text('→ $fix',
                                  style: const TextStyle(fontSize: 12))
                              : (error.suggestions.isEmpty
                                  ? const Text('No suggestions',
                                      style: TextStyle(fontSize: 12))
                                  : null),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if (error.suggestions.isNotEmpty)
                                DropdownButton<String>(
                                  value: fix,
                                  isDense: true,
                                  hint: const Text('Fix…'),
                                  items: [
                                    for (final s in error.suggestions)
                                      DropdownMenuItem(
                                          value: s, child: Text(s)),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _fixes[i] = v ?? error.word),
                                ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _ignores.add(i)),
                                child: const Text('Ignore'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.spellcheck, size: 16),
                    label: const Text('Apply fixes'),
                    onPressed: _fixes.isEmpty ? null : _applyFixes,
                  ),
                  const Spacer(),
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFixes() {
    final slide = widget.state.slides[widget.state.currentSlideIndex];
    var html = slide.htmlContent;
    // Apply fixes by scanning text nodes in order.
    final text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final errors = SpellcheckService.checkText(text);
    for (var i = 0; i < errors.length; i++) {
      final fix = _fixes[i];
      if (fix == null) continue;
      html = _replaceNthOccurrence(
          html, errors[i].word, fix, _occurrenceIndex(text, errors[i]));
    }
    widget.state.updateSlide(
        widget.state.currentSlideIndex, slide.copyWith(htmlContent: html));
    _scan();
    if (mounted) {
      showAppSnackBar(context, context.l10n.m9FixesAppliedNotice);
    }
  }

  int _occurrenceIndex(String text, SpellError error) {
    var idx = 0;
    var pos = 0;
    while (true) {
      final i = text.indexOf(error.word, pos);
      if (i == -1 || i >= error.start) return idx;
      idx++;
      pos = i + 1;
    }
  }

  String _replaceNthOccurrence(String html, String word, String fix, int n) {
    var count = 0;
    return html.replaceAllMapped(word, (m) {
      if (count++ == n) return fix;
      return m.group(0)!;
    });
  }
}

/// Accessibility panel (Track 58, FEAT 95) — list of issues + one-tap fix.
class AccessibilityPanel extends StatefulWidget {
  final PresentationState state;

  const AccessibilityPanel({super.key, required this.state});

  @override
  State<AccessibilityPanel> createState() => _AccessibilityPanelState();
}

class _AccessibilityPanelState extends State<AccessibilityPanel> {
  List<Issue> _issues = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _issues = AccessibilityService.checkDeck(
          [for (final s in widget.state.slides) s.toMap()]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Accessibility Checker — ${_issues.length} issue(s)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Re-check',
                    onPressed: _refresh,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _issues.isEmpty
                  ? const Center(
                      child: Text('No accessibility issues found 🎉'))
                  : ListView.builder(
                      itemCount: _issues.length,
                      itemBuilder: (context, i) {
                        final issue = _issues[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            switch (issue.type) {
                              'alt' => Icons.image_not_supported_outlined,
                              'contrast' => Icons.contrast,
                              _ => Icons.format_list_numbered,
                            },
                            color: issue.type == 'alt'
                                ? Colors.orange
                                : issue.type == 'contrast'
                                    ? Colors.red
                                    : Colors.blue,
                          ),
                          title: Text(
                            'Slide ${issue.slideIndex + 1}: ${issue.message}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: issue.type == 'alt' ||
                                  issue.type == 'contrast'
                              ? TextButton(
                                  onPressed: () {
                                    final slideMap = widget
                                        .state.slides[issue.slideIndex]
                                        .toMap();
                                    final fixed = AccessibilityService.applyFix(
                                        slideMap, issue);
                                    widget.state.updateSlide(
                                        issue.slideIndex, Slide.fromMap(fixed));
                                    _refresh();
                                  },
                                  child: const Text('Fix'),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Export report'),
                    onPressed: () {
                      final report = AccessibilityService.report(_issues,
                          slideCount: widget.state.slides.length);
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Accessibility report'),
                          content: SingleChildScrollView(
                            child: SelectableText(report),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-in manager dialog (Track 61, FEAT 98).
class AddinManagerDialog extends StatefulWidget {
  final PresentationState state;

  const AddinManagerDialog({super.key, required this.state});

  @override
  State<AddinManagerDialog> createState() => _AddinManagerDialogState();
}

class _AddinManagerDialogState extends State<AddinManagerDialog> {
  List<AddinInfo> _addins = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AddinService.loadAddins();
    if (mounted) setState(() => _addins = list);
  }

  Future<void> _install() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Install add-in (JSON)'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '{"id":"kpi","name":"KPI","handler":"kpi","code":""}',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Install')),
        ],
      ),
    );
    if (json == null || json.isEmpty || !mounted) return;
    final info = await AddinService.installFromJson(json);
    if (info == null) {
      setState(
          () => _error = 'Invalid add-in JSON or remote sources are blocked.');
      return;
    }
    await AddinService.setEnabled(info.id, true);
    await _load();
  }

  Future<void> _run(AddinInfo addin) async {
    final slides = [for (final s in widget.state.slides) s.toMap()];
    final result = AddinService.runHandler(addin, slides);
    var added = 0;
    if (result.add.isNotEmpty) {
      for (final slide in result.add) {
        widget.state.addSlide(Slide.fromMap(slide));
        added++;
      }
    }
    for (final update in result.update) {
      final index = update['index'] as int?;
      final slide = update['slide'] as Map?;
      if (index != null &&
          slide != null &&
          index >= 0 &&
          index < widget.state.slides.length) {
        widget.state.updateSlide(
            index, Slide.fromMap(Map<String, dynamic>.from(slide)));
      }
    }
    if (mounted) {
      showAppSnackBar(context, context.l10n.m9AddinRanNotice(addin.name, result.update.length, added));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Add-in Manager',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Install',
                      onPressed: _install),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12)),
              ),
            const Divider(height: 1),
            Expanded(
              child: _addins.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No add-ins installed. Add-in JSON files live in the app\'s addins/ folder.'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _addins.length,
                      itemBuilder: (context, i) {
                        final addin = _addins[i];
                        return ListTile(
                          dense: true,
                          leading: Switch(
                            value: addin.enabled,
                            onChanged: (v) async {
                              await AddinService.setEnabled(addin.id, v);
                              await _load();
                            },
                          ),
                          title: Text('${addin.name} v${addin.version}',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(addin.description.isEmpty
                              ? 'handler: ${addin.handler}'
                              : addin.description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (addin.enabled)
                                TextButton(
                                    onPressed: () => _run(addin),
                                    child: const Text('Run')),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Uninstall',
                                onPressed: () async {
                                  await AddinService.uninstall(addin.id);
                                  await _load();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-aloud control bar (Track 62, FEAT 100) — docked bar under the editor.
class ReadAloudBar extends StatefulWidget {
  final PresentationState state;

  const ReadAloudBar({super.key, required this.state});

  @override
  State<ReadAloudBar> createState() => _ReadAloudBarState();
}

class _ReadAloudBarState extends State<ReadAloudBar> {
  final ReadAloudService _service = ReadAloudService();
  bool _listening = false;
  double _rate = 0.0;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _service.removeListener(_onChanged);
    _service.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final slides = [for (final s in widget.state.slides) s.toMap()];
    if (slides.isEmpty) return;
    setState(() => _listening = true);
    // Poll UI while the deck reads.
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
    await _service.speakDeck(slides,
        startIndex: widget.state.currentSlideIndex,
        rate: _rate,
        locale: context.l10n.localeName.contains('vi') ? 'vi' : 'en');
    _uiTimer?.cancel();
    _uiTimer = null;
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _stop() async {
    _uiTimer?.cancel();
    _uiTimer = null;
    await _service.stop();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.record_voice_over,
                size: 18, color: _listening ? Colors.red : null),
            const SizedBox(width: 8),
            if (_listening)
              Text(
                  'Reading slide ${_service.currentIndex + 1}/${_service.totalSlides}',
                  style: const TextStyle(fontSize: 12))
            else
              const Text('Read aloud', style: TextStyle(fontSize: 12)),
            const Spacer(),
            if (_listening) ...[
              IconButton(
                  icon: const Icon(Icons.pause_circle_outline, size: 20),
                  tooltip: 'Pause',
                  onPressed: _service.paused ? null : _service.pause),
              IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  tooltip: 'Resume',
                  onPressed: _service.paused ? _service.resume : null),
            ],
            IconButton(
              icon: const Icon(Icons.fast_forward, size: 20),
              tooltip: 'Speed: slow / normal / fast',
              onPressed: () {
                setState(() {
                  _rate = _rate <= -1 ? 0.0 : (_rate >= 1 ? -2.0 : 2.0);
                });
              },
            ),
            IconButton(
              icon: _listening
                  ? const Icon(Icons.stop, size: 20)
                  : const Icon(Icons.play_arrow, size: 20),
              tooltip: _listening ? 'Stop' : 'Read from current slide',
              onPressed: _listening ? _stop : _start,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
