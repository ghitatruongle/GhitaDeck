import 'package:flutter/material.dart';
import '../../services/ribbon_config_service.dart';

/// Ribbon / QAT customization dialog (Track 60, FEAT 97).
///
/// Two lists: available commands (left) and QAT commands (right); move
/// commands between them. Tabs can be added/removed/reset. Config persists
/// via [RibbonConfigService] and can be exported/imported as JSON.
class RibbonCustomizeDialog extends StatefulWidget {
  const RibbonCustomizeDialog({super.key});

  @override
  State<RibbonCustomizeDialog> createState() => _RibbonCustomizeDialogState();
}

class _RibbonCustomizeDialogState extends State<RibbonCustomizeDialog> {
  List<String> _qat = [];
  List<RibbonTab> _tabs = [];
  List<String> _pool = [];
  String _tabName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final qat = await RibbonConfigService.loadQat();
    final tabs = await RibbonConfigService.loadTabs();
    final used = <String>{...qat, for (final t in tabs) for (final g in t.groups) ...g.commands};
    final pool = RibbonConfigService.allCommands
        .where((c) => !used.contains(c))
        .toList();
    if (mounted) {
      setState(() {
        _qat = qat;
        _tabs = tabs;
        _pool = pool;
      });
    }
  }

  Future<void> _save() async {
    await RibbonConfigService.saveQat(_qat);
    await RibbonConfigService.saveTabs(_tabs);
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Customize Ribbon & Quick Access Toolbar',
                        style: Theme.of(context).textTheme.titleMedium),
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
              child: Row(
                children: [
                  Expanded(
                    child: _CommandList(
                      title: 'Available commands',
                      commands: _pool,
                      emptyHint: 'All commands are on the ribbon/QAT.',
                      onMove: (c) {
                        setState(() {
                          _pool.remove(c);
                          _qat.add(c);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CommandList(
                      title: 'Quick Access Toolbar',
                      commands: _qat,
                      emptyHint: 'QAT is empty.',
                      onMove: (c) {
                        setState(() {
                          _qat.remove(c);
                          _pool.add(c);
                        });
                      },
                      onRemove: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Add a custom tab.
                  SizedBox(
                    width: 180,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'New tab name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _tabName = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _tabName.trim().isEmpty
                        ? null
                        : () {
                            setState(() {
                              _tabs.add(RibbonTab(
                                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                name: _tabName.trim(),
                              ));
                              _tabName = '';
                            });
                          },
                    child: const Text('Add tab'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        if (_tabs.isNotEmpty) _tabs.removeLast();
                      });
                    },
                    child: const Text('Remove last tab'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      await RibbonConfigService.resetTabs();
                      await RibbonConfigService.resetQat();
                      await _load();
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      await _save();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandList extends StatelessWidget {
  final String title;
  final List<String> commands;
  final String emptyHint;
  final void Function(String) onMove;
  final bool onRemove;

  const _CommandList({
    required this.title,
    required this.commands,
    required this.emptyHint,
    required this.onMove,
    this.onRemove = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: commands.isEmpty
                ? Center(
                    child: Text(emptyHint,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: commands.length,
                    itemBuilder: (context, i) {
                      final cmd = commands[i];
                      return ListTile(
                        dense: true,
                        title: Text(cmd, style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: Icon(
                              onRemove ? Icons.arrow_back : Icons.arrow_forward,
                              size: 18),
                          tooltip: onRemove ? 'Remove from QAT' : 'Add to QAT',
                          onPressed: () => onMove(cmd),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
