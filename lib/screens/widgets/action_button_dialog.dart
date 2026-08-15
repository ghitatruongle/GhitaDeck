import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/action_button_service.dart';

/// "Chèn nút hành động" dialog (Track 18, P1–P2).
class ActionButtonDialog extends StatefulWidget {
  const ActionButtonDialog({super.key});

  @override
  State<ActionButtonDialog> createState() => _ActionButtonDialogState();
}

class _ActionButtonDialogState extends State<ActionButtonDialog> {
  ActionButtonKind _kind = ActionButtonKind.next;
  ActionType _action = ActionType.slideNext;
  String _label = '';
  String _url = '';
  String _color = '#4472C4';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.touch_app_outlined),
        const SizedBox(width: 10),
        Text(l.actionButton),
      ]),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kind
              DropdownButtonFormField<ActionButtonKind>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: l.actionButtonKind,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final k in ActionButtonKind.values)
                    DropdownMenuItem(value: k, child: Text(k.name)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? ActionButtonKind.custom),
              ),
              const SizedBox(height: 8),
              // Action
              DropdownButtonFormField<ActionType>(
                initialValue: _action,
                decoration: InputDecoration(
                  labelText: l.actionButtonAction,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final a in ActionType.values)
                    DropdownMenuItem(value: a, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _action = v ?? ActionType.slideNext),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _label),
                decoration: InputDecoration(
                  labelText: l.actionButtonLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _label = v,
              ),
              const SizedBox(height: 8),
              if (_action == ActionType.url) ...[
                TextField(
                  controller: TextEditingController(text: _url),
                  decoration: InputDecoration(
                    labelText: l.actionButtonUrl,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _url = v,
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _color),
                decoration: InputDecoration(
                  labelText: l.actionButtonColor,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _color = v.isEmpty ? '#4472C4' : v,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ActionButton(
            kind: _kind,
            action: _action,
            label: _label,
            url: _url,
            color: _color,
          )),
          child: Text(l.actionButtonInsert),
        ),
      ],
    );
  }
}