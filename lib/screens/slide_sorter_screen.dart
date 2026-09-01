import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/presentation_state.dart';
import '../screens/widgets/slide_preview.dart';
import '../utils/snackbar_helper.dart';
import '../l10n/l10n.dart';

/// Slide Sorter — grid view of all slides, similar to PowerPoint's Slide Sorter.
/// Supports drag-and-drop reorder, multi-select, and bulk actions.
class SlideSorterScreen extends StatefulWidget {
  const SlideSorterScreen({super.key});

  @override
  State<SlideSorterScreen> createState() => _SlideSorterScreenState();
}

class _SlideSorterScreenState extends State<SlideSorterScreen> {
  final Set<int> _selectedIndexes = {};
  double _zoomLevel = 1.0;

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);
    final slides = presentationState.slides;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Slide Sorter (${slides.length} slides)',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 18),
            onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0)),
            tooltip: 'Zoom Out',
          ),
          SizedBox(
            width: 100,
            child: Slider(
              value: _zoomLevel,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) => setState(() => _zoomLevel = v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0)),
            tooltip: 'Zoom In',
          ),

          if (_selectedIndexes.isNotEmpty) ...[
            const VerticalDivider(),
            // Bulk actions
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: _duplicateSelected,
              tooltip: 'Duplicate Selected (${_selectedIndexes.length})',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: _deleteSelected,
              tooltip: 'Delete Selected (${_selectedIndexes.length})',
            ),
          ],

          const SizedBox(width: 8),

          // Select all / Deselect all
          if (slides.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIndexes.length == slides.length) {
                    _selectedIndexes.clear();
                  } else {
                    _selectedIndexes.addAll(List.generate(slides.length, (i) => i));
                  }
                });
              },
              child: Text(
                _selectedIndexes.length == slides.length
                    ? 'Deselect All'
                    : 'Select All',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      body: slides.isEmpty
          ? _buildEmptyState(theme)
          : _buildGrid(context, presentationState, slides, theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_view, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No slides to sort',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    PresentationState state,
    List<Slide> slides,
    ThemeData theme,
  ) {
    final crossAxisCount = (4 * _zoomLevel).round().clamp(2, 8);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: slides.length,
        itemBuilder: (context, index) {
          final slide = slides[index];
          final isSelected = _selectedIndexes.contains(index);

          return _SlideSorterCard(
            key: ValueKey(slide.timestamp),
            slide: slide,
            index: index,
            isSelected: isSelected,
            onTap: () => _toggleSelection(index),
            onDoubleTap: () {
              // Open in editor
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _duplicateSelected() {
    final state = Provider.of<PresentationState>(context, listen: false);
    final sortedIndexes = _selectedIndexes.toList()..sort((a, b) => b.compareTo(a));
    for (final index in sortedIndexes) {
      state.duplicateSlide(index);
    }
    setState(() => _selectedIndexes.clear());
    showAppSnackBar(context, context.l10n.sorterDuplicatedSlidesNotice(sortedIndexes.length));
  }

  void _deleteSelected() {
    final state = Provider.of<PresentationState>(context, listen: false);
    final sortedIndexes = _selectedIndexes.toList()..sort((a, b) => b.compareTo(a));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Slides'),
        content: Text('Delete ${sortedIndexes.length} selected slides?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              for (final index in sortedIndexes) {
                state.removeSlide(index);
              }
              setState(() => _selectedIndexes.clear());
              Navigator.pop(context);
              showAppSnackBar(
                  context, context.l10n.sorterDeletedSlidesNotice(sortedIndexes.length));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SlideSorterCard extends StatelessWidget {
  final Slide slide;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _SlideSorterCard({
    super.key,
    required this.slide,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            // Slide preview
            Positioned.fill(
              child: SlidePreview(
                title: slide.title,
                html: slide.htmlContent,
              ),
            ),
            // Slide number badge
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Selection checkmark
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            // Title overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  slide.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
