import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/icon_item.dart';
import '../../services/icon_library_service.dart';

/// "Chèn Icon" dialog (Track 15, P2): search, category filter, colour picker
/// and size slider — returns an [IconItem] or null.
class IconDialog extends StatefulWidget {
  const IconDialog({super.key});

  @override
  State<IconDialog> createState() => _IconDialogState();
}

class _IconDialogState extends State<IconDialog> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Color _selectedColor = const Color(0xFF000000);
  int _size = 48;
  final _searchController = TextEditingController();
  final _recentIcons = <IconItem>[];

  List<IconItem> get _filtered {
    final all = IconLibraryService.iconsByCategory;
    if (_selectedCategory == 'All') {
      final list = _searchQuery.trim().isEmpty
          ? all.values.expand((e) => e).toList()
          : IconLibraryService.search(_searchQuery);
      return list;
    }
    final icons = all[_selectedCategory] ?? [];
    if (_searchQuery.trim().isEmpty) return icons;
    final q = _searchQuery.toLowerCase();
    return icons.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  List<String> get _categories =>
      ['All', ...IconLibraryService.iconsByCategory.keys];

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
        const Icon(Icons.emoji_symbols_outlined),
        const SizedBox(width: 10),
        Text(l.insertIcon),
      ]),
      content: SizedBox(
        width: 620,
        height: 480,
        child: Column(
          children: [
            // Search + category filter
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.iconSearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 8),
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
            // Recent icons
            if (_recentIcons.isNotEmpty) ...[
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Text(l.iconRecent, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final icon in _recentIcons)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _iconTile(icon),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Icon grid
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text(l.iconNoResults))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        childAspectRatio: 1,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _iconTile(_filtered[i]),
                    ),
            ),
            // Colour + size controls
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l.iconColor, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                for (final swatch in const [
                  Color(0xFF000000),
                  Color(0xFFFF0000),
                  Color(0xFFFF8C00),
                  Color(0xFFFFD93D),
                  Color(0xFF6BCB77),
                  Color(0xFF3A8FD4),
                  Color(0xFF7A5CD0),
                  Color(0xFFFFFFFF),
                ])
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = swatch),
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == swatch
                              ? Colors.black
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Text('${_size}px', style: const TextStyle(fontSize: 12)),
                SizedBox(
                  width: 80,
                  child: Slider(
                    value: _size.toDouble(),
                    min: 16,
                    max: 96,
                    divisions: 10,
                    label: '$_size',
                    onChanged: (v) => setState(() => _size = v.round()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => _insertIcon(context),
          child: Text(l.insertIcon),
        ),
      ],
    );
  }

  String get _colorHex =>
      '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Widget _iconTile(IconItem icon) {
    final colorHex = _colorHex;
    final preview = icon.copyWith(color: colorHex, size: _size);
    return Tooltip(
      message: icon.name,
      child: GestureDetector(
        onTap: () {
          // Insert on tap
          Navigator.pop(context, preview);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Image.memory(
                  IconLibraryService.renderPng(
                    icon.copyWith(color: colorHex),
                    size: 24,
                  ),
                  width: 20,
                  height: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                icon.name,
                style: const TextStyle(fontSize: 7),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _insertIcon(BuildContext context) {
    final colorHex = _colorHex;
    Navigator.pop(context, _filtered.isNotEmpty
        ? _filtered.first.copyWith(color: colorHex, size: _size)
        : null);
  }
}