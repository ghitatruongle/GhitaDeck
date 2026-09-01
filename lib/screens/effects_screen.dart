import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide SlideEffect;
import 'package:provider/provider.dart';
import '../providers/presentation_state.dart';
import '../services/effect_preview_service.dart';
import '../utils/effect_helpers.dart';
import '../utils/snackbar_helper.dart';
import '../../l10n/l10n.dart';

class EffectsScreen extends StatefulWidget {
  const EffectsScreen({super.key});

  @override
  State<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends State<EffectsScreen> {
  String _selectedAnimation = 'Fade In';
  SlideEffect _selectedSlideEffect = SlideEffect.none;
  double _animationDuration = 1.0;
  bool _enableLoop = false;
  String _selectedCategory = 'Basic';

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transition Effects (${SlideEffect.values.length} total)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Preview animations and apply transition effects to your presentation',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- Preview Animation Settings ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Preview Animation',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Fade In', label: Text('Fade'), icon: Icon(Icons.opacity, size: 18)),
                      ButtonSegment(value: 'Slide In Left', label: Text('Slide L'), icon: Icon(Icons.swipe, size: 18)),
                      ButtonSegment(value: 'Slide In Right', label: Text('Slide R'), icon: Icon(Icons.swipe, size: 18)),
                      ButtonSegment(value: 'Scale In', label: Text('Scale'), icon: Icon(Icons.zoom_in, size: 18)),
                      ButtonSegment(value: 'Rotate In', label: Text('Rotate'), icon: Icon(Icons.rotate_right, size: 18)),
                      ButtonSegment(value: 'Bounce In', label: Text('Bounce'), icon: Icon(Icons.animation, size: 18)),
                    ],
                    selected: {_selectedAnimation},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _selectedAnimation = newSelection.first);
                    },
                  ),

                  const SizedBox(height: 16),

                  Text('Animation Duration (${_animationDuration.toStringAsFixed(1)}s)',
                      style: Theme.of(context).textTheme.titleMedium),
                  Slider(
                    min: 0.3, max: 3.0, value: _animationDuration, divisions: 9,
                    label: '${_animationDuration.toStringAsFixed(1)}s',
                    onChanged: (double value) => setState(() => _animationDuration = value),
                  ),

                  Row(
                    children: [
                      Checkbox(
                        value: _enableLoop,
                        onChanged: (value) => setState(() => _enableLoop = value ?? false),
                      ),
                      const Expanded(child: Text('Loop Animation Preview')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- Live Preview ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: _buildAnimatedWidget()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- Effect Categories ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Slide Transitions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Choose a transition effect for your slides',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),

                  // Category tabs
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EffectPreviewService.categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      final icon = EffectPreviewService.getCategoryIcon(cat);
                      return ChoiceChip(
                        label: Text('$icon $cat'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Effects in selected category
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: EffectPreviewService.getEffectsByCategory(_selectedCategory)
                        .where((e) => e != SlideEffect.none)
                        .map((effect) {
                      final isSelected = _selectedSlideEffect == effect;
                      return FilterChip(
                        label: Text(_effectDisplayName(effect)),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedSlideEffect = effect),
                        avatar: Icon(
                          _iconForEffect(effect),
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.outline,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  FilledButton.icon(
                    onPressed: () {
                      presentationState.setEffect(_selectedSlideEffect);
                      showAppSnackBar(context, context.l10n.effectsAppliedNotice(_effectDisplayName(_selectedSlideEffect)));
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Apply to Export'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWidget() {
    final duration = Duration(milliseconds: (_animationDuration * 1000).round());
    final textWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$_selectedAnimation Effect',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    final onComplete = _enableLoop
        ? (AnimationController controller) => controller.repeat(reverse: true)
        : null;

    late Animate animate;

    switch (_selectedAnimation) {
      case 'Fade In':
        animate = textWidget.animate(onComplete: onComplete).fadeIn(duration: duration);
        break;
      case 'Slide In Left':
        animate = textWidget.animate(onComplete: onComplete).slideX(begin: -1.0, end: 0.0, duration: duration);
        break;
      case 'Slide In Right':
        animate = textWidget.animate(onComplete: onComplete).slideX(begin: 1.0, end: 0.0, duration: duration);
        break;
      case 'Scale In':
        animate = textWidget.animate(onComplete: onComplete).scale(duration: duration);
        break;
      case 'Rotate In':
        animate = textWidget.animate(onComplete: onComplete).rotate(duration: duration);
        break;
      case 'Bounce In':
        animate = textWidget.animate(onComplete: onComplete).scale(duration: duration, curve: Curves.elasticOut);
        break;
      default:
        animate = textWidget.animate(onComplete: onComplete).fadeIn(duration: duration);
    }

    return animate;
  }

  String _effectDisplayName(SlideEffect effect) {
    return EffectHelpers.effectName(effect);
  }

  IconData _iconForEffect(SlideEffect effect) {
    switch (effect) {
      case SlideEffect.fade:
      case SlideEffect.appear:
      case SlideEffect.disappear:
        return Icons.opacity;
      case SlideEffect.pushLeft:
      case SlideEffect.flyInLeft:
      case SlideEffect.flyOutLeft:
        return Icons.arrow_back;
      case SlideEffect.pushRight:
      case SlideEffect.flyInRight:
      case SlideEffect.flyOutRight:
        return Icons.arrow_forward;
      case SlideEffect.pushUp:
      case SlideEffect.flyInTop:
        return Icons.arrow_upward;
      case SlideEffect.pushDown:
      case SlideEffect.flyInBottom:
        return Icons.arrow_downward;
      case SlideEffect.wipe:
        return Icons.cleaning_services;
      case SlideEffect.splitIn:
      case SlideEffect.splitOut:
        return Icons.call_split;
      case SlideEffect.randomBar:
        return Icons.view_column;
      case SlideEffect.checkerboard:
        return Icons.grid_view;
      case SlideEffect.blinds:
        return Icons.blinds;
      case SlideEffect.clock:
        return Icons.schedule;
      case SlideEffect.zoom:
      case SlideEffect.basicZoom:
      case SlideEffect.growShrink:
        return Icons.zoom_in;
      case SlideEffect.swivel:
      case SlideEffect.spin:
        return Icons.rotate_right;
      case SlideEffect.boomerang:
      case SlideEffect.arc:
      case SlideEffect.customPath:
        return Icons.route;
      case SlideEffect.pulse:
      case SlideEffect.teeter:
        return Icons.favorite;
      case SlideEffect.flicker:
      case SlideEffect.colorPulse:
        return Icons.flash_on;
      default:
        return Icons.animation;
    }
  }
}
