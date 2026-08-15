import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/drawn_shape.dart';

/// "Edit Points" dialog (Track 21, P5): displays anchor points of a
/// [DrawnShape] on a 10×10 grid; tap to select, drag to move, add/delete
/// points. Returns the updated [DrawnShape] or null when cancelled.
class ShapePointsDialog extends StatefulWidget {
  final DrawnShape shape;
  const ShapePointsDialog({super.key, required this.shape});

  @override
  State<ShapePointsDialog> createState() => _ShapePointsDialogState();
}

class _ShapePointsDialogState extends State<ShapePointsDialog> {
  late List<Offset2D> _points;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _points = widget.shape.anchorPoints;
  }

  void _addPoint() {
    setState(() {
      _points.add(const Offset2D(0.5, 0.5));
      _selectedIndex = _points.length - 1;
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null || _points.length <= 3) return;
    setState(() {
      _points.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
  }

  void _moveSelected(double dx, double dy) {
    if (_selectedIndex == null) return;
    final idx = _selectedIndex!;
    final p = _points[idx];
    setState(() {
      _points[idx] = Offset2D(
        (p.dx + dx).clamp(0.0, 1.0),
        (p.dy + dy).clamp(0.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.edit_outlined),
        const SizedBox(width: 10),
        Text(l.shapeEditPoints),
      ]),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            // Point grid
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  final local = details.localPosition;
                  final relX = local.dx / 400;
                  final relY = local.dy / 300;
                  // Check if we tapped near an existing point (radius 0.05).
                  for (var i = 0; i < _points.length; i++) {
                    final p = _points[i];
                    if ((p.dx - relX).abs() < 0.05 && (p.dy - relY).abs() < 0.05) {
                      setState(() => _selectedIndex = i);
                      return;
                    }
                  }
                  // Not near a point → deselect.
                  setState(() => _selectedIndex = null);
                },
                onPanUpdate: (details) {
                  if (_selectedIndex == null) return;
                  _moveSelected(
                    details.delta.dx / 400,
                    details.delta.dy / 300,
                  );
                },
                child: Container(
                  width: 400,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      // Grid lines
                      ...List.generate(10, (i) {
                        final frac = i / 10;
                        return Positioned.fill(
                          child: CustomPaint(
                            painter: _GridPainter(frac),
                          ),
                        );
                      }),
                      // Points
                      for (var i = 0; i < _points.length; i++)
                        Positioned(
                          left: _points[i].dx * 400 - 6,
                          top: _points[i].dy * 300 - 6,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              _moveSelected(
                                details.delta.dx / 400,
                                details.delta.dy / 300,
                              );
                            },
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _selectedIndex == i
                                    ? Colors.blueAccent
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedIndex == i
                                      ? Colors.blue
                                      : Colors.grey.shade600,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Point numbers
                      for (var i = 0; i < _points.length; i++)
                        Positioned(
                          left: _points[i].dx * 400 + 8,
                          top: _points[i].dy * 300 - 8,
                          child: Text(
                            '$i',
                            style: TextStyle(
                              fontSize: 10,
                              color: _selectedIndex == i
                                  ? Colors.blue
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.shapeAddPoint, style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: _selectedIndex != null && _points.length > 3
                      ? _deleteSelected
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  label: Text(l.shapeDeletePoint, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (_selectedIndex != null) ...[
              const SizedBox(height: 6),
              Text(
                '${l.shapePoint}: $_selectedIndex — '
                '(${(_points[_selectedIndex!].dx * 100).toStringAsFixed(0)}%, '
                '${(_points[_selectedIndex!].dy * 100).toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.shape.withAnchors(_points),
          ),
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final double position;
  _GridPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    final x = position * size.width;
    final y = position * size.height;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.position != position;
}