import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../l10n/app_localizations.dart';
import '../../services/image_editor_service.dart';

/// Image Editor Dialog — v1.3.0 (Track 22 + 23)
///
/// Tabs:
///  - Basic: resize / rotate / flip / brightness / contrast (regression-safe)
///  - Crop: freeform crop with locked aspect ratios + crop-to-shape mask
///  - Remove BG: local flood-fill background removal + brush refine
///  - Adjust: saturation / temperature / sharpness / duotone recolor
///  - Artistic: blur / mosaic / pencil / oil / film + 6 quick presets
///
/// Returns the final `data:image/png;base64,...` URI via Navigator.pop.
class ImageEditorDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String? initialName;

  const ImageEditorDialog({
    super.key,
    required this.imageBytes,
    this.initialName,
  });

  @override
  State<ImageEditorDialog> createState() => _ImageEditorDialogState();
}

class _ImageEditorDialogState extends State<ImageEditorDialog> {
  late Uint8List _currentImage;
  bool _isProcessing = false;
  int _tab = 0;

  // Basic
  double _brightness = 0;
  double _contrast = 0;

  // Crop
  String _aspect = 'none';
  double _cropX = 0, _cropY = 0, _cropW = 100, _cropH = 100;
  String _cropShape = 'rect';
  double _radiusRatio = 0.1;

  // Background removal
  double _seedX = 50, _seedY = 20, _tolerance = 0.25;
  double _brushRadius = 0.05;
  bool _eraseMode = true;

  // Adjust
  double _saturation = 0, _tone = 0, _sharpness = 0;
  Color _duotoneA = const Color(0xFF2B2B2B);
  Color _duotoneB = const Color(0xFFF5F5F5);

  // Artistic
  String _effect = 'blur';
  double _intensity = 1.0;

  // Preview geometry (for brush taps)
  int _imgW = 0, _imgH = 0;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.imageBytes;
    _refreshDimensions();
  }

  void _refreshDimensions() {
    final decoded = img.decodeImage(_currentImage);
    if (decoded != null) {
      _imgW = decoded.width;
      _imgH = decoded.height;
    }
  }

  Future<void> _run(Future<Uint8List?> Function() op) async {
    setState(() => _isProcessing = true);
    final result = await op();
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _currentImage = result;
        _refreshDimensions();
      }
      _isProcessing = false;
    });
  }

  Future<void> _applyResize(int width, int height) {
    return _run(() => ImageEditorService.resizeImage(_currentImage, width: width, height: height));
  }

  Future<void> _applyRotation(int degrees) {
    return _run(() => ImageEditorService.rotateImage(_currentImage, degrees: degrees));
  }

  Future<void> _applyFlip(bool horizontal) {
    return _run(() => ImageEditorService.flipImage(_currentImage, horizontal: horizontal));
  }

  Future<void> _applyAdjustments() {
    return _run(() => ImageEditorService.adjustImage(_currentImage, brightness: _brightness, contrast: _contrast));
  }

  Future<void> _applyCrop() {
    final w = _cropW.clamp(1.0, 100.0);
    final h = _cropH.clamp(1.0, 100.0);
    final x = _cropX.clamp(0.0, 100.0 - w);
    final y = _cropY.clamp(0.0, 100.0 - h);
    return _run(() => ImageEditorService.cropImage(
          _currentImage,
          x: x / 100,
          y: y / 100,
          w: w / 100,
          h: h / 100,
        ));
  }

  Future<void> _applyCropToShape() {
    return _run(() => ImageEditorService.cropToShape(_currentImage, shape: _cropShape, radiusRatio: _radiusRatio));
  }

  Future<void> _applyRemoveBg() {
    return _run(() => ImageEditorService.removeBackground(
          _currentImage,
          seedX: _seedX / 100,
          seedY: _seedY / 100,
          tolerance: _tolerance,
        ));
  }

  Future<void> _applyBrush(double fx, double fy) {
    return _run(() => ImageEditorService.brushEdit(
          _currentImage,
          original: widget.imageBytes,
          cx: fx,
          cy: fy,
          radius: _brushRadius,
          erase: _eraseMode,
        ));
  }

  Future<void> _applyCorrections() {
    return _run(() => ImageEditorService.correctImage(
          _currentImage,
          saturation: _saturation,
          tone: _tone,
          sharpness: _sharpness,
          duotoneA: _duotoneA.toARGB32() == 0xFF000000 ? null : '#${_duotoneA.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
          duotoneB: '#${_duotoneB.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        ));
  }

  Future<void> _applyArtistic() {
    return _run(() => ImageEditorService.artisticEffect(_currentImage, effect: _effect, intensity: _intensity));
  }

  Future<void> _applyPreset(String preset) {
    return _run(() => ImageEditorService.presetImage(_currentImage, preset));
  }

  /// Compute the displayed (contain-fit) rect of the image inside [size]
  /// so brush taps map to correct pixel coordinates.
  Rect _fittedRect(Size size) {
    if (_imgW == 0 || _imgH == 0 || size.isEmpty) return Offset.zero & size;
    final scale = (size.width / _imgW) < (size.height / _imgH)
        ? size.width / _imgW
        : size.height / _imgH;
    final w = _imgW * scale;
    final h = _imgH * scale;
    return Offset((size.width - w) / 2, (size.height - h) / 2) & Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, size: 24),
                  const SizedBox(width: 12),
                  Text(l.imageEditTitle, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                children: [
                  // Tabs
                  DefaultTabController(
                    length: 5,
                    child: TabBar(
                      isScrollable: true,
                      onTap: (i) => setState(() => _tab = i),
                      tabs: [
                        Tab(text: l.imageTabBasic),
                        Tab(text: l.imageTabCrop),
                        Tab(text: l.imageTabBackground),
                        Tab(text: l.imageTabAdjust),
                        Tab(text: l.imageTabArtistic),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Preview
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final fitted = _fittedRect(Size(constraints.maxWidth, constraints.maxHeight));
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTapDown: _tab == 2
                                              ? (details) {
                                                  final local = details.localPosition;
                                                  if (!fitted.contains(local)) return;
                                                  final fx = (local.dx - fitted.left) / fitted.width;
                                                  final fy = (local.dy - fitted.top) / fitted.height;
                                                  _applyBrush(fx.clamp(0.0, 1.0), fy.clamp(0.0, 1.0));
                                                }
                                              : null,
                                          child: Image.memory(_currentImage, fit: BoxFit.contain),
                                        ),
                                      ),
                                      if (_isProcessing)
                                        Container(
                                          color: Colors.black45,
                                          child: const Center(child: CircularProgressIndicator()),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Controls
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_tab == 0) _buildBasicTab(l),
                                  if (_tab == 1) _buildCropTab(l),
                                  if (_tab == 2) _buildBackgroundTab(l),
                                  if (_tab == 3) _buildAdjustTab(l),
                                  if (_tab == 4) _buildArtisticTab(l),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.imageCancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            final dataUri = ImageEditorService.toDataUri(_currentImage);
                            Navigator.of(context).pop(dataUri);
                          },
                    child: Text(l.imageUse),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTab(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l.imageSize),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Width', isDense: true),
                keyboardType: TextInputType.number,
                onSubmitted: (value) {
                  final w = int.tryParse(value) ?? 0;
                  if (w > 0) _applyResize(w, 0);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Height', isDense: true),
                keyboardType: TextInputType.number,
                onSubmitted: (value) {
                  final h = int.tryParse(value) ?? 0;
                  if (h > 0) _applyResize(0, h);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(l.imageRotate),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.rotate_left),
                label: const Text('90°'),
                onPressed: () => _applyRotation(270),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.rotate_right),
                label: const Text('90°'),
                onPressed: () => _applyRotation(90),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(l.imageFlip),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flip),
                label: Text(l.imageFlipH),
                onPressed: () => _applyFlip(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flip, size: 16),
                label: Text(l.imageFlipV),
                onPressed: () => _applyFlip(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(l.imageBrightness),
        Slider(
          value: _brightness,
          min: -100,
          max: 100,
          divisions: 20,
          onChanged: (v) => setState(() => _brightness = v),
        ),
        _sectionTitle(l.imageContrast),
        Slider(
          value: _contrast,
          min: -100,
          max: 100,
          divisions: 20,
          onChanged: (v) => setState(() => _contrast = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _applyAdjustments,
          child: Text(l.imageApply),
        ),
      ],
    );
  }

  Widget _buildCropTab(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l.imageCropAspect),
        DropdownButtonFormField<String>(
          initialValue: _aspect,
          isDense: true,
          items: ['none', 'square', '169', '32', '43']
              .map((a) => DropdownMenuItem(
                    value: a,
                    child: Text(_aspectLabel(l, a)),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() {
              _aspect = v ?? 'none';
              _applyAspectConstraint();
            });
          },
        ),
        const SizedBox(height: 12),
        _percentSlider(l, l.imageCropX, _cropX, 0, 100, (v) => setState(() => _cropX = v)),
        _percentSlider(l, l.imageCropY, _cropY, 0, 100, (v) => setState(() => _cropY = v)),
        _percentSlider(l, l.imageCropW, _cropW, 1, 100, (v) => setState(() => _cropW = v)),
        _percentSlider(l, l.imageCropH, _cropH, 1, 100, (v) => setState(() => _cropH = v)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _applyCrop,
          child: Text(l.imageCropApply),
        ),
        const SizedBox(height: 20),
        _sectionTitle(l.imageCropShape),
        DropdownButtonFormField<String>(
          initialValue: _cropShape,
          isDense: true,
          items: ['rect', 'oval', 'rounded', 'triangle', 'diamond', 'heart']
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_shapeLabel(l, s)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _cropShape = v ?? 'rect'),
        ),
        if (_cropShape == 'rounded') ...[
          const SizedBox(height: 8),
          _percentSlider(l, l.imageRadius, _radiusRatio, 0.02, 0.5, (v) => setState(() => _radiusRatio = v)),
        ],
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _applyCropToShape,
          child: Text(l.imageApply),
        ),
      ],
    );
  }

  Widget _buildBackgroundTab(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l.imageRemoveBg),
        Text(l.imageBgHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        _percentSlider(l, l.imageSeedX, _seedX, 0, 100, (v) => setState(() => _seedX = v)),
        _percentSlider(l, l.imageSeedY, _seedY, 0, 100, (v) => setState(() => _seedY = v)),
        _sectionTitle(l.imageTolerance),
        Slider(
          value: _tolerance,
          min: 0.02,
          max: 0.6,
          divisions: 28,
          onChanged: (v) => setState(() => _tolerance = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _applyRemoveBg,
          child: Text(l.imageApply),
        ),
        const SizedBox(height: 20),
        _sectionTitle(l.imageBrush),
        Text(l.imageBrushHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l.imageErase)),
            ButtonSegment(value: false, label: Text(l.imageRestore)),
          ],
          selected: {_eraseMode},
          onSelectionChanged: (s) => setState(() => _eraseMode = s.first),
        ),
        const SizedBox(height: 8),
        _sectionTitle(l.imageBrushSize),
        Slider(
          value: _brushRadius,
          min: 0.01,
          max: 0.2,
          divisions: 38,
          onChanged: (v) => setState(() => _brushRadius = v),
        ),
        Text('${(_brushRadius * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAdjustTab(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l.imageSaturation),
        Slider(
          value: _saturation,
          min: -1,
          max: 1,
          divisions: 40,
          onChanged: (v) => setState(() => _saturation = v),
        ),
        _sectionTitle(l.imageTone),
        Slider(
          value: _tone,
          min: -1,
          max: 1,
          divisions: 40,
          onChanged: (v) => setState(() => _tone = v),
        ),
        _sectionTitle(l.imageSharpness),
        Slider(
          value: _sharpness,
          min: 0,
          max: 2,
          divisions: 40,
          onChanged: (v) => setState(() => _sharpness = v),
        ),
        const SizedBox(height: 8),
        _sectionTitle(l.imageDuotoneA),
        _colorRow(_duotoneA, (c) => setState(() => _duotoneA = c)),
        _sectionTitle(l.imageDuotoneB),
        _colorRow(_duotoneB, (c) => setState(() => _duotoneB = c)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _applyCorrections,
          child: Text(l.imageApply),
        ),
      ],
    );
  }

  Widget _buildArtisticTab(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l.imageEffect),
        DropdownButtonFormField<String>(
          initialValue: _effect,
          isDense: true,
          items: ['blur', 'mosaic', 'pencil', 'oil', 'film']
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(_effectLabel(l, e)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _effect = v ?? 'blur'),
        ),
        const SizedBox(height: 8),
        _sectionTitle(l.imageIntensity),
        Slider(
          value: _intensity,
          min: 0.2,
          max: 2,
          divisions: 36,
          onChanged: (v) => setState(() => _intensity = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _applyArtistic,
          child: Text(l.imageApply),
        ),
        const SizedBox(height: 20),
        _sectionTitle(l.imagePreset),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _presetChip(l.imagePresetBw, () => _applyPreset('bw')),
            _presetChip(l.imagePresetVintage, () => _applyPreset('vintage')),
            _presetChip(l.imagePresetCool, () => _applyPreset('cool')),
            _presetChip(l.imagePresetWarm, () => _applyPreset('warm')),
            _presetChip(l.imagePresetSoft, () => _applyPreset('soft')),
            _presetChip(l.imagePresetVivid, () => _applyPreset('vivid')),
          ],
        ),
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(label: Text(label), onPressed: _isProcessing ? null : onTap);
  }

  Widget _colorRow(Color color, ValueChanged<Color> onChanged) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showDialog<Color>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Pick color'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final hex in const [
                            '000000', 'FFFFFF', 'FF0000', 'FF8800', 'FFFF00', '00FF00',
                            '00AAFF', '0000FF', '8800FF', 'FF00FF', '884400', '888888',
                          ])
                            InkWell(
                              onTap: () => Navigator.of(context).pop(Color(int.parse('FF$hex', radix: 16))),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(int.parse('FF$hex', radix: 16)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (picked != null) onChanged(picked);
            },
            child: const Text('#'),
          ),
        ),
      ],
    );
  }

  void _applyAspectConstraint() {
    final ratio = switch (_aspect) {
      'square' => 1.0,
      '169' => 16 / 9,
      '32' => 3 / 2,
      '43' => 4 / 3,
      _ => null,
    };
    if (ratio == null) return;
    // Keep the crop centred, lock W/H to the chosen ratio.
    final w = _cropW.clamp(1.0, 100.0);
    var h = (w / ratio).clamp(1.0, 100.0);
    // If the locked height overflows, derive width from height instead.
    if (h == 100.0 && w / ratio > 100.0) {
      h = 100.0;
      final w2 = (h * ratio).clamp(1.0, 100.0);
      _cropW = w2;
    } else {
      _cropW = w;
    }
    _cropH = h;
    final maxX = 100.0 - _cropW;
    final maxY = 100.0 - _cropH;
    _cropX = _cropX.clamp(0.0, maxX);
    _cropY = _cropY.clamp(0.0, maxY);
  }

  Widget _percentSlider(AppLocalizations l, String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${value.round()}%', style: Theme.of(context).textTheme.bodySmall),
        Slider(value: value, min: min, max: max, divisions: 200, onChanged: onChanged),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }

  String _aspectLabel(AppLocalizations l, String a) => switch (a) {
        'square' => l.imageAspectSquare,
        '169' => l.imageAspect169,
        '32' => l.imageAspect32,
        '43' => l.imageAspect43,
        _ => l.imageAspectNone,
      };

  String _shapeLabel(AppLocalizations l, String s) => switch (s) {
        'oval' => l.imageShapeOval,
        'rounded' => l.imageShapeRounded,
        'triangle' => l.imageShapeTriangle,
        'diamond' => l.imageShapeDiamond,
        'heart' => l.imageShapeHeart,
        _ => l.imageShapeRect,
      };

  String _effectLabel(AppLocalizations l, String e) => switch (e) {
        'mosaic' => l.imageEffectMosaic,
        'pencil' => l.imageEffectPencil,
        'oil' => l.imageEffectOil,
        'film' => l.imageEffectFilm,
        _ => l.imageEffectBlur,
      };
}
