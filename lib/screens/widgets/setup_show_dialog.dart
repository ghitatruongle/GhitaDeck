import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/custom_show.dart';
import '../../services/setup_show_service.dart';

/// Result of the Set Up Show dialog.
class SetupShowResult {
  final SetupShowSettings settings;
  final CustomShow? customShow;

  const SetupShowResult({required this.settings, this.customShow});
}

/// "Set Up Show" dialog (Track 36, P2–P5): presentation mode, options,
/// default pen colour, and optional custom show. Returns a [SetupShowResult].
Future<SetupShowResult?> showSetupShowDialog(
  BuildContext context, {
  required SetupShowSettings initial,
  required List<CustomShow> customShows,
  required int slideCount,
}) {
  return showDialog<SetupShowResult>(
    context: context,
    builder: (_) => _SetupShowDialog(
      initial: initial,
      customShows: customShows,
      slideCount: slideCount,
    ),
  );
}

class _SetupShowDialog extends StatefulWidget {
  final SetupShowSettings initial;
  final List<CustomShow> customShows;
  final int slideCount;

  const _SetupShowDialog({
    required this.initial,
    required this.customShows,
    required this.slideCount,
  });

  @override
  State<_SetupShowDialog> createState() => _SetupShowDialogState();
}

class _SetupShowDialogState extends State<_SetupShowDialog> {
  late ShowMode _mode;
  late bool _loop;
  late bool _noNarration;
  late bool _noAnimation;
  late int _advance;
  late String _penColor;
  CustomShow? _selectedShow;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _loop = widget.initial.loopContinuously;
    _noNarration = widget.initial.showWithoutNarration;
    _noAnimation = widget.initial.showWithoutAnimation;
    _advance = widget.initial.advanceSeconds;
    _penColor = widget.initial.penColorHex;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.setupShowTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.setupShowMode,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _modeTile(ShowMode.presenter, l10n.setupShowModePresenter,
                  Icons.present_to_all),
              _modeTile(ShowMode.browsed, l10n.setupShowModeBrowsed,
                  Icons.window),
              _modeTile(ShowMode.kiosk, l10n.setupShowModeKiosk, Icons.lock),
              const Divider(height: 20),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.setupShowLoop, style: const TextStyle(fontSize: 13)),
                value: _loop,
                onChanged: (v) => setState(() => _loop = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.setupShowNoNarration,
                    style: const TextStyle(fontSize: 13)),
                value: _noNarration,
                onChanged: (v) => setState(() => _noNarration = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.setupShowNoAnimation,
                    style: const TextStyle(fontSize: 13)),
                value: _noAnimation,
                onChanged: (v) => setState(() => _noAnimation = v ?? false),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(l10n.setupShowAdvance,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _advance,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Off')),
                      DropdownMenuItem(value: 5, child: Text('5 s')),
                      DropdownMenuItem(value: 10, child: Text('10 s')),
                      DropdownMenuItem(value: 30, child: Text('30 s')),
                      DropdownMenuItem(value: 60, child: Text('60 s')),
                    ],
                    onChanged: (v) => setState(() => _advance = v ?? 0),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(l10n.setupShowPenColor,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final hex in const [
                    '#ED1C24', '#FF7F27', '#FFF200', '#22B14C',
                    '#00A2E8', '#3F48CC', '#FFFFFF', '#000000',
                  ])
                    InkWell(
                      onTap: () => setState(() => _penColor = hex),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _parseHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _penColor == hex
                                ? Colors.lightBlueAccent
                                : Colors.grey.shade600,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 20),
              Text(l10n.setupShowCustomShow,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<CustomShow>(
                initialValue: _selectedShow,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                hint: Text(l10n.setupShowCustomShowAll,
                    style: const TextStyle(fontSize: 13)),
                items: [
                  for (final show in widget.customShows)
                    DropdownMenuItem(
                      value: show,
                      child: Text(show.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedShow = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final settings = SetupShowSettings(
              mode: _mode,
              loopContinuously: _loop,
              showWithoutNarration: _noNarration,
              showWithoutAnimation: _noAnimation,
              advanceSeconds: _advance,
              penColorHex: _penColor,
            );
            Navigator.pop(context, SetupShowResult(
              settings: settings,
              customShow: _selectedShow,
            ));
          },
          child: Text(l10n.startShow),
        ),
      ],
    );
  }

  Widget _modeTile(ShowMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.blue.shade400 : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.blue.shade700 : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    } catch (_) {
      return const Color(0xFFED1C24);
    }
  }
}

/// Custom Shows manager (Track 36, P6): create / rename / delete shows.
Future<List<CustomShow>?> showCustomShowsManager(
  BuildContext context, {
  required List<CustomShow> shows,
  required int slideCount,
  List<String>? slideTitles,
}) {
  return showDialog<List<CustomShow>>(
    context: context,
    builder: (_) => _CustomShowsDialog(
      shows: shows,
      slideCount: slideCount,
      slideTitles: slideTitles ?? const [],
    ),
  );
}

class _CustomShowsDialog extends StatefulWidget {
  final List<CustomShow> shows;
  final int slideCount;
  final List<String> slideTitles;

  const _CustomShowsDialog({
    required this.shows,
    required this.slideCount,
    required this.slideTitles,
  });

  @override
  State<_CustomShowsDialog> createState() => _CustomShowsDialogState();
}

class _CustomShowsDialogState extends State<_CustomShowsDialog> {
  late List<CustomShow> _shows;
  final _nameCtrl = TextEditingController();
  final List<int> _pending = [];

  @override
  void initState() {
    super.initState();
    _shows = List.of(widget.shows);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _createShow() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _pending.isEmpty) return;
    setState(() {
      _shows.add(CustomShow(
        id: 'show_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        slideIndices: List.of(_pending)..sort(),
      ));
      _nameCtrl.clear();
      _pending.clear();
    });
  }

  void _deleteShow(CustomShow show) {
    setState(() => _shows.removeWhere((s) => s.id == show.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.customShowsTitle),
      content: SizedBox(
        width: 440,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.customShowName,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _createShow(),
            ),
            const SizedBox(height: 8),
            Text(l10n.customShowPickSlides,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 48,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: widget.slideCount,
                itemBuilder: (_, i) {
                  final selected = _pending.contains(i);
                  final title = widget.slideTitles.length > i
                      ? widget.slideTitles[i]
                      : 'Slide ${i + 1}';
                  return InkWell(
                    onTap: () => setState(() {
                      final idx = _pending.indexOf(i);
                      if (idx >= 0) {
                        _pending.removeAt(idx);
                      } else {
                        _pending.add(i);
                      }
                      _pending.sort();
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF3A8FD4)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Tooltip(
                        message: title,
                        child: Text('${i + 1}',
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            )),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: _createShow,
                  child: Text(l10n.customShowCreate),
                ),
                if (_pending.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('${_pending.length} slides',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: _shows.isEmpty
                  ? Center(
                      child: Text(l10n.customShowEmpty,
                          style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : ListView.builder(
                      itemCount: _shows.length,
                      itemBuilder: (_, i) {
                        final show = _shows[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.playlist_play, size: 18),
                          title: Text(show.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            '${show.slideIndices.length} / ${widget.slideCount} slides',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () => _deleteShow(show),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _shows),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}
