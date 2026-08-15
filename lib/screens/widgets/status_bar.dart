import 'package:flutter/material.dart';

/// Status Bar at the bottom of the editor, similar to PowerPoint's status bar.
/// Shows: slide counter, zoom slider, view mode toggles, auto-save indicator.
class StatusBar extends StatelessWidget {
  final int currentSlide;
  final int totalSlides;
  final double zoomLevel;
  final ValueChanged<double> onZoomChanged;
  final String? autoSaveStatus;
  final String language;
  /// Track 63 (OPT 24): word count of the current slide + deck size in KB.
  final int? wordCount;
  final int? deckSizeBytes;

  const StatusBar({
    super.key,
    required this.currentSlide,
    required this.totalSlides,
    required this.zoomLevel,
    required this.onZoomChanged,
    required this.language,
    this.autoSaveStatus,
    this.wordCount,
    this.deckSizeBytes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Semantics(
        container: true,
        label:
            'Presentation status: slide ${currentSlide > 0 ? currentSlide : 1} of $totalSlides, zoom ${(zoomLevel * 100).round()} percent${autoSaveStatus == null ? '' : ', $autoSaveStatus'}',
        child: Row(
          children: [
            // Slide counter
            Icon(Icons.slideshow, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              totalSlides > 0
                  ? 'Slide ${currentSlide.clamp(1, totalSlides)} / $totalSlides'
                  : 'Slide 0 / 0',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),

            // Word count + deck size (Track 63, OPT 24).
            if (wordCount != null) ...[
              Icon(Icons.notes, size: 12, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                '$wordCount từ',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (deckSizeBytes != null) ...[
              Icon(Icons.data_usage, size: 12, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                '${(deckSizeBytes! / 1024).toStringAsFixed(deckSizeBytes! >= 1024 * 1024 ? 1 : 0)} KB',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
            ],

            // Language indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Vietnamese',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const Spacer(),

            // Auto-save/export indicator.
            // The caller passes PresentationState.exportStatus which uses
            // 'exporting' / 'success' / 'error' — comparing against those
            // (previously the widget compared 'saving'/'saved', which never
            // matched, so every export showed the red "Error" icon).
            if (autoSaveStatus != null) ...[
              Icon(
                autoSaveStatus == 'exporting'
                    ? Icons.sync
                    : autoSaveStatus == 'success'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                size: 12,
                color: autoSaveStatus == 'success'
                    ? Colors.green
                    : autoSaveStatus == 'exporting'
                        ? Colors.orange
                        : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                autoSaveStatus == 'exporting'
                    ? 'Đang xuất...'
                    : autoSaveStatus == 'success'
                        ? 'Đã xuất'
                        : autoSaveStatus == 'error'
                            ? 'Lỗi'
                            : 'Đã lưu',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Zoom controls
            IconButton(
              icon: Icon(Icons.remove,
                  size: 12, color: theme.colorScheme.onPrimaryContainer),
              onPressed: () => onZoomChanged((zoomLevel - 0.1).clamp(0.5, 2.0)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            ),

            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.outlineVariant,
                  thumbColor: theme.colorScheme.primary,
                ),
                child: Slider(
                  value: zoomLevel,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: onZoomChanged,
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.add,
                  size: 12, color: theme.colorScheme.onPrimaryContainer),
              onPressed: () => onZoomChanged((zoomLevel + 0.1).clamp(0.5, 2.0)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            ),

            Text(
              '${(zoomLevel * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(width: 12),

            // View mode toggles
            _viewModeButton(context, Icons.edit_note, 'Normal', true),
            _viewModeButton(context, Icons.grid_view, 'Sorter', false),
            _viewModeButton(context, Icons.auto_stories, 'Reading', false),
          ],
        ),
      ),
    );
  }

  Widget _viewModeButton(
      BuildContext context, IconData icon, String tooltip, bool isActive) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$tooltip view',
      selected: isActive,
      readOnly: true,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: isActive
              ? BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                )
              : null,
          child: Icon(
            icon,
            size: 14,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
