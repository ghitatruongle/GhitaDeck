import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/symbol_service.dart';

/// "Chèn ký hiệu" dialog (Track 18, P5): categorized Unicode symbol table
/// with search and a Unicode code-point lookup box. Returns the selected
/// symbol character, or null when cancelled.
class SymbolDialog extends StatefulWidget {
  const SymbolDialog({super.key});

  @override
  State<SymbolDialog> createState() => _SymbolDialogState();
}

class _SymbolDialogState extends State<SymbolDialog> {
  String _query = '';
  String _category = 'All';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SymbolItem> get _filtered {
    if (_query.trim().isNotEmpty) {
      return SymbolService.search(_query);
    }
    if (_category == 'All') {
      return SymbolService.byCategory.values.expand((e) => e).toList();
    }
    return SymbolService.byCategory[_category] ?? [];
  }

  List<String> get _categories => ['All', ...SymbolService.byCategory.keys];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.abc_outlined),
        const SizedBox(width: 10),
        Text(l.symbol),
      ]),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          children: [
            // Search + unicode code lookup
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '${l.symbolSearch} (e.g. U+221E)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {
                  _query = v;
                  // If the user types a unicode code point, show that symbol.
                  final codeMatch = RegExp(r'U\+([0-9A-Fa-f]{2,6})').firstMatch(v);
                  if (codeMatch != null) {
                    final code = int.tryParse(codeMatch.group(1)!, radix: 16);
                    if (code != null && code > 0) {
                      _query = String.fromCharCode(code);
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            // Category chips
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final cat in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Symbol grid
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text(l.symbolNoResults))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        childAspectRatio: 1,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _symbolTile(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }

  Widget _symbolTile(SymbolItem item) {
    return Tooltip(
      message: '${item.name} (U+${item.char.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')})',
      child: GestureDetector(
        onTap: () => Navigator.pop(context, item.char),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              item.char,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}