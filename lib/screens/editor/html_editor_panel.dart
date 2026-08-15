import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/presentation_state.dart';
import '../../models/free_shape.dart';
import '../../models/drawn_shape.dart';
import '../../screens/widgets/slide_preview.dart';
import '../../screens/widgets/wysiwyg_toolbar.dart';
import '../../screens/widgets/audio_recorder_panel.dart';
import '../../services/eyedropper_service.dart';
import '../../services/wysiwyg_service.dart';
import '../editor/editor_state.dart';
import 'canvas_overlay.dart';

/// Central editor panel containing the HTML editor, WYSIWYG toolbar,
/// and live preview — the main content editing area.
class HtmlEditorPanel extends StatefulWidget {
  const HtmlEditorPanel({super.key});

  @override
  State<HtmlEditorPanel> createState() => _HtmlEditorPanelState();
}

class _HtmlEditorPanelState extends State<HtmlEditorPanel> {
  String? _selectedFreeTextId;
  String? _selectedShapeId;

  @override
  Widget build(BuildContext context) {
    final editorState = Provider.of<EditorState>(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Title + Notes bar (compact)
          _buildTitleBar(context, editorState, theme),

          const Divider(height: 1),

          // WYSIWYG toolbar
          WysiwygToolbar(
            onInsertTag: editorState.insertHtmlTag,
            formatPainterArmed: editorState.formatPainterArmed,
            onFormatPainter: () => _handleFormatPainter(context, editorState),
            onEyedropper: () => _handleEyedropper(context),
            onPickColor: (hex) => _applySelectionFormat(
                editorState,
                (h, s, e) =>
                    WysiwygService.colorSelection(h, s, e, hex)),
            onListNumbered: () => _applySelectionFormat(editorState,
                (h, s, e) => WysiwygService.wrapSelection(h, s, e, '<ol>\n  <li>', '</li>\n</ol>')),
            onQuote: () => _applySelectionFormat(editorState,
                (h, s, e) => WysiwygService.wrapSelection(h, s, e, '<blockquote>', '</blockquote>')),
          ),

          const Divider(height: 1),

          // Editor + Preview
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HTML editor
                Expanded(
                  flex: editorState.showPreview ? 3 : 1,
                  child: _buildHtmlEditor(context, editorState, theme),
                ),

                // Live preview
                if (editorState.showPreview) ...[
                  VerticalDivider(width: 1, color: theme.dividerColor),
                  Expanded(
                    flex: 2,
                    child: _buildLivePreview(context, editorState, theme),
                  ),
                ],
              ],
            ),
          ),

          // Notes panel (toggleable)
          if (editorState.showNotes) ...[
            const Divider(height: 1),
            _buildNotesPanel(context, editorState, theme),
          ],

          // Bottom action bar (compact)
          const Divider(height: 1),
          _buildActionBar(context, editorState, theme),
        ],
      ),
    );
  }

  Widget _buildTitleBar(
      BuildContext context, EditorState editorState, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Row(
        children: [
          // Editing indicator
          if (editorState.isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Editing #${editorState.editingIndex! + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Title field
          Expanded(
            child: TextField(
              controller: editorState.titleController,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Slide title...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.title, size: 16, color: theme.colorScheme.outline),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
          ),

          // Transition effect dropdown
          _buildEffectDropdown(context, editorState, theme),

          const SizedBox(width: 4),

          // Preview toggle
          IconButton(
            icon: Icon(
              editorState.showPreview ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            tooltip: 'Toggle Preview',
            onPressed: editorState.togglePreview,
            visualDensity: VisualDensity.compact,
          ),

          // Notes toggle
          IconButton(
            icon: Icon(
              editorState.showNotes ? Icons.notes : Icons.notes_outlined,
              size: 18,
            ),
            tooltip: 'Toggle Notes',
            onPressed: editorState.toggleNotes,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEffectDropdown(
      BuildContext context, EditorState editorState, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<SlideEffect?>(
        value: editorState.slideEffectOverride,
        hint: Text('Effect', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
        underline: const SizedBox.shrink(),
        isDense: true,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
        items: [
          DropdownMenuItem<SlideEffect?>(
            value: null,
            child: Text('Deck effect', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          ),
          ...SlideEffect.values.map(
            (e) => DropdownMenuItem<SlideEffect?>(
              value: e,
              child: Text(EditorState.effectName(e), style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
        onChanged: (val) {
          editorState.setSlideEffectOverride(val);
        },
      ),
    );
  }

  Widget _buildHtmlEditor(
      BuildContext context, EditorState editorState, ThemeData theme) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextFormField(
            controller: editorState.htmlController,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: ['monospace'],
              fontSize: 13,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '<h1>Title</h1>\n<p>Content...</p>\n<ul>\n  <li>Item</li>\n</ul>',
              hintStyle: TextStyle(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                fontFamily: 'Consolas',
                fontFamilyFallback: const ['monospace'],
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(8),
            ),
            keyboardType: TextInputType.multiline,
          ),
        ),
        if (editorState.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildLivePreview(
      BuildContext context, EditorState editorState, ThemeData theme) {
    return Column(
      children: [
        // Preview header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          ),
          child: Row(
            children: [
              Icon(Icons.preview, size: 12, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Zoom controls
              IconButton(
                icon: const Icon(Icons.remove, size: 14),
                onPressed: editorState.zoomOut,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
              Text(
                '${(editorState.zoomLevel * 100).round()}%',
                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14),
                onPressed: editorState.zoomIn,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ],
          ),
        ),
        // Preview content
        Expanded(
          child: editorState.previewHtml.trim().isEmpty
              ? Center(
                  child: Text(
                    'Start typing to see preview',
                    style: TextStyle(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                )
              : ClipRect(
                  child: Transform.scale(
                    scale: editorState.zoomLevel,
                    alignment: Alignment.topCenter,
                    child: Stack(
                      children: [
                        SlidePreview(
                          title: editorState.titleController.text,
                          html: editorState.previewHtml,
                        ),
                        // Track 17, P2/P7: free-form text overlay on the
                        // preview — drag to move, resize handle, delete.
                        _buildCanvasOverlay(context, editorState),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCanvasOverlay(
      BuildContext context, EditorState editorState) {
    final presentationState = Provider.of<PresentationState>(context);
    if (presentationState.slides.isEmpty) return const SizedBox.shrink();
    final slide =
        presentationState.slides[presentationState.currentSlideIndex];
    final raw = slide.visualElements['freeTexts'];
    final elements = raw is List
        ? raw
            .map((e) => e is Map<String, dynamic>
                ? FreeTextShape.fromMap(e)
                : (e is Map
                    ? FreeTextShape.fromMap(Map<String, dynamic>.from(e))
                    : null))
            .whereType<FreeTextShape>()
            .toList()
        : <FreeTextShape>[];
    // Track 21, P7: shapes overlay (visualElements['shapes']).
    final rawShapes = slide.visualElements['shapes'];
    final shapes = rawShapes is List
        ? rawShapes
            .map((e) => e is Map<String, dynamic>
                ? DrawnShape.fromMap(e)
                : (e is Map
                    ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                    : null))
            .whereType<DrawnShape>()
            .toList()
        : <DrawnShape>[];
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: CanvasOverlay(
          elements: elements,
          selectedId: _selectedFreeTextId,
          onElementChanged: (updated) {
            final idx = elements.indexWhere((e) => e.id == updated.id);
            if (idx < 0) return;
            final copy = List<FreeTextShape>.from(elements);
            copy[idx] = updated;
            // Drag/resize streams must not flood the undo history — the
            // discrete dialog edits record their own snapshot (Track 17, P8).
            presentationState.updateFreeTexts(copy, record: false);
          },
          onSelect: (id) => setState(() => _selectedFreeTextId = id),
          onDelete: (id) {
            presentationState.updateFreeTexts(
              elements.where((e) => e.id != id).toList(),
            );
            setState(() => _selectedFreeTextId = null);
          },
          // Track 21, P7: shapes overlay.
          drawnShapes: shapes,
          selectedShapeId: _selectedShapeId,
          selectedShapeIds: editorState.selectedShapeIds,
          onShapeChanged: (updated) {
            final idx = shapes.indexWhere((e) => e.id == updated.id);
            if (idx < 0) return;
            final copy = List<DrawnShape>.from(shapes);
            copy[idx] = updated;
            // Drag streams don't record history; discrete ops do (Track 21, P8).
            _updateShapes(presentationState, copy, record: false);
          },
          // Track 21, P4: click selects (or shift-click toggles multi-select).
          onShapeSelect: (id) {
            final hw = HardwareKeyboard.instance;
            final pressed = hw.logicalKeysPressed;
            final shift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
                pressed.contains(LogicalKeyboardKey.shiftRight);
            editorState.selectShape(id, multi: shift);
            setState(() => _selectedShapeId = id);
          },
          onShapeDelete: (id) {
            _updateShapes(
              presentationState,
              shapes.where((e) => e.id != id).toList(),
            );
            editorState.clearShapeSelection();
            setState(() => _selectedShapeId = null);
          },
          // Track 21, P4: scribble drawing mode.
          scribbleMode: editorState.scribbleMode,
          scribblePoints: editorState.scribblePoints,
          onScribbleMove: (p) => editorState.addScribblePoint(p),
          onScribbleEnd: () {
            final pts = editorState.scribblePoints;
            if (pts.length >= 3) {
              _insertScribbleShape(presentationState, pts);
            }
            editorState.finishScribble();
          },
        ),
      ),
    );
  }

  /// Write the shapes list back into the current slide's visualElements.
  /// Discrete operations (delete, dialog edit) record undo history; drag
  /// streams pass [record] = false (Track 21, P8).
  void _updateShapes(PresentationState state, List<DrawnShape> shapes,
      {bool record = true}) {
    state.updateShapes(shapes, record: record);
  }

  /// Track 21, P4: convert a scribble stroke (relative 0..1 canvas points)
  /// into a freeform DrawnShape and insert it.
  void _insertScribbleShape(
      PresentationState state, List<Offset2D> points) {
    // Normalise the stroke to its own bounding box.
    var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (maxX - minX < 0.005 || maxY - minY < 0.005) return;
    final rel = [
      for (final p in points)
        Offset2D((p.dx - minX) / (maxX - minX), (p.dy - minY) / (maxY - minY)),
    ];
    // Smooth: drop points closer than 1.5% of the box to the previous one.
    final cleaned = <Offset2D>[rel.first];
    for (final p in rel.skip(1)) {
      final last = cleaned.last;
      if ((p.dx - last.dx).abs() > 0.015 || (p.dy - last.dy).abs() > 0.015) {
        cleaned.add(p);
      }
    }
    if (cleaned.length < 3) return;
    final shape = DrawnShape(
      id: 'shape_${DateTime.now().millisecondsSinceEpoch}',
      type: ShapeType.freeform,
      x: minX * 100,
      y: minY * 100,
      w: (maxX - minX) * 100,
      h: (maxY - minY) * 100,
      fillColor: '#4472C4',
      fillTransparency: 0.35,
      strokeColor: '#4472C4',
      strokeWidth: 2,
      freeformPath: DrawnShape.pathFromPoints(cleaned, w: 100, h: 100),
    );
    state.upsertShape(shape);
  }

  /// Track 24: Format Painter capture/paste. When armed the next click pastes
  /// Apply a WysiwygService format operation to the HTML source selection,
  /// keeping the selection range on the new text (Track 63, OPT 15).
  void _applySelectionFormat(
    EditorState editorState,
    FormatResult Function(String html, int s, int e) op,
  ) {
    final controller = editorState.htmlController;
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed || sel.start < 0 ||
        sel.end > controller.text.length) {
      return;
    }
    final res = op(controller.text, sel.start, sel.end);
    controller.value = TextEditingValue(
      text: res.html,
      selection: TextSelection(
        baseOffset: res.start.clamp(0, res.html.length),
        extentOffset: res.end.clamp(0, res.html.length),
      ),
    );
  }

  /// onto the current text selection or the selected shape; otherwise it
  /// captures the current selection's format.
  void _handleFormatPainter(
      BuildContext context, EditorState editorState) {
    if (editorState.formatPainterArmed) {
      final pasted = editorState.pasteFormatToSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pasted
                ? 'Format pasted'
                : 'Select some text first, or select a shape to format'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      editorState.captureFormat();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format captured — select the target and paste'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Track 24: capture the colour under the cursor via the Windows GDI API
  /// and copy the hex value to the clipboard.
  Future<void> _handleEyedropper(BuildContext context) async {
    final color = EyedropperService.pickAtCursor();
    if (color == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture the colour (Windows only)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: color));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Colour $color copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildNotesPanel(
      BuildContext context, EditorState editorState, ThemeData theme) {
    final presentationState = Provider.of<PresentationState>(context);
    return Container(
      height: 150,
      padding: const EdgeInsets.all(6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                'Speaker Notes',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                onPressed: editorState.toggleNotes,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ],
          ),
          Expanded(
            child: TextField(
              controller: editorState.notesController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Notes for the presenter...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.all(4),
              ),
            ),
          ),
          // Track 13, P1: per-slide narration recorder next to the notes box.
          const Divider(height: 1),
          AudioRecorderPanel(slideIndex: presentationState.currentSlideIndex),
        ],
      ),
    );
  }

  Widget _buildActionBar(
      BuildContext context, EditorState editorState, ThemeData theme) {
    final presentationState = Provider.of<PresentationState>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      ),
      child: Row(
        children: [
          // Add/Update button
          FilledButton.icon(
            onPressed: editorState.isLoading
                ? null
                : () => editorState.addOrUpdateSlide(context),
            icon: Icon(editorState.isEditing ? Icons.save : Icons.add, size: 14),
            label: Text(
              editorState.isEditing ? 'Update' : 'Add Slide',
              style: const TextStyle(fontSize: 11),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),

          if (editorState.isEditing) ...[
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: editorState.clearEditor,
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Cancel', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],

          const Spacer(),

          // Present button
          if (presentationState.slides.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: SlidePreview(
                        title: presentationState.presentationTitle,
                        html: presentationState.buildHtmlDeck(),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Present', style: TextStyle(fontSize: 11)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
