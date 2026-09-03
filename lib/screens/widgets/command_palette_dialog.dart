import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class CommandPaletteItem {
  final String title;
  final String category;
  final IconData icon;
  final VoidCallback onSelect;

  CommandPaletteItem({
    required this.title,
    required this.category,
    required this.icon,
    required this.onSelect,
  });
}

class CommandPaletteDialog extends StatefulWidget {
  final List<CommandPaletteItem> items;

  const CommandPaletteDialog({super.key, required this.items});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      return item.title.toLowerCase().contains(_query.toLowerCase()) ||
          item.category.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        height: 420,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.commandPaletteHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(context.l10n.commandPaletteEmpty))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        return ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.title),
                          subtitle: Text(item.category),
                          onTap: () {
                            Navigator.pop(context);
                            item.onSelect();
                          },
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
