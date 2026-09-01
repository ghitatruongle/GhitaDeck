import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/presentation_state.dart';
import '../../screens/widgets/slide_preview.dart';
import '../../l10n/l10n.dart';
import '../../services/thumbnail_service.dart';
import '../../utils/snackbar_helper.dart';
import '../editor/editor_state.dart';

/// Left panel showing slide thumbnails with drag-to-reorder,
/// similar to PowerPoint's slide thumbnail sidebar.
class SlideListPanel extends StatelessWidget {
  final VoidCallback onAddSlide;
  final VoidCallback onClearAll;

  const SlideListPanel({
    super.key,
    required this.onAddSlide,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);
    final editorState = Provider.of<EditorState>(context);
    final slides = presentationState.slides;
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: context.l10n.slideListSemantics(slides.length),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Semantics(
              header: true,
              label: context.l10n.slideListSemantics(slides.length),
              child: ExcludeSemantics(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.slideshow,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.l10n.slideCount(slides.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: context.l10n.addSlideTooltip,
                        onPressed: onAddSlide,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Slide list
            Expanded(
              child: slides.isEmpty
                  ? _buildEmptyState(context)
                  : _buildSlideList(
                      context, presentationState, editorState, slides),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _footerButton(
                    context,
                    icon: Icons.add_circle_outline,
                    tooltip: 'New Slide',
                    onPressed: onAddSlide,
                  ),
                  _footerButton(
                    context,
                    icon: Icons.copy,
                    tooltip: 'Duplicate',
                    onPressed: editorState.selectedSlideIndex >= 0
                        ? () => presentationState
                            .duplicateSlide(editorState.selectedSlideIndex)
                        : null,
                  ),
                  _footerButton(
                    context,
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: Colors.red,
                    onPressed: editorState.selectedSlideIndex >= 0
                        ? () => _deleteSlideWithUndo(context, presentationState,
                            editorState.selectedSlideIndex)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.slideshow, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'No slides yet',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.clickToAddSlide,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideList(
    BuildContext context,
    PresentationState presentationState,
    EditorState editorState,
    List<Slide> slides,
  ) {
    return ReorderableListView.builder(
      itemCount: slides.length,
      onReorderItem: (oldIndex, newIndex) {
        presentationState.moveSlide(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = _lerpDouble(0, 6, animation.value);
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final slide = slides[index];
        final isSelected = index == editorState.selectedSlideIndex;

        return _SlideThumbnailCard(
          // timestamp is documented as the stable identity of a slide — do
          // NOT include the index or every reorder/delete rebuilds the list
          // with fresh keys (kills drag animations, loses drag tracking).
          key: ValueKey(slide.timestamp),
          slide: slide,
          index: index,
          isSelected: isSelected,
          onTap: () {
            presentationState.setCurrentSlide(index);
            editorState.selectSlide(index);
            editorState.editSlide(index, presentationState);
          },
          onDuplicate: () => presentationState.duplicateSlide(index),
          onDelete: () =>
              _deleteSlideWithUndo(context, presentationState, index),
          onPreview: () => _previewSlide(context, slide),
        );
      },
    );
  }

  void _deleteSlideWithUndo(
      BuildContext context, PresentationState state, int index) {
    final slide = state.slides[index];
    final title = slide.title;
    final editorState = Provider.of<EditorState>(context, listen: false);
    state.removeSlide(index);
    // Fix up any selection/editing referencing the deleted slide so we never
    // update a different slide or touch an out-of-range index.
    editorState.handleSlideRemoved(index, state.slides.length);

    showAppSnackBar(
      context,
      context.l10n.deletedWithUndo(title),
      duration: const Duration(seconds: 3),
      actionLabel: context.l10n.undoAction,
      onAction: () {
        // Restore at the ORIGINAL position (not appended at the end).
        state.insertSlide(
            index,
            slide.copyWith(
                timestamp: DateTime.now().millisecondsSinceEpoch));
      },
    );
  }

  void _previewSlide(BuildContext context, Slide slide) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 800,
          height: 480,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(slide.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child:
                      SlidePreview(title: slide.title, html: slide.htmlContent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Individual slide thumbnail card with number badge and context menu.
class _SlideThumbnailCard extends StatelessWidget {
  final Slide slide;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  const _SlideThumbnailCard({
    super.key,
    required this.slide,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: context.l10n.slideSemanticLabel(index + 1, slide.title),
      hint: context.l10n.slideSemanticHint,
      button: true,
      selected: isSelected,
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2 : 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showContextMenu(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Slide number badge + thumbnail
                Stack(
                  children: [
                    // Thumbnail preview area
                    Container(
                      height: 80,
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      child: Center(
                        child: _buildMiniThumbnail(context),
                      ),
                    ),
                    // Slide number badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    // Transition effect indicator
                    if (slide.effect != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.animation,
                            size: 10,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                // Title + structure chips
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slide.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _buildStructureChips(slide.htmlContent, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// LRU-ish cache: re-rendering on every rebuild janks scrolling (Track 64).
  static final Map<int, Uint8List> _thumbCache = {};
  static const int _thumbCacheMax = 60;

  Uint8List? _cachedThumb() {
    final key = slide.hashCode;
    final hit = _thumbCache[key];
    if (hit != null) return hit;
    final bytes = ThumbnailService.renderThumbnail(slide);
    if (bytes != null) {
      _thumbCache[key] = bytes;
      if (_thumbCache.length > _thumbCacheMax) {
        _thumbCache.remove(_thumbCache.keys.first);
      }
    }
    return bytes;
  }

  Widget _buildMiniThumbnail(BuildContext context) {
    final html = slide.htmlContent;
    final theme = Theme.of(context);

    // Track 64: real rendered thumbnail when available; fall back to the
    // layout placeholder so the list never blocks or shows empty boxes.
    final thumb = _cachedThumb();
    if (thumb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.memory(
          thumb,
          gaplessPlayback: true,
          fit: BoxFit.contain,
          width: double.infinity,
          height: 72,
        ),
      );
    }

    // Simple text-based thumbnail preview
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (html.contains('<h1'))
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(height: 4),
          if (html.contains('<h2'))
            Container(
              height: 4,
              width: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 3,
            width: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 3,
            width: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructureChips(String html, ThemeData theme) {
    final h1 = _countTag(html, 'h1');
    final h2 = _countTag(html, 'h2');
    final li = _countTag(html, 'li');
    final hasTable = html.contains('<table');

    final chips = <Widget>[];
    if (h1 > 0) chips.add(_chip('H1', Colors.deepOrange, theme));
    if (h2 > 0) chips.add(_chip('H2', Colors.orange, theme));
    if (li > 0) chips.add(_chip('$li●', Colors.green, theme));
    if (hasTable) chips.add(_chip('▦', Colors.purple, theme));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 3,
      runSpacing: 1,
      children: chips,
    );
  }

  Widget _chip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  int _countTag(String html, String tag) {
    return RegExp('<$tag[\\s>]', caseSensitive: false).allMatches(html).length;
  }

  void _showContextMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'edit', child: Text('Edit Slide')),
        const PopupMenuItem<String>(
            value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem<String>(value: 'preview', child: Text('Preview')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'edit':
          onTap();
          break;
        case 'duplicate':
          onDuplicate();
          break;
        case 'preview':
          onPreview();
          break;
        case 'delete':
          onDelete();
          break;
      }
    });
  }
}
