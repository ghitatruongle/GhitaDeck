import 'dart:async';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';
import '../../providers/presentation_state.dart';
import '../../models/drawn_shape.dart';
import '../../models/slide_template.dart';
import '../../services/format_painter_service.dart';
import '../../services/html_sanitizer_service.dart';
import '../../utils/effect_helpers.dart';
import '../../utils/error_mapper.dart';
import '../../l10n/l10n.dart';

/// Centralized editor state for the PowerPoint-style editor.
///
/// Manages HTML editing, slide CRUD, template application, export dialogs,
/// and live preview — extracted from the monolithic HtmlToPPTScreen.
class EditorState with ChangeNotifier {
  // ---- Controllers ----
  final htmlController = TextEditingController();
  final titleController = TextEditingController();
  final notesController = TextEditingController();

  // ---- Editing mode ----
  int? _editingIndex;
  SlideEffect? _slideEffectOverride;
  bool _isLoading = false;

  // ---- Live preview (debounced) ----
  Timer? _previewTimer;
  String _previewHtml = '';
  double _zoomLevel = 1.0;
  bool _showNotes = false;
  bool _showPreview = true;
  int _selectedSlideIndex = -1;

  // ---- Shape selection & scribble (Track 21, P4) ----
  Set<String> _selectedShapeIds = {};
  bool _scribbleMode = false;
  List<Offset2D> _scribblePoints = [];

  Set<String> get selectedShapeIds => _selectedShapeIds;
  bool get scribbleMode => _scribbleMode;
  List<Offset2D> get scribblePoints => _scribblePoints;

  /// Replace the shape selection (single click) or toggle a member
  /// (shift/multi click).
  void selectShape(String id, {bool multi = false}) {
    if (multi) {
      final next = Set<String>.of(_selectedShapeIds);
      if (!next.add(id)) next.remove(id);
      _selectedShapeIds = next;
    } else {
      _selectedShapeIds = {id};
    }
    notifyListeners();
  }

  void clearShapeSelection() {
    if (_selectedShapeIds.isEmpty) return;
    _selectedShapeIds = {};
    notifyListeners();
  }

  void setScribbleMode(bool value) {
    _scribbleMode = value;
    if (!value) _scribblePoints = [];
    notifyListeners();
  }

  void addScribblePoint(Offset2D p) {
    _scribblePoints = [..._scribblePoints, p];
    notifyListeners();
  }

  void finishScribble() {
    _scribblePoints = [];
    _scribbleMode = false;
    notifyListeners();
  }

  // ---- Format Painter (Track 24) ----
  final FormatPainterService _formatPainter = FormatPainterService();

  FormatPainterService get formatPainter => _formatPainter;
  bool get formatPainterArmed => _formatPainter.isArmed;

  /// Capture the format of the current text selection (or a selected shape
  /// when [selectedShape] is provided). Ctrl+Shift+C.
  void captureFormat({DrawnShape? selectedShape}) {
    if (selectedShape != null) {
      _formatPainter.capture(FormatSnapshot.fromShape(selectedShape));
    } else {
      final text = htmlController.text;
      final sel = htmlController.selection;
      final fragment = (sel.isValid && sel.start < sel.end && sel.end <= text.length)
          ? text.substring(sel.start, sel.end)
          : text;
      _formatPainter.capture(FormatSnapshot.fromHtmlFragment(fragment));
    }
    notifyListeners();
  }

  /// Apply the captured format to the current text selection. Returns false
  /// when there is no armed snapshot or nothing selected. Ctrl+Shift+V.
  bool pasteFormatToSelection() {
    final snap = _formatPainter.use();
    if (snap == null) return false;
    final text = htmlController.text;
    final sel = htmlController.selection;
    if (!sel.isValid || sel.start >= sel.end || sel.end > text.length) {
      return false;
    }
    final selected = text.substring(sel.start, sel.end);
    final wrapped = snap.applyToSelection(selected);
    htmlController.text = text.replaceRange(sel.start, sel.end, wrapped);
    htmlController.selection =
        TextSelection.collapsed(offset: sel.start + wrapped.length);
    _schedulePreviewUpdate();
    notifyListeners();
    return true;
  }

  /// Apply the captured format to a DrawnShape. Returns the updated shape or
  /// null when no snapshot is armed.
  DrawnShape? pasteFormatToShape(DrawnShape shape) {
    final snap = _formatPainter.use();
    if (snap == null) return null;
    return snap.applyToShape(shape);
  }

  void clearFormatPainter() {
    _formatPainter.clear();
    notifyListeners();
  }

  // ---- Getters ----
  int? get editingIndex => _editingIndex;
  SlideEffect? get slideEffectOverride => _slideEffectOverride;
  bool get isLoading => _isLoading;
  String get previewHtml => _previewHtml;
  double get zoomLevel => _zoomLevel;
  bool get showNotes => _showNotes;
  bool get showPreview => _showPreview;
  int get selectedSlideIndex => _selectedSlideIndex;
  bool get isEditing => _editingIndex != null;

  EditorState() {
    titleController.text = 'New Slide';
    htmlController.addListener(_schedulePreviewUpdate);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    htmlController.dispose();
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ---- Preview debounce ----

  void _schedulePreviewUpdate() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 500), () {
      _previewHtml = htmlController.text;
      notifyListeners();
    });
  }

  // ---- Zoom ----

  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(0.5, 2.0);
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoomLevel + 0.1);
  void zoomOut() => setZoom(_zoomLevel - 0.1);

  // ---- UI toggles ----

  void toggleNotes() {
    _showNotes = !_showNotes;
    notifyListeners();
  }

  void togglePreview() {
    _showPreview = !_showPreview;
    notifyListeners();
  }

  // ---- Slide selection ----

  void selectSlide(int index) {
    _selectedSlideIndex = index;
    notifyListeners();
  }

  // ---- Public setters for private fields (accessed from other files) ----

  void setSlideEffectOverride(SlideEffect? effect) {
    _slideEffectOverride = effect;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ---- HTML tag insertion ----

  void insertHtmlTag(String open, String close) {
    final text = htmlController.text;
    final selection = htmlController.selection;
    if (selection.isValid &&
        selection.start >= 0 &&
        selection.end <= text.length) {
      final selectedText = text.substring(selection.start, selection.end);
      final replacement = '$open$selectedText$close';
      final newText =
          text.replaceRange(selection.start, selection.end, replacement);
      htmlController.text = newText;
      htmlController.selection = TextSelection.collapsed(
        offset: selection.start + open.length + selectedText.length,
      );
    } else {
      // No selection: insert the pair and place the caret between the tags so
      // typing continues inside the newly opened element.
      final newText = '$text$open$close';
      htmlController.text = newText;
      htmlController.selection = TextSelection.collapsed(
        offset: text.length + open.length,
      );
    }
  }

  /// Insert raw HTML at the cursor (or append when there is no valid
  /// selection). Used by the ribbon Insert tab.
  void insertHtml(String html) {
    final text = htmlController.text;
    final selection = htmlController.selection;
    if (selection.isValid &&
        selection.start >= 0 &&
        selection.end <= text.length) {
      final newText = text.replaceRange(selection.start, selection.end, html);
      htmlController.text = newText;
      htmlController.selection = TextSelection.collapsed(
        offset: selection.start + html.length,
      );
    } else {
      htmlController.text = '$text$html';
    }
  }

  // ---- Input Validation ----
  // Returns error message string on failure, or null on success (sets _lastSanitizedHtml).

  String? _lastSanitizedHtml;

  /// Validate and sanitize HTML. Returns error message on failure, null on success.
  String? validateAndSanitizeHtml(String rawHtml) {
    final error = HtmlSanitizerService.validate(rawHtml);
    if (error != null) return error;
    _lastSanitizedHtml = HtmlSanitizerService.sanitize(rawHtml).html;
    return null; // null = no error
  }

  /// Get the last sanitized HTML (call after validateAndSanitizeHtml returns null).
  String get lastSanitizedHtml => _lastSanitizedHtml ?? '';

  // ---- Add / Update Slide ----

  /// Begin a brand-new blank slide: appends it to the deck and opens it in the
  /// editor for immediate editing. Used by the slide panel "+" button and the
  /// sidebar "New Slide" action so clicking + always produces a slide.
  void startNewSlide(BuildContext context) {
    final state = Provider.of<PresentationState>(context, listen: false);
    final slide = Slide(
      title: 'New Slide',
      htmlContent: '<h1>New Slide</h1>\n<p>Click to edit</p>',
    );
    state.addSlide(slide);
    final newIndex = state.slides.length - 1;
    state.setCurrentSlide(newIndex);
    editSlide(newIndex, state);
  }

  /// Reconcile selection/editing state after a slide was removed at
  /// [removedIndex] (deck length is now [newLength]). Prevents stale indices
  /// that would silently update the wrong slide or crash with a RangeError.
  void handleSlideRemoved(int removedIndex, int newLength) {
    if (_selectedSlideIndex == removedIndex) {
      _selectedSlideIndex = -1;
    } else if (removedIndex < _selectedSlideIndex) {
      _selectedSlideIndex--;
    }
    if (_selectedSlideIndex >= newLength) _selectedSlideIndex = newLength - 1;

    if (_editingIndex != null) {
      if (_editingIndex == removedIndex) {
        clearEditor();
      } else if (removedIndex < _editingIndex!) {
        _editingIndex = _editingIndex! - 1;
      }
    }
    notifyListeners();
  }

  Future<void> addOrUpdateSlide(BuildContext context) async {
    final rawHtml = htmlController.text.trim();
    final error = validateAndSanitizeHtml(rawHtml);
    if (error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    final sanitizedHtml = lastSanitizedHtml;
    final state = Provider.of<PresentationState>(context, listen: false);

    _isLoading = true;
    notifyListeners();

    try {
      final document = html_parser.parse(sanitizedHtml);
      String title = titleController.text.trim();

      final h1 = document.querySelector('h1');
      if (h1 != null && h1.text.isNotEmpty) {
        title = h1.text;
      } else if (title.isEmpty) {
        title = 'Untitled Slide';
      }

      final slide = Slide(
        title: title,
        htmlContent: sanitizedHtml,
        notes: notesController.text.trim(),
        effect: _slideEffectOverride,
      );

      if (_editingIndex != null) {
        state.updateSlide(_editingIndex!, slide);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.slideUpdated)),
          );
        }
      } else {
        state.addSlide(slide);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.slideAddedSuccess)),
          );
        }
      }

      clearEditor();
    } catch (e) {
      if (context.mounted) {
        ErrorMapper.showErrorSnackBar(context, e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---- Edit existing slide ----

  void editSlide(int index, PresentationState state) {
    if (index < 0 || index >= state.slides.length) return;

    final slide = state.slides[index];
    htmlController.text = slide.htmlContent;
    titleController.text = slide.title;
    notesController.text = slide.notes;
    _editingIndex = index;
    _slideEffectOverride = slide.effect;
    _selectedSlideIndex = index;
    // Force preview update immediately (don't wait for debounce)
    _previewHtml = slide.htmlContent;
    notifyListeners();
  }

  // ---- Clear editor ----

  void clearEditor() {
    htmlController.clear();
    titleController.text = 'New Slide';
    notesController.clear();
    _editingIndex = null;
    _slideEffectOverride = null;
    notifyListeners();
  }

  // ---- Apply template ----

  void applyTemplate(SlideTemplate template, BuildContext context) {
    htmlController.text = template.htmlContent;
    titleController.text = _extractTitleFromHtml(template.htmlContent);
    _editingIndex = null;
    // Force preview update immediately
    _previewHtml = template.htmlContent;

    final state = Provider.of<PresentationState>(context, listen: false);
    state.setEffect(template.recommendedEffect);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied "${template.name}" template!'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    notifyListeners();
  }

  String _extractTitleFromHtml(String html) {
    try {
      final doc = html_parser.parse(html);
      final h1 = doc.querySelector('h1');
      if (h1 != null && h1.text.trim().isNotEmpty) {
        return h1.text.trim();
      }
    } catch (_) {}
    return 'New Slide';
  }

  // ---- Effect name display ----

  static String effectName(SlideEffect effect) => EffectHelpers.effectName(effect);
}
