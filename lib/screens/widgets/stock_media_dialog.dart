import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/stock_media_service.dart';

/// "Chèn ảnh kho" dialog (Track 15, P5): browse CC0-style vector illustrations
/// by category, preview, then insert the selected SVG as a data-URI `<img>`.
class StockMediaDialog extends StatefulWidget {
  const StockMediaDialog({super.key});

  @override
  State<StockMediaDialog> createState() => _StockMediaDialogState();
}

class _StockMediaDialogState extends State<StockMediaDialog> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  List<StockMediaItem> get _filtered {
    final all = StockMediaService.byCategory;
    if (_selectedCategory == 'All') {
      final list = _searchQuery.trim().isEmpty
          ? all.values.expand((e) => e).toList()
          : StockMediaService.search(_searchQuery);
      return list;
    }
    final items = all[_selectedCategory] ?? [];
    if (_searchQuery.trim().isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  List<String> get _categories =>
      ['All', ...StockMediaService.byCategory.keys];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.image_outlined),
        const SizedBox(width: 10),
        Text(l.insertStockMedia),
      ]),
      content: SizedBox(
        width: 640,
        height: 480,
        child: Column(
          children: [
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.mediaSearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
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
                        selected: _selectedCategory == cat,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Grid
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text(l.mediaNoResults))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _mediaTile(_filtered[i]),
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

  Widget _mediaTile(StockMediaItem item) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, item),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.memory(
                // Use memory image from the SVG data URI — Flutter doesn't
                // natively render SVG, so we show a coloured placeholder badge.
                Uint8List(0), // empty — we'll use a Container fallback
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEEF2F7),
                  child: Center(
                    child: Text(
                      item.category,
                      style: const TextStyle(
                        color: Color(0xFF3A8FD4),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: Colors.grey.shade100,
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}