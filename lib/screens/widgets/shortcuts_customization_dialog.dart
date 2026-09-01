import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/shortcuts_provider.dart';
import '../../utils/keyboard_shortcuts.dart';
import '../../utils/snackbar_helper.dart';
import '../../l10n/l10n.dart';

/// Dialog để user customize keyboard shortcuts
class ShortcutsCustomizationDialog extends StatefulWidget {
  const ShortcutsCustomizationDialog({super.key});

  @override
  State<ShortcutsCustomizationDialog> createState() =>
      _ShortcutsCustomizationDialogState();
}

class _ShortcutsCustomizationDialogState
    extends State<ShortcutsCustomizationDialog> {
  ShortcutAction? _editingAction;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Keyboard Shortcuts'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Consumer<ShortcutsProvider>(
          builder: (context, shortcutsProvider, _) {
            if (!shortcutsProvider.isLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final actions = ShortcutAction.values.toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Action buttons
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset All'),
                      onPressed: () {
                        _showResetConfirmDialog(context, shortcutsProvider);
                      },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export'),
                      onPressed: () => _exportShortcuts(shortcutsProvider),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Import'),
                      onPressed: () => _importShortcuts(shortcutsProvider),
                    ),
                  ],
                ),
                const Divider(),
                // Shortcuts list
                Expanded(
                  child: ListView.builder(
                    itemCount: actions.length,
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      final shortcut = shortcutsProvider.getShortcut(action);
                      final isEditing = _editingAction == action;

                      return Card(
                        key: ValueKey(action),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          title: Text(
                            AppShortcuts.actionLabel(action),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: isEditing
                              ? _buildShortcutRecorder(
                                  context, shortcutsProvider, action)
                              : _buildShortcutDisplay(
                                  context, shortcutsProvider, action, shortcut),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildShortcutDisplay(BuildContext context,
      ShortcutsProvider provider, ShortcutAction action, SingleActivator shortcut) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            AppShortcuts.shortcutToString(shortcut),
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          tooltip: 'Edit shortcut',
          onPressed: () {
            setState(() {
              _editingAction = action;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Reset to default',
          onPressed: () {
            provider.resetToDefault(action);
          },
        ),
      ],
    );
  }

  Widget _buildShortcutRecorder(BuildContext context,
      ShortcutsProvider provider, ShortcutAction action) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          _handleKeyPress(context, provider, action, event);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: Text(
              'Press keys...',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Cancel',
            onPressed: () {
              setState(() {
                _editingAction = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _handleKeyPress(BuildContext context, ShortcutsProvider provider,
      ShortcutAction action, KeyEvent event) {
    // Ignore modifier keys when pressed alone
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight ||
        event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight) {
      return;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    final shortcut = SingleActivator(
      event.logicalKey,
      control: isCtrl,
      shift: isShift,
      alt: isAlt,
    );

    // Check for conflicts
    final conflict = provider.findConflict(action, shortcut);
    if (conflict != null) {
      _showConflictDialog(context, provider, action, shortcut, conflict);
      return;
    }

    // Apply the shortcut
    provider.setShortcut(action, shortcut);
    setState(() {
      _editingAction = null;
    });
  }

  void _showConflictDialog(
      BuildContext context,
      ShortcutsProvider provider,
      ShortcutAction action,
      SingleActivator shortcut,
      ShortcutAction conflictingAction) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Shortcut Conflict'),
        content: Text(
          'The shortcut "${AppShortcuts.shortcutToString(shortcut)}" is already assigned to '
          '"${AppShortcuts.actionLabel(conflictingAction)}".\n\n'
          'Do you want to reassign it to "${AppShortcuts.actionLabel(action)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.setShortcut(action, shortcut);
              setState(() {
                _editingAction = null;
              });
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Reassign'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog(
      BuildContext context, ShortcutsProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset All Shortcuts'),
        content: const Text(
          'Are you sure you want to reset all shortcuts to their default values?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.resetAllToDefaults();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  void _exportShortcuts(ShortcutsProvider provider) {
    try {
      final json = provider.exportToJson();
      Clipboard.setData(ClipboardData(text: json));
      showAppSnackBar(
  context,
  'Shortcuts copied to clipboard!',
  duration: const Duration(seconds: 2)
);
    } catch (e) {
      showAppSnackBar(
  context,
  'Failed to export shortcuts',
  duration: const Duration(seconds: 2)
);
    }
  }

  void _importShortcuts(ShortcutsProvider provider) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return; // dialog may have been closed while awaiting
      if (data?.text != null) {
        final success = provider.importFromJson(data!.text!);
        if (success && mounted) {
          showAppSnackBar(
  context,
  'Shortcuts imported successfully!',
  duration: const Duration(seconds: 2)
);
        } else if (mounted) {
          showAppSnackBar(
  context,
  'Failed to import shortcuts. Invalid format.',
  duration: const Duration(seconds: 2)
);
        }
      } else {
        showAppSnackBar(context, context.l10n.themeClipboardEmptyNotice, duration: const Duration(seconds: 2));
      }
    } catch (e) {
      // importFromJson can throw on malformed JSON — don't crash.
      if (!mounted) return;
      showAppSnackBar(
  context,
  'Failed to import shortcuts. Invalid format.',
  duration: const Duration(seconds: 2)
);
    }
  }
}
