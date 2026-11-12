import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../providers/presentation_state.dart';
import '../../services/effect_preview_service.dart';
import '../../utils/effect_helpers.dart';

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
    final l10n = context.l10n;
    final degrades = EffectPreviewService.degradesOnPptxExport(_effect);
    return AlertDialog(
      title: Text(l10n.transTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.transEffect, style: theme.textTheme.titleSmall),
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
              if (degrades) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l10n.transWarningPptx,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            )),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              Text(
                  '${l10n.transDuration}: ${(_durationMs / 1000).toStringAsFixed(1)}s',
                  style: theme.textTheme.titleSmall),
              Slider(
                value: _durationMs,
                min: 100,
                max: 3000,
                divisions: 29,
                label: '${(_durationMs / 1000).toStringAsFixed(1)}s',
                onChanged: (v) => setState(() => _durationMs = v),
              ),
              Text(l10n.transAutoAdvance, style: theme.textTheme.titleSmall),
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
                          ? l10n.transOff
                          : '${(_autoAdvanceMs / 1000).toStringAsFixed(1)}s',
                      onChanged: (v) =>
                          setState(() => _autoAdvanceMs = v.round()),
                    ),
                  ),
                  Text(
                    _autoAdvanceMs == 0
                        ? l10n.transOff
                        : '${(_autoAdvanceMs / 1000).toStringAsFixed(1)}s',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.transMorphTitle),
                subtitle: Text(l10n.transMorphSubtitle),
                value: _morph,
                onChanged: (v) => setState(() => _morph = v ?? false),
              ),
              const Divider(height: 8),
              Text(l10n.transSound, style: theme.textTheme.titleSmall),
              DropdownButtonFormField<String>(
                initialValue: _sound,
                items: [
                  DropdownMenuItem(value: '', child: Text(l10n.transSoundNone)),
                  DropdownMenuItem(
                      value: 'applause', child: Text(l10n.transSoundApplause)),
                  DropdownMenuItem(
                      value: 'chime', child: Text(l10n.transSoundChime)),
                  DropdownMenuItem(
                      value: 'click', child: Text(l10n.transSoundClick)),
                  DropdownMenuItem(
                      value: 'drum', child: Text(l10n.transSoundDrum)),
                ],
                onChanged: (v) => setState(() => _sound = v ?? ''),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.transSoundNote,
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
          child: Text(l10n.cancel),
        ),
        OutlinedButton(
          onPressed: _applyToAll,
          child: Text(l10n.transApplyAll),
        ),
        FilledButton(
          onPressed: _applyCurrent,
          child: Text(l10n.apply),
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
