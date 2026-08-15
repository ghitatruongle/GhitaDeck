import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/drawn_shape.dart';
import '../../models/shape_effect.dart';

/// Shape Properties Dialog (Track 21, P7): edit fill, stroke, transparency,
/// gradient, shadow for a selected [DrawnShape]. Returns the updated shape.
class ShapePropertiesDialog extends StatefulWidget {
  final DrawnShape shape;
  const ShapePropertiesDialog({super.key, required this.shape});

  @override
  State<ShapePropertiesDialog> createState() => _ShapePropertiesDialogState();
}

class _ShapePropertiesDialogState extends State<ShapePropertiesDialog> {
  late DrawnShape _draft;
  late TextEditingController _fillCtrl;
  late TextEditingController _gradStartCtrl;
  late TextEditingController _gradEndCtrl;
  late TextEditingController _strokeCtrl;
  late TextEditingController _strokeWidthCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.shape;
    _fillCtrl = TextEditingController(text: _draft.fillColor);
    _gradStartCtrl = TextEditingController(text: _draft.gradientStart);
    _gradEndCtrl = TextEditingController(text: _draft.gradientEnd);
    _strokeCtrl = TextEditingController(text: _draft.strokeColor);
    _strokeWidthCtrl =
        TextEditingController(text: _draft.strokeWidth.toStringAsFixed(1));
  }

  void _setFx(ShapeEffect fx) {
    setState(() => _draft = _draft.copyWith(effect: fx));
  }

  Widget _fxSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: 40,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 40,
            child: Text(value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11))),
      ],
    );
  }

  Widget _fxPresetChip(String label, EffectPreset preset) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      onPressed: () => _setFx(_draft.effect.withPreset(preset)),
    );
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _gradStartCtrl.dispose();
    _gradEndCtrl.dispose();
    _strokeCtrl.dispose();
    _strokeWidthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.tune),
        const SizedBox(width: 10),
        Text(l.shapeProperties),
      ]),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fill color
              TextField(
                controller: _fillCtrl,
                decoration: InputDecoration(
                  labelText: l.shapeFillColor,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    _draft = _draft.copyWith(fillColor: v.isEmpty ? '#4472C4' : v),
              ),
              const SizedBox(height: 8),
              // Fill transparency
              Row(
                children: [
                  Text(l.shapeTransparency,
                      style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _draft.fillTransparency,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label:
                          '${(_draft.fillTransparency * 100).round()}%',
                      onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(fillTransparency: v)),
                    ),
                  ),
                  Text('${(_draft.fillTransparency * 100).round()}%',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              // Gradient fill (Track 21, P7)
              CheckboxListTile(
                value: _draft.gradientStart.isNotEmpty,
                title: Text(l.shapeGradient, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(
                    gradientStart: v == true ? '#FF8A00' : '',
                    gradientEnd: v == true ? '#E52E71' : '',
                    gradientAngle: _draft.gradientAngle,
                  );
                  _gradStartCtrl.text = _draft.gradientStart;
                  _gradEndCtrl.text = _draft.gradientEnd;
                }),
              ),
              if (_draft.gradientStart.isNotEmpty) ...[
                TextField(
                  controller: _gradStartCtrl,
                  decoration: InputDecoration(
                    labelText: l.shapeGradientStart,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _draft = _draft.copyWith(
                      gradientStart: v.isEmpty ? '#FF8A00' : v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _gradEndCtrl,
                  decoration: InputDecoration(
                    labelText: l.shapeGradientEnd,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _draft = _draft.copyWith(
                      gradientEnd: v.isEmpty ? '#E52E71' : v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(l.shapeGradientAngle,
                        style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _draft.gradientAngle,
                        min: 0,
                        max: 360,
                        divisions: 36,
                        label: '${_draft.gradientAngle.round()}°',
                        onChanged: (v) => setState(() =>
                            _draft = _draft.copyWith(gradientAngle: v)),
                      ),
                    ),
                    Text('${_draft.gradientAngle.round()}°',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Stroke color
              TextField(
                controller: _strokeCtrl,
                decoration: InputDecoration(
                  labelText: l.shapeStrokeColor,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    _draft = _draft.copyWith(strokeColor: v.isEmpty ? '#000000' : v),
              ),
              const SizedBox(height: 8),
              // Stroke width
              TextField(
                controller: _strokeWidthCtrl,
                decoration: InputDecoration(
                  labelText: l.shapeStrokeWidth,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _draft = _draft.copyWith(
                    strokeWidth: double.tryParse(v) ?? 1.0),
              ),
              const SizedBox(height: 8),
              // ---- Effects (Track 25) ----
              const Divider(height: 16),
              Text(l.fxTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              // Quick presets
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _fxPresetChip(l.fxPresetNone, EffectPreset.none),
                  _fxPresetChip(l.fxPresetSoft, EffectPreset.soft),
                  _fxPresetChip(l.fxPresetHard, EffectPreset.hard),
                  _fxPresetChip(l.fxPresetGlow, EffectPreset.glow),
                  _fxPresetChip(l.fxPresetNeumorphism, EffectPreset.neumorphism),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _draft.effect.shadow,
                title: Text(l.fxShadow, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _draft =
                    _draft.copyWith(effect: _draft.effect.copyWith(shadow: v == true))),
              ),
              if (_draft.effect.shadow) ...[
                _fxSlider(l.fxShadowOffsetX, _draft.effect.shadowOffsetX, -20, 20,
                    (v) => _setFx(_draft.effect.copyWith(shadowOffsetX: v))),
                _fxSlider(l.fxShadowOffsetY, _draft.effect.shadowOffsetY, -20, 20,
                    (v) => _setFx(_draft.effect.copyWith(shadowOffsetY: v))),
                _fxSlider(l.fxShadowBlur, _draft.effect.shadowBlur, 0, 30,
                    (v) => _setFx(_draft.effect.copyWith(shadowBlur: v))),
                _fxSlider(l.fxShadowAlpha, _draft.effect.shadowAlpha, 0, 1,
                    (v) => _setFx(_draft.effect.copyWith(shadowAlpha: v))),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: l.fxShadowColor,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: _draft.effect.shadowColor,
                  onChanged: (v) => _setFx(_draft.effect.copyWith(
                      shadowColor: v.isEmpty ? '#000000' : v)),
                ),
              ],
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _draft.effect.glow,
                title: Text(l.fxGlow, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _draft =
                    _draft.copyWith(effect: _draft.effect.copyWith(glow: v == true))),
              ),
              if (_draft.effect.glow) ...[
                _fxSlider(l.fxGlowSize, _draft.effect.glowSize, 1, 25,
                    (v) => _setFx(_draft.effect.copyWith(glowSize: v))),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: l.fxGlowColor,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: _draft.effect.glowColor,
                  onChanged: (v) => _setFx(_draft.effect.copyWith(
                      glowColor: v.isEmpty ? '#FFD700' : v)),
                ),
              ],
              const SizedBox(height: 4),
              _fxSlider(l.fxSoftEdge, _draft.effect.softEdge, 0, 20,
                  (v) => _setFx(_draft.effect.copyWith(softEdge: v))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _draft.effect.bevel,
                isDense: true,
                decoration: InputDecoration(
                  labelText: l.fxBevel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: kBevelPresets
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) =>
                    _setFx(_draft.effect.copyWith(bevel: v ?? 'none')),
              ),
              const SizedBox(height: 8),
              _fxSlider('X', _draft.effect.rot3dX, -90, 90,
                  (v) => _setFx(_draft.effect.copyWith(rot3dX: v))),
              _fxSlider('Y', _draft.effect.rot3dY, -90, 90,
                  (v) => _setFx(_draft.effect.copyWith(rot3dY: v))),
              _fxSlider('Z', _draft.effect.rot3dZ, -180, 180,
                  (v) => _setFx(_draft.effect.copyWith(rot3dZ: v))),
              const SizedBox(height: 8),
              // Preview
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    _draft.type.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _draft),
          child: Text(l.save),
        ),
      ],
    );
  }
}