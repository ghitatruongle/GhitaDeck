import 'package:flutter/material.dart';
import '../../providers/presentation_state.dart';
import '../../services/designer_service.dart';

/// Designer panel (Track 54, FEAT 87) — docked right pane proposing local
/// layout transformations for the current slide. Apply is one tap; the
/// original slide is kept for manual undo.
class DesignerPanel extends StatefulWidget {
  final PresentationState state;

  const DesignerPanel({super.key, required this.state});

  @override
  State<DesignerPanel> createState() => _DesignerPanelState();
}

class _DesignerPanelState extends State<DesignerPanel> {
  String _accent = '#1F4E79';
  bool _dark = false;
  String? _appliedSuggestionId;

  Slide? get _slide {
    final i = widget.state.currentSlideIndex;
    if (i < 0 || i >= widget.state.slides.length) return null;
    return widget.state.slides[i];
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slide;
    if (slide == null) {
      return const _PanelFrame(
        title: 'Designer',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select a slide to see design ideas'),
          ),
        ),
      );
    }

    final suggestions = DesignerService.suggest(slide.htmlContent, accent: _accent);
    return _PanelFrame(
      title: 'Designer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                DropdownButton<String>(
                  value: _accent,
                  isDense: true,
                  items: [
                    for (final c in DesignerService.accentPalette)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _accent = v ?? _accent),
                ),
                FilterChip(
                  label: const Text('Dark'),
                  selected: _dark,
                  onSelected: (v) => setState(() => _dark = v),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: suggestions.length,
              itemBuilder: (context, i) {
                final s = suggestions[i];
                var html = s.html;
                if (_dark) html = DesignerService.applyDarkVariant(html);
                final preview = Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _apply(s.id, s.html),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(s.description,
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 6),
                          _HtmlThumbnail(html: html),
                        ],
                      ),
                    ),
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    if (_appliedSuggestionId == s.id)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextButton.icon(
                          icon: const Icon(Icons.undo, size: 14),
                          label: const Text('Undo design'),
                          onPressed: _undo,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _apply(String id, String html) {
    final i = widget.state.currentSlideIndex;
    final slide = _slide;
    if (slide == null) return;
    widget.state.updateSlide(
        i, slide.copyWith(htmlContent: html, layoutType: 'designer'));
    setState(() => _appliedSuggestionId = id);
  }

  void _undo() {
    final i = widget.state.currentSlideIndex;
    final slide = _slide;
    if (slide == null) return;
    widget.state.updateSlide(
        i, slide.copyWith(layoutType: 'standard'));
    setState(() => _appliedSuggestionId = null);
  }
}

class _HtmlThumbnail extends StatelessWidget {
  final String html;
  const _HtmlThumbnail({required this.html});

  @override
  Widget build(BuildContext context) {
    final clean = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        clean.isEmpty ? '(content)' : clean,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}

class _PanelFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _PanelFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
