import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../models/drawn_shape.dart';
import 'shape_points_dialog.dart';

/// Dialog to pick a preset shape, set fill color, stroke color/width, then
/// return a [DrawnShape] (Track 21).
class ShapeToolsDialog extends StatefulWidget {
  const ShapeToolsDialog({super.key});

  @override
  State<ShapeToolsDialog> createState() => _ShapeToolsDialogState();
}

class _ShapeToolsDialogState extends State<ShapeToolsDialog> {
  ShapeType _type = ShapeType.rect;
  final _fillColorCtrl = TextEditingController(text: '#4472C4');
  final _strokeColorCtrl = TextEditingController(text: '#000000');
  final _strokeWidthCtrl = TextEditingController(text: '1.0');

  @override
  void dispose() {
    _fillColorCtrl.dispose();
    _strokeColorCtrl.dispose();
    _strokeWidthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.category_outlined),
        const SizedBox(width: 10),
        Text(l.shape),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shape type
            DropdownButtonFormField<ShapeType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l.shapeType,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: ShapeType.rect, child: Text('Rectangle')),
                DropdownMenuItem(value: ShapeType.oval, child: Text('Oval')),
                DropdownMenuItem(value: ShapeType.line, child: Text('Line')),
                DropdownMenuItem(value: ShapeType.arrow, child: Text('Arrow')),
              ],
              onChanged: (v) => setState(() => _type = v ?? ShapeType.rect),
            ),
            const SizedBox(height: 10),
            // Fill color
            TextField(
              controller: _fillColorCtrl,
              decoration: InputDecoration(
                labelText: l.shapeFillColor,
                hintText: '#4472C4',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(7),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            // Stroke color
            TextField(
              controller: _strokeColorCtrl,
              decoration: InputDecoration(
                labelText: l.shapeStrokeColor,
                hintText: '#000000',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(7),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            // Stroke width
            TextField(
              controller: _strokeWidthCtrl,
              decoration: InputDecoration(
                labelText: l.shapeStrokeWidth,
                hintText: '1.0',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          // Track 21, P5: edit anchor points of the shape before inserting.
          onPressed: () async {
            final draft = DrawnShape(
              id: 'shape_${DateTime.now().millisecondsSinceEpoch}',
              type: _type,
              x: 20, y: 20,
              w: 25, h: 18,
              fillColor: _fillColorCtrl.text.trim().isEmpty
                  ? '#4472C4'
                  : _fillColorCtrl.text.trim(),
              strokeColor: _strokeColorCtrl.text.trim().isEmpty
                  ? '#000000'
                  : _strokeColorCtrl.text.trim(),
              strokeWidth: double.tryParse(_strokeWidthCtrl.text) ?? 1.0,
            );
            final edited = await showDialog<DrawnShape>(
              context: context,
              builder: (_) => ShapePointsDialog(shape: draft),
            );
            if (edited != null && context.mounted) {
              Navigator.pop(context, edited);
            }
          },
          child: Text(l.shapeEditPoints),
        ),
        FilledButton(
          onPressed: () {
            final sw = double.tryParse(_strokeWidthCtrl.text) ?? 1.0;
            Navigator.pop(context, DrawnShape(
              id: 'shape_${DateTime.now().millisecondsSinceEpoch}',
              type: _type,
              x: 20, y: 20,
              w: 25, h: 18,
              fillColor: _fillColorCtrl.text.trim().isEmpty
                  ? '#4472C4'
                  : _fillColorCtrl.text.trim(),
              strokeColor: _strokeColorCtrl.text.trim().isEmpty
                  ? '#000000'
                  : _strokeColorCtrl.text.trim(),
              strokeWidth: sw,
            ));
          },
          child: Text(l.shapeInsert),
        ),
      ],
    );
  }
}