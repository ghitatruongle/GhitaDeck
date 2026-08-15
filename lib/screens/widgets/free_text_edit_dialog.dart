import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/free_shape.dart';
import '../../services/wordart_service.dart';

/// Dialog to add or edit a free-form text box (Track 17, P2/P7).
///
/// Returns a [FreeTextShape] when the user confirms, or null when cancelled.
class FreeTextEditDialog extends StatefulWidget {
  final FreeTextShape? existing;
  const FreeTextEditDialog({super.key, this.existing});

  @override
  State<FreeTextEditDialog> createState() => _FreeTextEditDialogState();
}

class _FreeTextEditDialogState extends State<FreeTextEditDialog> {
  late FreeTextShape _draft;
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.existing ?? FreeTextShape(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: 'Double-click to edit',
      x: 10, y: 10, w: 40, h: 15,
    );
    _textCtrl = TextEditingController(text: _draft.text);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.text_fields),
        const SizedBox(width: 10),
        Text(widget.existing == null ? l.freeTextAdd : l.freeTextEdit),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text content
              TextField(
                controller: _textCtrl,
                decoration: InputDecoration(
                  labelText: l.freeTextContent,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
                onChanged: (v) => _draft = _draft.copyWith(text: v),
              ),
              const SizedBox(height: 12),
              // Position / size row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.x.toStringAsFixed(1),
                      decoration: const InputDecoration(
                        labelText: 'X (%)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        x: double.tryParse(v) ?? _draft.x,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.y.toStringAsFixed(1),
                      decoration: const InputDecoration(
                        labelText: 'Y (%)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        y: double.tryParse(v) ?? _draft.y,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.w.toStringAsFixed(1),
                      decoration: const InputDecoration(
                        labelText: 'W (%)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        w: double.tryParse(v) ?? _draft.w,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.h.toStringAsFixed(1),
                      decoration: const InputDecoration(
                        labelText: 'H (%)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        h: double.tryParse(v) ?? _draft.h,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Font size + rotation
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.fontSize.toStringAsFixed(0),
                      decoration: InputDecoration(
                        labelText: l.freeTextFontSize,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        fontSize: double.tryParse(v) ?? _draft.fontSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.rotation.toStringAsFixed(0),
                      decoration: const InputDecoration(
                        labelText: 'Rotation (°)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        rotation: double.tryParse(v) ?? _draft.rotation,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.zOrder.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Z-order',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        zOrder: int.tryParse(v) ?? _draft.zOrder,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Font + weight + color
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _draft.fontFamily,
                      decoration: const InputDecoration(
                        labelText: 'Font',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Segoe UI', child: Text('Segoe UI')),
                        DropdownMenuItem(value: 'Arial', child: Text('Arial')),
                        DropdownMenuItem(value: 'Calibri', child: Text('Calibri')),
                        DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
                        DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
                      ],
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(fontFamily: v ?? 'Segoe UI')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _draft.fontWeight,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'bold', child: Text('Bold')),
                      ],
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(fontWeight: v ?? 'normal')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Color + background
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.color,
                      decoration: InputDecoration(
                        labelText: l.freeTextColor,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _draft = _draft.copyWith(color: v.isEmpty ? '#000000' : v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.backgroundColor == 'transparent' ? '' : _draft.backgroundColor,
                      decoration: InputDecoration(
                        labelText: l.freeTextBg,
                        hintText: 'transparent',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _draft = _draft.copyWith(backgroundColor: v.isEmpty ? 'transparent' : v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Border + shadow
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.borderColor,
                      decoration: InputDecoration(
                        labelText: l.freeTextBorder,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _draft = _draft.copyWith(borderColor: v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _draft.borderWidth > 0 ? _draft.borderWidth.toString() : '',
                      decoration: const InputDecoration(
                        labelText: 'Border W',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _draft = _draft.copyWith(
                        borderWidth: double.tryParse(v) ?? 0.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _draft.shadow,
                        onChanged: (v) => setState(() => _draft = _draft.copyWith(shadow: v ?? false)),
                      ),
                      Text(l.freeTextShadow, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // WordArt style
              DropdownButtonFormField<int>(
                initialValue: _draft.wordArtStyle,
                decoration: InputDecoration(
                  labelText: l.freeTextWordArt,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('None')),
                  for (var i = 1; i <= WordArtService.count; i++)
                    DropdownMenuItem(value: i, child: Text(WordArtService.styleName(i))),
                ],
                onChanged: (v) => setState(() => _draft = _draft.copyWith(wordArtStyle: v ?? 0)),
              ),
              // Preview
              if (_draft.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      _draft.text,
                      style: TextStyle(
                        fontSize: _draft.fontSize.clamp(10, 24),
                        fontFamily: _draft.fontFamily,
                        fontWeight: _draft.fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
                        fontStyle: _draft.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                        color: _parseColorHex(_draft.color) ?? Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
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
          onPressed: () => Navigator.pop(context, _draft.copyWith(text: _textCtrl.text)),
          child: Text(widget.existing == null ? l.freeTextAdd : l.save),
        ),
      ],
    );
  }
}

/// Parse a hex colour string (#RRGGBB) into a [Color], or null.
Color? _parseColorHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  if (clean.length != 6) return null;
  final val = int.tryParse(clean, radix: 16);
  if (val == null) return null;
  return Color(0xFF000000 | val);
}