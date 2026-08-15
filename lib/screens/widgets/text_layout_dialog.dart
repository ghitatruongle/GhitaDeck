import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/presentation_state.dart';
import '../../services/text_layout_service.dart';

/// Advanced text tools (Track 28): replace font across the whole deck,
/// change case, character spacing, text direction, autofit, bullets and tab
/// stops for the current slide.
class TextLayoutDialog extends StatefulWidget {
  const TextLayoutDialog({super.key});

  @override
  State<TextLayoutDialog> createState() => _TextLayoutDialogState();
}

class _TextLayoutDialogState extends State<TextLayoutDialog> {
  final _fromFontCtrl = TextEditingController();
  final _toFontCtrl = TextEditingController();
  double _spacingPx = 0;
  String _direction = 'horizontal';
  String _autofit = 'none';
  int _bulletStart = 1;
  int _bulletLevel = 0;
  String _tabStops = '50, 200';
  String _tabLeader = '.';

  @override
  void dispose() {
    _fromFontCtrl.dispose();
    _toFontCtrl.dispose();
    super.dispose();
  }

  void _applyToCurrentSlide(String Function(String html) transform) {
    final state = context.read<PresentationState>();
    final slide = state.currentSlide;
    if (slide == null) return;
    state.updateSlide(
      state.currentSlideIndex,
      slide.copyWith(htmlContent: transform(slide.htmlContent)),
    );
  }

  void _applyToAllSlides(String Function(String html) transform) {
    final state = context.read<PresentationState>();
    final slides = state.slides;
    for (var i = 0; i < slides.length; i++) {
      state.updateSlide(i, slides[i].copyWith(htmlContent: transform(slides[i].htmlContent)));
    }
  }

  void _replaceFontDeckWide() {
    final from = _fromFontCtrl.text.trim();
    final to = _toFontCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both font names')),
      );
      return;
    }
    _applyToAllSlides((html) => TextLayoutService.replaceFont(html, from, to));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Font replaced across the whole deck')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Text Layout Tools'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Replace font (whole deck)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromFontCtrl,
                      decoration: const InputDecoration(
                        labelText: 'From font',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _toFontCtrl,
                      decoration: const InputDecoration(
                        labelText: 'To font',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _replaceFontDeckWide,
                  child: const Text('Replace'),
                ),
              ),
              const Divider(height: 24),
              Text('Change case (current slide)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  _caseBtn('UPPER', 'upper'),
                  _caseBtn('lower', 'lower'),
                  _caseBtn('Title Case', 'title'),
                  _caseBtn('Sentence', 'sentence'),
                  _caseBtn('tOGGLE', 'toggle'),
                ],
              ),
              const Divider(height: 24),
              Text('Character spacing (current slide)', style: theme.textTheme.titleSmall),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _spacingPx,
                      min: -5,
                      max: 20,
                      divisions: 50,
                      label: '${_spacingPx.toStringAsFixed(1)} px',
                      onChanged: (v) => setState(() => _spacingPx = v),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${_spacingPx.toStringAsFixed(1)} px',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _applyToCurrentSlide(
                    (html) => TextLayoutService.setCharacterSpacing(html, _spacingPx),
                  ),
                  child: const Text('Apply'),
                ),
              ),
              const Divider(height: 24),
              Text('Text direction (current slide)', style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 4,
                children: [
                  _dirChip('Horizontal', 'horizontal'),
                  _dirChip('Vertical', 'vertical'),
                  _dirChip('Rotate 90°', 'rotated90'),
                  _dirChip('Rotate 270°', 'rotated270'),
                ],
              ),
              const Divider(height: 24),
              Text('Autofit (current slide)', style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 4,
                children: [
                  _fitChip('None', 'none'),
                  _fitChip('Shrink text on overflow', 'shrink'),
                  _fitChip('Resize shape to fit', 'resizeShape'),
                ],
              ),
              const Divider(height: 24),
              Text('Bullets (current slide)', style: theme.textTheme.titleSmall),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Start at',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _bulletStart = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Indent level',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _bulletLevel = int.tryParse(v) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _applyToCurrentSlide(
                    (html) => TextLayoutService.setBullets(
                      html,
                      startAt: _bulletStart,
                      level: _bulletLevel,
                    ),
                  ),
                  child: const Text('Apply bullets'),
                ),
              ),
              const Divider(height: 24),
              Text('Tab stops (current slide)', style: theme.textTheme.titleSmall),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _tabStops),
                      decoration: const InputDecoration(
                        labelText: 'Positions px (comma-separated)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _tabStops = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _tabLeader,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('None')),
                      DropdownMenuItem(value: '.', child: Text('Dots')),
                      DropdownMenuItem(value: '-', child: Text('Dashes')),
                    ],
                    onChanged: (v) => setState(() => _tabLeader = v ?? ''),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _applyToCurrentSlide(
                    (html) => TextLayoutService.setTabStops(
                      html,
                      [
                        for (final s in _tabStops.split(','))
                          if (double.tryParse(s.trim()) != null) double.parse(s.trim()),
                      ],
                      leader: _tabLeader,
                    ),
                  ),
                  child: const Text('Apply tabs'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _caseBtn(String label, String mode) => OutlinedButton(
        onPressed: () {
          _applyToCurrentSlide((html) => TextLayoutService.changeCase(html, mode));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Case applied: $label'), duration: const Duration(seconds: 1)),
          );
        },
        child: Text(label),
      );

  Widget _dirChip(String label, String mode) => ChoiceChip(
        label: Text(label),
        selected: _direction == mode,
        onSelected: (_) {
          setState(() => _direction = mode);
          _applyToCurrentSlide(
            (html) => TextLayoutService.setTextDirection(html, mode),
          );
        },
      );

  Widget _fitChip(String label, String mode) => ChoiceChip(
        label: Text(label),
        selected: _autofit == mode,
        onSelected: (_) {
          setState(() => _autofit = mode);
          _applyToCurrentSlide((html) => TextLayoutService.setAutofit(html, mode));
        },
      );
}
