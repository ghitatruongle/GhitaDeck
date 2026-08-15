import 'package:flutter/material.dart';
import '../../models/free_shape.dart';
import '../../models/drawn_shape.dart';

/// Canvas overlay for free-form text/shape editing (Track 17, P2/P7) and
/// DrawnShape selection (Track 21, P7).
class CanvasOverlay extends StatelessWidget {
  final List<FreeTextShape> elements;
  final String? selectedId;
  final ValueChanged<FreeTextShape>? onElementChanged;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onDelete;

  /// Track 21 shapes overlay.
  final List<DrawnShape> drawnShapes;
  final String? selectedShapeId;
  final Set<String> selectedShapeIds;
  final ValueChanged<DrawnShape>? onShapeChanged;
  final ValueChanged<String>? onShapeSelect;
  final ValueChanged<String>? onShapeDelete;

  /// Track 21, P4: freeform scribble drawing over the whole canvas.
  final bool scribbleMode;
  final List<Offset2D> scribblePoints;
  final void Function(Offset2D localPoint)? onScribbleMove;
  final VoidCallback? onScribbleEnd;

  const CanvasOverlay({
    super.key,
    this.elements = const [],
    this.selectedId,
    this.onElementChanged,
    this.onSelect,
    this.onDelete,
    this.drawnShapes = const [],
    this.selectedShapeId,
    this.selectedShapeIds = const {},
    this.onShapeChanged,
    this.onShapeSelect,
    this.onShapeDelete,
    this.scribbleMode = false,
    this.scribblePoints = const [],
    this.onScribbleMove,
    this.onScribbleEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty && drawnShapes.isEmpty && !scribbleMode) {
      return const SizedBox.shrink();
    }
    final sorted = List<FreeTextShape>.from(elements)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    final sortedShapes = List<DrawnShape>.from(drawnShapes)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth == 0 ? 1.0 : constraints.maxWidth;
        final h = constraints.maxHeight == 0 ? 1.0 : constraints.maxHeight;
        final overlay = Stack(
          children: [
            for (final el in sorted)
              _DraggableTextShape(
                key: ValueKey(el.id),
                element: el,
                isSelected: el.id == selectedId,
                onChanged: (updated) => onElementChanged?.call(updated),
                onTap: () => onSelect?.call(el.id),
                onDelete: onDelete != null ? () => onDelete?.call(el.id) : null,
              ),
            for (final shape in sortedShapes)
              _DraggableShapeOverlay(
                key: ValueKey('shape_${shape.id}'),
                shape: shape,
                isSelected: selectedShapeIds.isNotEmpty
                    ? selectedShapeIds.contains(shape.id)
                    : shape.id == selectedShapeId,
                onChanged: (updated) => onShapeChanged?.call(updated),
                onTap: () => onShapeSelect?.call(shape.id),
                onDelete: onShapeDelete != null
                    ? () => onShapeDelete?.call(shape.id)
                    : null,
              ),
          ],
        );
        if (!scribbleMode) return overlay;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (d) => onScribbleMove?.call(
              Offset2D(d.localPosition.dx / w, d.localPosition.dy / h)),
          onPanUpdate: (d) => onScribbleMove?.call(
              Offset2D(d.localPosition.dx / w, d.localPosition.dy / h)),
          onPanEnd: (_) => onScribbleEnd?.call(),
          onPanCancel: onScribbleEnd,
          child: Stack(
            children: [
              overlay,
              // Scribble preview while drawing.
              if (scribblePoints.length >= 2)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScribblePainter(scribblePoints),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints the in-progress scribble stroke (Track 21, P4).
class _ScribblePainter extends CustomPainter {
  final List<Offset2D> points;
  _ScribblePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF4472C4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScribblePainter old) => true;
}

class _DraggableTextShape extends StatefulWidget {
  final FreeTextShape element;
  final bool isSelected;
  final ValueChanged<FreeTextShape> onChanged;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _DraggableTextShape({
    super.key,
    required this.element,
    required this.isSelected,
    required this.onChanged,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_DraggableTextShape> createState() => _DraggableTextShapeState();
}

class _DraggableTextShapeState extends State<_DraggableTextShape> {
  late FreeTextShape _draft;

  /// True while the user is dragging/resizing so external rebuilds don't
  /// clobber the in-flight gesture.
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.element;
  }

  @override
  void didUpdateWidget(_DraggableTextShape old) {
    super.didUpdateWidget(old);
    // Sync external edits (dialog, undo/redo, …) which rebuild the element
    // list with new instances of the same id — otherwise the overlay keeps
    // showing stale content and a later drag would push the old value back.
    if (old.element.id != widget.element.id || !_dragging) {
      _draft = widget.element;
    }
  }

  void _emit() => widget.onChanged(_draft);

  @override
  Widget build(BuildContext context) {
    final el = _draft;
    final bg = el.backgroundColor == 'transparent'
        ? null
        : _parseColor(el.backgroundColor);
    final borderColor = el.borderColor.isNotEmpty
        ? _parseColor(el.borderColor)
        : null;

    return Positioned(
      left: el.x * 4, // rough px conversion (400px slide preview)
      top: el.y * 4,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) => _dragging = true,
        onPanEnd: (_) => _dragging = false,
        onPanUpdate: (details) {
          setState(() {
            _draft = _draft.copyWith(
              x: _draft.x + details.delta.dx / 4,
              y: _draft.y + details.delta.dy / 4,
            );
          });
          _emit();
        },
        child: Container(
          width: el.w * 4,
          height: el.h * 4,
          decoration: BoxDecoration(
            color: bg,
            border: borderColor != null && el.borderWidth > 0
                ? Border.all(color: borderColor, width: el.borderWidth)
                : (widget.isSelected
                    ? Border.all(color: Colors.blueAccent, width: 2)
                    : null),
            borderRadius: BorderRadius.circular(4),
            boxShadow: el.shadow
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(2, 2))]
                : null,
          ),
          transform: el.rotation != 0
              ? Matrix4.rotationZ(el.rotation * 3.14159 / 180)
              : null,
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    el.text,
                    style: TextStyle(
                      fontSize: el.fontSize,
                      fontFamily: el.fontFamily,
                      fontWeight: _fontWeight(el.fontWeight),
                      fontStyle: el.fontStyle == 'italic'
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: _parseColor(el.color) ?? Colors.black,
                    ),
                  ),
                ),
              ),
              // Resize handle
              if (widget.isSelected)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _draft = _draft.copyWith(
                          w: _draft.w + details.delta.dx / 4,
                          h: _draft.h + details.delta.dy / 4,
                        );
                      });
                      _emit();
                    },
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              // Delete button
              if (widget.isSelected && widget.onDelete != null)
                Positioned(
                  right: -8,
                  top: -8,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parse a hex colour string into a [Color], or return null.
Color? _parseColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  if (clean.length != 6 && clean.length != 8) return null;
  final val = int.tryParse(clean, radix: 16);
  if (val == null) return null;
  if (clean.length == 6) return Color(0xFF000000 | val);
  return Color(val);
}

/// Map a weight string to a [FontWeight].
FontWeight _fontWeight(String w) {
  switch (w) {
    case 'bold': return FontWeight.bold;
    case 'w100': return FontWeight.w100;
    case 'w200': return FontWeight.w200;
    case 'w300': return FontWeight.w300;
    case 'w400': return FontWeight.w400;
    case 'w500': return FontWeight.w500;
    case 'w600': return FontWeight.w600;
    case 'w700': return FontWeight.w700;
    case 'w800': return FontWeight.w800;
    case 'w900': return FontWeight.w900;
    default: return FontWeight.normal;
  }
}

/// A draggable overlay for a [DrawnShape] on the canvas (Track 21, P7).
class _DraggableShapeOverlay extends StatefulWidget {
  final DrawnShape shape;
  final bool isSelected;
  final ValueChanged<DrawnShape> onChanged;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _DraggableShapeOverlay({
    super.key,
    required this.shape,
    required this.isSelected,
    required this.onChanged,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_DraggableShapeOverlay> createState() => _DraggableShapeOverlayState();
}

class _DraggableShapeOverlayState extends State<_DraggableShapeOverlay> {
  late DrawnShape _draft;

  /// True while the user is dragging/resizing so external rebuilds don't
  /// clobber the in-flight gesture.
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.shape;
  }

  @override
  void didUpdateWidget(_DraggableShapeOverlay old) {
    super.didUpdateWidget(old);
    // Sync external edits (properties dialog, undo/redo, …) which rebuild the
    // list with new instances of the same id — otherwise the overlay keeps
    // showing stale content and a later drag would push the old value back.
    if (old.shape.id != widget.shape.id || !_dragging) {
      _draft = widget.shape;
    }
  }

  void _emit() => widget.onChanged(_draft);

  @override
  Widget build(BuildContext context) {
    final el = _draft;
    final fillColor = _parseColor(el.fillColor) ?? Colors.blueAccent;
    final strokeColor = _parseColor(el.strokeColor) ?? Colors.black;
    return Positioned(
      left: el.x * 4,
      top: el.y * 4,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) => _dragging = true,
        onPanEnd: (_) => _dragging = false,
        onPanUpdate: (details) {
          setState(() {
            _draft = _draft.copyWith(
              x: _draft.x + details.delta.dx / 4,
              y: _draft.y + details.delta.dy / 4,
            );
          });
          _emit();
        },
        child: Container(
          width: el.w * 4,
          height: el.h * 4,
          decoration: BoxDecoration(
            color: fillColor.withValues(alpha: 1.0 - el.fillTransparency),
            border: Border.all(
              color: widget.isSelected ? Colors.blueAccent : strokeColor,
              width: widget.isSelected ? 2 : el.strokeWidth,
            ),
            borderRadius: el.type == ShapeType.oval
                ? BorderRadius.circular(el.w * 2)
                : BorderRadius.circular(2),
            boxShadow: el.mergeOp == 'shadow'
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(2, 2))]
                : null,
          ),
          transform: el.rotation != 0
              ? Matrix4.rotationZ(el.rotation * 3.14159 / 180)
              : null,
          child: Stack(
            children: [
              Center(
                child: Text(
                  el.type.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _contrastColor(fillColor),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Resize handle
              if (widget.isSelected)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _draft = _draft.copyWith(
                          w: _draft.w + details.delta.dx / 4,
                          h: _draft.h + details.delta.dy / 4,
                        );
                      });
                      _emit();
                    },
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              // Delete button
              if (widget.isSelected && widget.onDelete != null)
                Positioned(
                  right: -8,
                  top: -8,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}