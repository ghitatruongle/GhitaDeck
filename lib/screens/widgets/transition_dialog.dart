import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/presentation_state.dart';
import '../../utils/effect_helpers.dart';

/// Transition picker (Track 33, FEAT 52/53): every SlideEffect including the
/// 26 new ones, per-slide duration (0.1–3s), auto-advance and optional
/// sound. Applies to the current slide (or the whole deck).
class TransitionDialog extends StatefulWidget {
  const TransitionDialog({super.key});

  @override
  State<TransitionDialog> createState() => _TransitionDialogState();
}

class _TransitionDialogState extends State<TransitionDialog> {
  late SlideEffect _effect;
  late double _durationMs;
  late int _autoAdvanceMs;
  late String _sound;
  late bool _morph;

  @override
  void initState() {
    super.initState();
    final state = context.read<PresentationState>();
    final slide = state.currentSlide;
    _effect = slide?.effect ?? state.slideEffect;
    _durationMs =
        (slide?.transitionDurationMs ?? 500).clamp(100, 3000).toDouble();
    _autoAdvanceMs = slide?.autoAdvanceMs ?? 0;
    _sound = slide?.transitionSound ?? '';
    _morph = slide?.morphFromPrevious ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Transitions'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Effect', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final e in SlideEffect.values)
                    if (e != SlideEffect.none)
                      ChoiceChip(
                        label: Text(EffectHelpers.effectName(e),
                            style: const TextStyle(fontSize: 11)),
                        selected: _effect == e,
                        onSelected: (_) => setState(() => _effect = e),
                      ),
                ],
              ),
              const Divider(height: 24),
              Text('Duration: ${(_durationMs / 1000).toStringAsFixed(1)}s',
                  style: theme.textTheme.titleSmall),
              Slider(
                value: _durationMs,
                min: 100,
                max: 3000,
                divisions: 29,
                label: '${(_durationMs / 1000).toStringAsFixed(1)}s',
                onChanged: (v) => setState(() => _durationMs = v),
              ),
              Text('Auto-advance after',
                  style: theme.textTheme.titleSmall),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16),
                  Expanded(
                    child: Slider(
                      value: _autoAdvanceMs == 0 ? 0 : _autoAdvanceMs.toDouble(),
                      min: 0,
                      max: 30000,
                      divisions: 30,
                      label: _autoAdvanceMs == 0
                          ? 'Off'
                          : '${(_autoAdvanceMs / 1000).toStringAsFixed(1)}s',
                      onChanged: (v) => setState(() => _autoAdvanceMs = v.round()),
                    ),
                  ),
                  Text(
                    _autoAdvanceMs == 0
                        ? 'Off'
                        : '${(_autoAdvanceMs / 1000).toStringAsFixed(1)}s',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Morph from previous slide (Track 34)'),
                subtitle: const Text('Morphs matching shapes smoothly'),
                value: _morph,
                onChanged: (v) => setState(() => _morph = v ?? false),
              ),
              const Divider(height: 8),
              Text('Sound', style: theme.textTheme.titleSmall),
              DropdownButtonFormField<String>(
                initialValue: _sound,
                items: const [
                  DropdownMenuItem(value: '', child: Text('(None)')),
                  DropdownMenuItem(value: 'applause', child: Text('Applause')),
                  DropdownMenuItem(value: 'chime', child: Text('Chime')),
                  DropdownMenuItem(value: 'click', child: Text('Click')),
                  DropdownMenuItem(value: 'drum', child: Text('Drum Roll')),
                ],
                onChanged: (v) => setState(() => _sound = v ?? ''),
              ),
              const SizedBox(height: 4),
              Text(
                'Note: sound is embedded in exported decks when the audio '
                'file is available; otherwise the transition still exports.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _applyToAll,
          child: const Text('Apply to all'),
        ),
        FilledButton(
          onPressed: _applyCurrent,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _applyCurrent() {
    final state = context.read<PresentationState>();
    final index = state.currentSlideIndex;
    if (index < 0) return;
    state.setSlideEffectOverride(index, _effect);
    state.setSlideTransitionSettings(
      index,
      durationMs: _durationMs.round(),
      sound: _sound,
      autoAdvanceMs: _autoAdvanceMs,
    );
    state.setSlideMorph(index, _morph);
    Navigator.pop(context);
  }

  void _applyToAll() {
    final state = context.read<PresentationState>();
    for (var i = 0; i < state.slides.length; i++) {
      state.setSlideEffectOverride(i, _effect);
      state.setSlideTransitionSettings(
        i,
        durationMs: _durationMs.round(),
        sound: _sound,
        autoAdvanceMs: _autoAdvanceMs,
      );
      state.setSlideMorph(i, _morph);
    }
    Navigator.pop(context);
  }
}
