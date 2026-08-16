import 'package:flutter/material.dart';
import '../../services/template_service.dart';
import '../../models/slide_template.dart';
import '../l10n/l10n.dart';

/// Template Studio — v1.2.0: Dynamic grid from TemplateService (20 templates, 6 categories)
class TemplateStudioScreen extends StatefulWidget {
  /// Callback when a template is applied (returns the template's HTML content).
  final void Function(SlideTemplate template)? onApplyTemplate;

  const TemplateStudioScreen({super.key, this.onApplyTemplate});

  @override
  State<TemplateStudioScreen> createState() => _TemplateStudioScreenState();
}

class _TemplateStudioScreenState extends State<TemplateStudioScreen> {
  final TemplateService _templateService = TemplateService();
  List<SlideTemplate> _allTemplates = [];
  List<SlideTemplate> _filteredTemplates = [];
  List<String> _categories = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _templateService.loadTemplates();
      final categories = await _templateService.getCategories();
      if (mounted) {
        setState(() {
          _allTemplates = templates;
          _filteredTemplates = templates;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterTemplates() {
    setState(() {
      _filteredTemplates = _allTemplates.where((t) {
        final matchesCategory = _selectedCategory == 'All' || t.category == _selectedCategory;
        final matchesSearch = _searchQuery.isEmpty ||
            t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.description.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ['All', ..._categories.where((c) => c != 'All')];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.style, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Thư Viện Template',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text('${_filteredTemplates.length} templates'),
                  avatar: const Icon(Icons.grid_view, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.templateSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterTemplates();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                _searchQuery = v;
                _filterTemplates();
              },
            ),
            const SizedBox(height: 12),

            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = cat);
                        _filterTemplates();
                      },
                      avatar: Icon(_categoryIcon(cat), size: 16),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Template grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTemplates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
                              const SizedBox(height: 12),
                              const Text('Không tìm thấy template phù hợp'),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredTemplates.length,
                          itemBuilder: (ctx, idx) {
                            final t = _filteredTemplates[idx];
                            return _buildTemplateCard(context, t, idx);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, SlideTemplate template, int index) {
    final theme = Theme.of(context);
    final accentColor = template.accentColor;

    return Card(
      key: ValueKey(template.name),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showTemplateDetail(context, template),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview header with accent color
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                ),
              ),
              child: Center(
                child: Icon(
                  template.icon,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          template.category,
                          style: TextStyle(fontSize: 9, color: accentColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Sử dụng', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        widget.onApplyTemplate?.call(template);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã áp dụng template: ${template.name}')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateDetail(BuildContext context, SlideTemplate template) {
    final theme = Theme.of(context);
    final accentColor = template.accentColor;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.7)]),
                ),
                child: Row(
                  children: [
                    Icon(
                      template.icon,
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(template.category, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.description, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      // HTML preview
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HTML Preview:', style: theme.textTheme.labelSmall),
                            const SizedBox(height: 8),
                            Text(
                              template.htmlContent.length > 300
                                  ? '${template.htmlContent.substring(0, 300)}...'
                                  : template.htmlContent,
                              style: const TextStyle(fontFamily: 'Consolas', fontSize: 10),
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Đóng'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Áp dụng Template'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onApplyTemplate?.call(template);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã áp dụng template: ${template.name}')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'All': return Icons.apps;
      case 'Corporate': return Icons.business;
      case 'Creative': return Icons.palette;
      case 'Education': return Icons.school;
      case 'Technology': return Icons.computer;
      case 'Data': return Icons.bar_chart;
      case 'Special': return Icons.star;
      default: return Icons.folder;
    }
  }
}
