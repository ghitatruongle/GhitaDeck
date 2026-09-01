import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/presentation_state.dart';
import '../../services/template_service.dart';
import '../../services/eyedropper_service.dart';
import '../../services/dictation_service.dart';
import '../../models/chart_data.dart';
import '../../models/icon_item.dart';
import '../../models/media_item.dart';
import '../../models/model3d_item.dart';
import '../../models/slide_layout.dart';
import '../../models/smartart.dart';
import '../../models/slide_template.dart';
import '../../services/stock_media_service.dart';
import '../../screens/present_screen.dart';
import '../../screens/slide_sorter_screen.dart';
import 'editor_state.dart';
import 'slide_list_panel.dart';
import 'html_editor_panel.dart';
import '../widgets/advanced_export_dialog.dart';
import '../widgets/chart_dialog.dart';
import '../widgets/icon_dialog.dart';
import '../widgets/stock_media_dialog.dart';
import '../widgets/smartart_dialog.dart';
import '../widgets/video_dialog.dart';
import '../widgets/model3d_dialog.dart';
import '../widgets/selection_pane.dart';
import '../widgets/guides_align_dialog.dart';
import '../widgets/text_layout_dialog.dart';
import '../widgets/animation_pane.dart';
import '../widgets/transition_dialog.dart';
import '../widgets/screen_capture_dialog.dart';
import '../widgets/screenshot_dialog.dart';
import '../widgets/photo_album_dialog.dart';
import '../widgets/image_editor_dialog.dart';
import '../widgets/free_text_edit_dialog.dart';
import '../widgets/action_button_dialog.dart';
import '../widgets/equation_dialog.dart';
import '../widgets/symbol_dialog.dart';
import '../widgets/ole_dialog.dart';
import '../widgets/zoom_dialog.dart';
import '../widgets/cameo_dialog.dart';
import '../widgets/shape_tools_dialog.dart';
import '../widgets/shape_properties_dialog.dart';
import '../widgets/header_footer_dialog.dart';
import '../widgets/collaboration_panel.dart';
import '../widgets/comments_panel.dart';
import '../widgets/profile_cloud_dialogs.dart';
import '../widgets/layout_picker.dart';
import '../widgets/designer_panel.dart';
import '../widgets/reuse_compare_dialog.dart';
import '../widgets/m9_productivity_dialogs.dart';
import '../widgets/import_dialog.dart';
import '../widgets/ribbon_customize_dialog.dart';
import '../../l10n/l10n.dart';
import '../../utils/snackbar_helper.dart';
import '../../models/free_shape.dart';
import '../../models/drawn_shape.dart';
import '../../services/action_button_service.dart';
import '../../services/equation_service.dart';
import '../../services/ole_service.dart';
import '../../services/header_footer_service.dart';
import '../../services/zoom_feature_service.dart';
import '../../services/cameo_service.dart';

/// Main editor shell with PowerPoint-style 3-panel layout:
/// Left: Slide thumbnails | Center: HTML editor + preview | Right: (future Properties)
///
/// This replaces the monolithic HtmlToPPTScreen with a clean, composable layout.
///
/// The EditorState is owned by HomeScreen (single source of truth so the
/// ribbon toolbar and status bar can drive the same editor instance); this
/// shell resolves it from the provider scope instead of creating its own.
enum _EditorAuxPane { selection, animation, comments, designer }

class EditorShell extends StatefulWidget {
  const EditorShell({super.key});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  EditorState get _editorState =>
      Provider.of<EditorState>(context, listen: false);

  /// Track 26, P2: whether the Selection Pane is docked on the right.
  bool _showSelectionPane = false;

  /// Track 30, P1: whether the Animation Pane is docked on the right.
  bool _showAnimationPane = false;

  /// Track 48, P2: whether the Comments pane is docked on the right.
  bool _showCommentsPane = false;

  /// Track 54, P3: whether the Designer pane is docked on the right.
  bool _showDesignerPane = false;

  /// Track 56, FEAT 90: dictation engine + live state.
  final DictationService _dictation = DictationService();
  bool _dictating = false;

  /// Track 62, FEAT 100: read-aloud bar visibility.
  bool _showReadAloudBar = false;

  /// Resizable slide list sidebar width (defaults to 180, resizable 110-360)
  double _sidebarWidth = 180.0;
  bool _isSidebarCollapsed = false;
  bool _showAdvancedTools = false;
  final ScrollController _toolbarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _dictation.addListener(_onDictationChanged);
  }

  void _onDictationChanged() {
    if (mounted && _dictating != _dictation.listening) {
      setState(() => _dictating = _dictation.listening);
    }
  }

  @override
  void dispose() {
    _dictation.removeListener(_onDictationChanged);
    _dictation.dispose();
    _toolbarScrollController.dispose();
    super.dispose();
  }

  void _toggleAuxPane(_EditorAuxPane pane) {
    final wasOpen = switch (pane) {
      _EditorAuxPane.selection => _showSelectionPane,
      _EditorAuxPane.animation => _showAnimationPane,
      _EditorAuxPane.comments => _showCommentsPane,
      _EditorAuxPane.designer => _showDesignerPane,
    };
    setState(() {
      _showSelectionPane = false;
      _showAnimationPane = false;
      _showCommentsPane = false;
      _showDesignerPane = false;
      if (!wasOpen) {
        switch (pane) {
          case _EditorAuxPane.selection:
            _showSelectionPane = true;
          case _EditorAuxPane.animation:
            _showAnimationPane = true;
          case _EditorAuxPane.comments:
            _showCommentsPane = true;
          case _EditorAuxPane.designer:
            _showDesignerPane = true;
        }
      }
    });
  }

  // ---- Export Dialog ----

  Future<void> _showExportDialog() => showDialog<void>(
        context: context,
        builder: (_) => const AdvancedExportDialog(),
      );

  Future<void> _showCollaboration() => showDialog<void>(
        context: context,
        builder: (_) => const CollaborationPanel(),
      );

  /// Insert or edit a SmartArt diagram (Track 10, P5–P7).
  Future<void> _showSmartArtDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => SmartArtDialog(currentHtml: slide.htmlContent),
    );
    if (!mounted) return;
    if (result is SmartArtGraph) {
      presentationState.upsertSmartArt(result);
      if (mounted) {
        showAppSnackBar(context, context.l10n.smartartInserted,
            duration: const Duration(seconds: 1));
      }
    } else if (result is String && result.startsWith('edit:')) {
      final index = int.tryParse(result.substring(5)) ?? -1;
      if (index < 0) return;
      final editResult = await showDialog<Object>(
        context: context,
        builder: (_) => SmartArtDialog(
          currentHtml: slide.htmlContent,
          editIndex: index,
        ),
      );
      if (!mounted) return;
      if (editResult is SmartArtGraph) {
        presentationState.upsertSmartArt(editResult, editIndex: index);
        if (mounted) {
          showAppSnackBar(context, context.l10n.smartartUpdated,
              duration: const Duration(seconds: 1));
        }
      }
    }
  }

  /// Record the screen and insert the result into the current slide
  /// (Track 12, P4: the dialog pops a VideoData consumed by upsertVideo —
  /// the exact Track 11 embed pipeline).
  Future<void> _showScreenCaptureDialog(
      PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<VideoData>(
      context: context,
      builder: (_) => const ScreenCaptureDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertVideo(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.recordInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Take a screenshot (full screen / window / region), open the image editor
  /// for cropping, then insert into the current slide (Track 16, P1–P2).
  Future<void> _showScreenshotDialog(
      PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const ScreenshotDialog(),
    );
    if (!mounted || result == null) return;
    // P2: open the existing image editor for crop before inserting.
    final edited = await showDialog<String>(
      context: context,
      builder: (_) => ImageEditorDialog(imageBytes: result),
    );
    if (!mounted || edited == null) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final imgTag = '<img src="$edited" alt="Screenshot">';
    presentationState.updateSlide(
      presentationState.currentSlideIndex,
      slide.copyWith(htmlContent: '${slide.htmlContent.trimRight()}\n$imgTag'),
    );
    if (mounted) {
      showAppSnackBar(context, context.l10n.screenshotInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Create a photo album: pick multiple images, choose layout, then append
  /// generated slides to the end of the deck (Track 16, P3–P6).
  Future<void> _showPhotoAlbumDialog(
      PresentationState presentationState) async {
    final result = await showDialog<List<Slide>>(
      context: context,
      builder: (_) => const PhotoAlbumDialog(),
    );
    if (!mounted || result == null || result.isEmpty) return;
    for (final slide in result) {
      presentationState.addSlide(slide);
    }
    if (mounted) {
      showAppSnackBar(context, context.l10n.photoAlbumCreated(result.length),
          duration: const Duration(seconds: 2));
    }
  }

  /// Add or edit a free-form text box on the current slide (Track 17, P2).
  /// The element is stored in the slide's `visualElements['freeTexts']`.
  Future<void> _showFreeTextDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final visual = slide.visualElements;
    final rawList = visual['freeTexts'];
    final existing = rawList is List && rawList.isNotEmpty
        ? FreeTextShape.fromMap(Map<String, dynamic>.from(rawList.last as Map))
        : null;
    final result = await showDialog<FreeTextShape>(
      context: context,
      builder: (_) => FreeTextEditDialog(existing: existing),
    );
    if (!mounted || result == null) return;
    final list = rawList is List
        ? rawList
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList()
        : <Map<String, dynamic>>[];
    if (existing != null) {
      // Replace the last element (re-edit).
      list[list.length - 1] = result.toMap();
    } else {
      list.add(result.toMap());
    }
    presentationState.updateFreeTexts(
      list.map(FreeTextShape.fromMap).toList(),
    );
    if (mounted) {
      showAppSnackBar(context, context.l10n.freeTextAdded,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert an action button into the current slide (Track 18, P1–P2).
  Future<void> _showActionButtonDialog(
      PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<ActionButton>(
      context: context,
      builder: (_) => const ActionButtonDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertActionButton(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.actionButtonInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert an equation into the current slide (Track 18, P3–P4).
  Future<void> _showEquationDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<EquationData>(
      context: context,
      builder: (_) => const EquationDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertEquation(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.equationInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert a Unicode symbol into the current slide (Track 18, P5).
  Future<void> _showSymbolDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const SymbolDialog(),
    );
    if (!mounted || result == null) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    presentationState.updateSlide(
      presentationState.currentSlideIndex,
      slide.copyWith(
        htmlContent: '${slide.htmlContent.trimRight()}\n<p>$result</p>',
      ),
    );
    if (mounted) {
      showAppSnackBar(context, context.l10n.symbolInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert an OLE embedded object into the current slide (Track 18, P6).
  Future<void> _showOleDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<OleData>(
      context: context,
      builder: (_) => const OleDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertOle(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.oleInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert a slide zoom (Track 20, P5) or Section/Summary Zoom (P6).
  Future<void> _showZoomDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => ZoomDialog(
        slideCount: presentationState.slides.length,
      ),
    );
    if (!mounted || result == null) return;
    if (result is SectionZoomData) {
      presentationState.upsertSectionZoom(result);
    } else if (result is ZoomItem) {
      presentationState.upsertZoom(result);
    }
    if (mounted) {
      showAppSnackBar(context, context.l10n.zoomInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert a cameo (live camera) placeholder (Track 20, P8).
  Future<void> _showCameoDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<CameoData>(
      context: context,
      builder: (_) => const CameoDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertCameo(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.cameoInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert a shape (Track 21).
  Future<void> _showShapeDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<DrawnShape>(
      context: context,
      builder: (_) => const ShapeToolsDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertShape(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.shapeInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Edit the selected shape's properties (Track 21, P7).
  Future<void> _showShapePropertiesDialog(
      PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final raw = slide.visualElements['shapes'];
    if (raw is! List || raw.isEmpty) {
      showAppSnackBar(context, context.l10n.shapeNoSelection,
          duration: const Duration(seconds: 1));
      return;
    }
    // Edit the last shape in the list.
    final last = DrawnShape.fromMap(Map<String, dynamic>.from(raw.last as Map));
    final result = await showDialog<DrawnShape>(
      context: context,
      builder: (_) => ShapePropertiesDialog(shape: last),
    );
    if (!mounted || result == null) return;
    // Replace the last shape (records undo history — Track 21, P7/P8).
    final copy = List<Map<String, dynamic>>.from(
        raw.map((e) => Map<String, dynamic>.from(e as Map)));
    copy[copy.length - 1] = result.toMap();
    presentationState.updateShapes(
      copy.map(DrawnShape.fromMap).toList(),
    );
    if (mounted) {
      showAppSnackBar(context, context.l10n.shapePropertiesUpdated,
          duration: const Duration(seconds: 1));
    }
  }

  /// Track 21, P4: merge the selected shapes (or the two most recent) with
  /// a real boolean operation.
  Future<void> _showShapeMergeDialog(
      PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final raw = slide.visualElements['shapes'];
    if (raw is! List || raw.length < 2) {
      showAppSnackBar(context, context.l10n.shapeMergeNeedTwo,
          duration: const Duration(seconds: 2));
      return;
    }
    final ids = _editorState.selectedShapeIds.toList();
    final op = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.shapeMerge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.shapeMergeHint,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            _mergeOpTile(
                ctx, 'union', Icons.merge_type, context.l10n.shapeMergeUnion),
            _mergeOpTile(ctx, 'combine', Icons.auto_awesome,
                context.l10n.shapeMergeCombine),
            _mergeOpTile(ctx, 'intersect', Icons.horizontal_split,
                context.l10n.shapeMergeIntersect),
            _mergeOpTile(ctx, 'subtract', Icons.backspace_outlined,
                context.l10n.shapeMergeSubtract),
          ],
        ),
      ),
    );
    if (!mounted || op == null) return;
    final merged = presentationState.mergeShapes(ids, op);
    _editorState.clearShapeSelection();
    if (!mounted) return;
    showAppSnackBar(
      context,
      merged == null ? context.l10n.shapeMergeEmpty : context.l10n.shapeMerged,
      duration: const Duration(seconds: 2),
    );
  }

  Widget _mergeOpTile(
      BuildContext ctx, String op, IconData icon, String label) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: () => Navigator.pop(ctx, op),
    );
  }

  /// Show the Header & Footer dialog (Track 19, P2).
  Future<void> _showHeaderFooterDialog(
      PresentationState presentationState) async {
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => HeaderFooterDialog(current: presentationState.deckMeta),
    );
    if (!mounted || result == null) return;
    if (result is (DeckMeta, bool)) {
      final meta = result.$1;
      presentationState.setDeckMeta(meta);
      if (mounted) {
        showAppSnackBar(context, context.l10n.hfApplied,
            duration: const Duration(seconds: 1));
      }
    }
  }

  /// Insert or edit a 3D model on the current slide (Track 14, P2/P6).
  Future<void> _showModel3dDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => Model3dDialog(currentHtml: slide.htmlContent),
    );
    if (!mounted) return;
    if (result is Model3DData) {
      presentationState.upsertModel3d(result);
      if (mounted) {
        showAppSnackBar(context, context.l10n.model3dInserted,
            duration: const Duration(seconds: 1));
      }
    } else if (result is String && result.startsWith('edit:')) {
      final index = int.tryParse(result.substring(5)) ?? -1;
      if (index < 0) return;
      final editResult = await showDialog<Object>(
        context: context,
        builder: (_) => Model3dDialog(
          currentHtml: slide.htmlContent,
          editIndex: index,
        ),
      );
      if (!mounted) return;
      if (editResult is Model3DData) {
        presentationState.upsertModel3d(editResult, editIndex: index);
        if (mounted) {
          showAppSnackBar(context, context.l10n.model3dUpdated,
              duration: const Duration(seconds: 1));
        }
      }
    }
  }

  /// Insert an icon from the library into the current slide (Track 15, P2).
  Future<void> _showIconDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<IconItem>(
      context: context,
      builder: (_) => const IconDialog(),
    );
    if (!mounted || result == null) return;
    presentationState.upsertIcon(result);
    if (mounted) {
      showAppSnackBar(context, context.l10n.iconInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert a stock illustration into the current slide (Track 15, P5).
  Future<void> _showStockMediaDialog(
      PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final result = await showDialog<StockMediaItem>(
      context: context,
      builder: (_) => const StockMediaDialog(),
    );
    if (!mounted || result == null) return;
    // Insert the SVG as a data-URI <img>
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final imgTag = '<img src="${result.dataUri}" alt="${result.name}">';
    final html = '${slide.htmlContent.trimRight()}\n$imgTag';
    presentationState.updateSlide(
      presentationState.currentSlideIndex,
      slide.copyWith(htmlContent: html),
    );
    if (mounted) {
      showAppSnackBar(context, context.l10n.mediaInserted,
          duration: const Duration(seconds: 1));
    }
  }

  /// Insert or edit a video on the current slide (Track 11, P4–P7).
  Future<void> _showVideoDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => VideoDialog(currentHtml: slide.htmlContent),
    );
    if (!mounted) return;
    if (result is VideoData) {
      presentationState.upsertVideo(result);
      if (mounted) {
        showAppSnackBar(context, context.l10n.videoInserted,
            duration: const Duration(seconds: 1));
      }
    } else if (result is String && result.startsWith('edit:')) {
      final index = int.tryParse(result.substring(5)) ?? -1;
      if (index < 0) return;
      final editResult = await showDialog<Object>(
        context: context,
        builder: (_) => VideoDialog(
          currentHtml: slide.htmlContent,
          editIndex: index,
        ),
      );
      if (!mounted) return;
      if (editResult is VideoData) {
        presentationState.upsertVideo(editResult, editIndex: index);
        if (mounted) {
          showAppSnackBar(context, context.l10n.videoUpdated,
              duration: const Duration(seconds: 1));
        }
      }
    }
  }

  /// Insert or edit a chart on the current slide (Track 08, P7–P8).
  Future<void> _showChartDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty) return;
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => ChartDialog(currentHtml: slide.htmlContent),
    );
    if (!mounted) return;
    if (result is ChartData) {
      presentationState.upsertChart(result);
      if (mounted) {
        showAppSnackBar(context, context.l10n.chartInserted,
            duration: const Duration(seconds: 1));
      }
    } else if (result is String && result.startsWith('edit:')) {
      final index = int.tryParse(result.substring(5)) ?? -1;
      if (index < 0) return;
      final editResult = await showDialog<Object>(
        context: context,
        builder: (_) => ChartDialog(
          currentHtml: slide.htmlContent,
          editIndex: index,
        ),
      );
      if (editResult is ChartData) {
        presentationState.upsertChart(editResult, editIndex: index);
        if (mounted) {
          showAppSnackBar(context, context.l10n.chartUpdated,
              duration: const Duration(seconds: 1));
        }
      }
    }
  }

  // ---- Template Gallery ----

  Future<void> _showTemplateGallery() async {
    final templateService = TemplateService();
    final templates = await templateService.loadTemplates();
    if (templates.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, context.l10n.noTemplates);
      }
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth * 0.85;
        return AlertDialog(
          title: Text(context.l10n.chooseTemplate),
          content: SizedBox(
            width: dialogWidth > 600 ? 600 : dialogWidth,
            height: 450,
            child: ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: template.accentColor,
                      child: Icon(template.icon, color: Colors.white, size: 20),
                    ),
                    title: Text(template.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(template.description,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        _editorState.applyTemplate(template, context);
                        Navigator.pop(context);
                      },
                      child: Text(context.l10n.useTemplate),
                    ),
                    onTap: () => _previewTemplate(template),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    );
  }

  void _previewTemplate(SlideTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.name),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.description,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(context.l10n.htmlPreview,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    template.htmlContent,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                      'Effect: ${EditorState.effectName(template.recommendedEffect)}'),
                  avatar: const Icon(Icons.animation, size: 16),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _editorState.applyTemplate(template, context);
            },
            child: Text(context.l10n.useThisTemplate),
          ),
        ],
      ),
    );
  }

  // ---- Clear All ----

  void _confirmClearAll() {
    final state = Provider.of<PresentationState>(context, listen: false);
    if (state.slides.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearAllSlides),
        content: Text(context.l10n.clearAllSlidesMessage(state.slides.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              state.clearSlides();
              showAppSnackBar(
                context,
                context.l10n.deletedAllSlides,
                duration: const Duration(seconds: 3),
                actionLabel: context.l10n.undoAction,
                onAction: () => state.undo(),
              );
              Navigator.pop(context);
            },
            child: Text(context.l10n.clearAllSlides),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentationState = Provider.of<PresentationState>(context);
    final theme = Theme.of(context);

    if (presentationState.isHydrating) {
      return const Center(child: CircularProgressIndicator());
    }
    if (presentationState.lastPersistenceError != null &&
        presentationState.slides.isEmpty) {
      return Center(
        child: SelectableText(
          'Không thể khôi phục dữ liệu: ${presentationState.lastPersistenceError}',
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _editorState,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
              _editorState.addOrUpdateSlide(context),
          const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
              _showExportDialog(),
          // Ctrl+S must SAVE (matches QAT tooltip "Save (Ctrl+S)") — it must
          // NOT open the export dialog.
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              () async {
            await presentationState.savePresentation();
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
              presentationState.undo(),
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
              presentationState.redo(),
          // Track 24, P7: Format Painter shortcuts (Ctrl+Shift+C / Ctrl+Shift+V)
          // and Eyedropper (Ctrl+Shift+I).
          const SingleActivator(LogicalKeyboardKey.keyC,
              control: true, shift: true): () => _editorState.captureFormat(),
          const SingleActivator(LogicalKeyboardKey.keyV,
              control: true,
              shift: true): () => _editorState.pasteFormatToSelection(),
          const SingleActivator(LogicalKeyboardKey.keyI,
              control: true, shift: true): () async {
            final color = EyedropperService.pickAtCursor();
            if (color != null) {
              await Clipboard.setData(ClipboardData(text: color));
            }
          },
        },
        // Keep the focusable node inside CallbackShortcuts so its key-event
        // handler is guaranteed to sit on the active focus path. This mirrors
        // the working shortcut structure used by the presentation screen.
        child: Focus(
          autofocus: true,
          child: _buildLayout(context, presentationState, theme),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, PresentationState presentationState,
      ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left panel: Slide thumbnails (resizable & collapsible)
          if (!_isSidebarCollapsed) ...[
            SizedBox(
              width: _sidebarWidth,
              child: SlideListPanel(
                onAddSlide: () => _editorState.startNewSlide(context),
                onClearAll: _confirmClearAll,
              ),
            ),
            // Draggable splitter handle
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _sidebarWidth =
                        (_sidebarWidth + details.delta.dx).clamp(110.0, 360.0);
                  });
                },
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Center panel: HTML editor + preview (flex: 1)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Top action bar (Templates, Export, Present, Clear)
                _buildTopBar(context, presentationState, theme),

                // Read Aloud bar (Track 62, FEAT 100)
                if (_showReadAloudBar) ReadAloudBar(state: presentationState),

                const SizedBox(height: 4),

                // Main editor area
                const Expanded(
                  child: HtmlEditorPanel(),
                ),
              ],
            ),
          ),

          if (_showSelectionPane) ...[
            const SizedBox(width: 4),
            // Selection Pane (Track 26, P2)
            SizedBox(
              width: 240,
              child: SelectionPane(
                selectedIds:
                    _editorState.selectedShapeIds.map((e) => 'sh_$e').toSet(),
                onSelectLayer: (elementId) => _editorState.selectShape(
                    elementId.startsWith('sh_')
                        ? elementId.substring(3)
                        : elementId),
              ),
            ),
          ],
          if (_showAnimationPane) ...[
            const SizedBox(width: 4),
            // Animation Pane (Track 30, P1)
            SizedBox(
              width: 260,
              child: AnimationPane(
                selectedShapeIds: _editorState.selectedShapeIds.toList(),
              ),
            ),
          ],
          if (_showCommentsPane) ...[
            const SizedBox(width: 4),
            // Comments Pane (Track 48, P2)
            SizedBox(
              width: 300,
              child: _buildCommentsPane(presentationState),
            ),
          ],
          if (_showDesignerPane) ...[
            const SizedBox(width: 4),
            // Designer Pane (Track 54, P3)
            SizedBox(
              width: 300,
              child: DesignerPanel(state: presentationState),
            ),
          ],
        ],
      ),
    );
  }

  /// Localized name of a slide layout (Track 05, P9).
  String _layoutName(BuildContext context, SlideLayoutType type) {
    final l = context.l10n;
    return switch (type) {
      SlideLayoutType.blank => l.layoutBlank,
      SlideLayoutType.titleSlide => l.layoutTitleSlide,
      SlideLayoutType.titleAndContent => l.layoutTitleAndContent,
      SlideLayoutType.sectionHeader => l.layoutSectionHeader,
      SlideLayoutType.twoContent => l.layoutTwoContent,
      SlideLayoutType.comparison => l.layoutComparison,
      SlideLayoutType.titleOnly => l.layoutTitleOnly,
      SlideLayoutType.contentAndCaption => l.layoutContentAndCaption,
      SlideLayoutType.pictureAndCaption => l.layoutPictureAndCaption,
    };
  }

  Widget _buildTopBar(BuildContext context, PresentationState presentationState,
      ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Scrollbar(
        controller: _toolbarScrollController,
        thumbVisibility: true,
        thickness: 3,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _toolbarScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Toggle sidebar
              IconButton(
                icon: Icon(
                  _isSidebarCollapsed
                      ? Icons.view_sidebar_outlined
                      : Icons.view_sidebar,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                tooltip: _isSidebarCollapsed
                    ? 'Mở thanh Slide'
                    : 'Thu gọn thanh Slide',
                onPressed: () =>
                    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              // Templates
              _actionButton(
                context,
                icon: Icons.palette_outlined,
                label: context.l10n.templates,
                onPressed: _showTemplateGallery,
              ),
              const SizedBox(width: 4),
              // Import (Track 66, M10: markdown/file/web)
              _actionButton(
                context,
                icon: Icons.file_upload_outlined,
                label: context.l10n.import,
                onPressed: () => _showImportDialog(presentationState),
              ),
              const SizedBox(width: 4),
              // Keep release-critical actions visible without horizontal scroll.
              _actionButton(
                context,
                icon: Icons.download,
                label: context.l10n.export,
                onPressed: _showExportDialog,
              ),
              const SizedBox(width: 4),
              _actionButton(
                context,
                icon: Icons.people_outline,
                label: context.l10n.collaboration,
                onPressed: _showCollaboration,
              ),
              const SizedBox(width: 4),
              _actionButton(
                context,
                icon: _showAdvancedTools ? Icons.expand_less : Icons.more_horiz,
                label: _showAdvancedTools
                    ? context.l10n.collapseTools
                    : context.l10n.moreTools,
                onPressed: () =>
                    setState(() => _showAdvancedTools = !_showAdvancedTools),
              ),
              const SizedBox(width: 8),
              if (_showAdvancedTools) ...[
                // Slide layout (Track 05, P8: picker writes back to Slide.layoutType)
                _actionButton(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: context.l10n.layout,
                  onPressed: () => LayoutPicker.showAsDialog(
                    context,
                    (type) {
                      presentationState.setSlideLayout(type);
                      showAppSnackBar(
                          context,
                          context.l10n
                              .layoutApplied(_layoutName(context, type)),
                          duration: const Duration(seconds: 1));
                    },
                    nameOf: (type) => _layoutName(context, type),
                  ),
                ),
                const SizedBox(width: 4),
                // Insert / edit chart (Track 08, P7–P8)
                _actionButton(
                  context,
                  icon: Icons.insert_chart_outlined,
                  label: context.l10n.insertChart,
                  onPressed: () => _showChartDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Insert / edit SmartArt (Track 10, P5–P7)
                _actionButton(
                  context,
                  icon: Icons.account_tree_outlined,
                  label: context.l10n.insertSmartArt,
                  onPressed: () => _showSmartArtDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Insert / edit 3D model (Track 14, P2/P6)
                _actionButton(
                  context,
                  icon: Icons.view_in_ar_outlined,
                  label: context.l10n.insertModel3d,
                  onPressed: () => _showModel3dDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Insert / edit video (Track 11, P4–P7)
                _actionButton(
                  context,
                  icon: Icons.movie_outlined,
                  label: context.l10n.insertVideo,
                  onPressed: () => _showVideoDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Insert icon (Track 15, P2)
                _actionButton(
                  context,
                  icon: Icons.emoji_symbols_outlined,
                  label: context.l10n.insertIcon,
                  onPressed: () => _showIconDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Insert stock media (Track 15, P5)
                _actionButton(
                  context,
                  icon: Icons.image_outlined,
                  label: context.l10n.insertStockMedia,
                  onPressed: () => _showStockMediaDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Record screen (Track 12, P2–P7)
                _actionButton(
                  context,
                  icon: Icons.videocam_outlined,
                  label: context.l10n.recordScreen,
                  onPressed: () => _showScreenCaptureDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Screenshot (Track 16, P1–P2)
                _actionButton(
                  context,
                  icon: Icons.camera_alt_outlined,
                  label: context.l10n.screenshot,
                  onPressed: () => _showScreenshotDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Photo album (Track 16, P3–P6)
                _actionButton(
                  context,
                  icon: Icons.photo_library_outlined,
                  label: context.l10n.photoAlbum,
                  onPressed: () => _showPhotoAlbumDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Free-form text box (Track 17, P2)
                _actionButton(
                  context,
                  icon: Icons.text_fields,
                  label: context.l10n.freeTextAdd,
                  onPressed: () => _showFreeTextDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Action button (Track 18, P1)
                _actionButton(
                  context,
                  icon: Icons.touch_app_outlined,
                  label: context.l10n.actionButton,
                  onPressed: () => _showActionButtonDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Equation (Track 18, P3)
                _actionButton(
                  context,
                  icon: Icons.functions_outlined,
                  label: context.l10n.equation,
                  onPressed: () => _showEquationDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Symbol (Track 18, P5)
                _actionButton(
                  context,
                  icon: Icons.abc_outlined,
                  label: context.l10n.symbol,
                  onPressed: () => _showSymbolDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // OLE object (Track 18, P6)
                _actionButton(
                  context,
                  icon: Icons.insert_drive_file_outlined,
                  label: context.l10n.ole,
                  onPressed: () => _showOleDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Slide zoom (Track 20, P5)
                _actionButton(
                  context,
                  icon: Icons.zoom_in_outlined,
                  label: context.l10n.zoom,
                  onPressed: () => _showZoomDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Cameo / live camera (Track 20, P8)
                _actionButton(
                  context,
                  icon: Icons.videocam_outlined,
                  label: context.l10n.cameo,
                  onPressed: () => _showCameoDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Shape (Track 21)
                _actionButton(
                  context,
                  icon: Icons.category_outlined,
                  label: context.l10n.shape,
                  onPressed: () => _showShapeDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Shape properties (Track 21, P7)
                _actionButton(
                  context,
                  icon: Icons.tune,
                  label: context.l10n.shapeProperties,
                  onPressed: () =>
                      _showShapePropertiesDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Merge shapes (Track 21, P4)
                _actionButton(
                  context,
                  icon: Icons.merge_type,
                  label: context.l10n.shapeMerge,
                  onPressed: () => _showShapeMergeDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Freeform scribble (Track 21, P4)
                _actionButton(
                  context,
                  icon: Icons.gesture,
                  label: context.l10n.shapeScribble,
                  onPressed: () =>
                      _editorState.setScribbleMode(!_editorState.scribbleMode),
                ),
                const SizedBox(width: 4),
                // Align & Guides (Track 27)
                _actionButton(
                  context,
                  icon: Icons.align_horizontal_left,
                  label: context.l10n.alignGuides,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => GuidesAlignDialog(
                      selectedShapeIds: _editorState.selectedShapeIds.toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Text layout tools (Track 28)
                _actionButton(
                  context,
                  icon: Icons.text_fields,
                  label: context.l10n.textLayout,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const TextLayoutDialog(),
                  ),
                ),
                const SizedBox(width: 4),
                // Transitions (Track 33)
                _actionButton(
                  context,
                  icon: Icons.auto_awesome_motion,
                  label: context.l10n.transitions,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const TransitionDialog(),
                  ),
                ),
                const SizedBox(width: 4),
                // Header & Footer (Track 19, P2)
                _actionButton(
                  context,
                  icon: Icons.text_snippet_outlined,
                  label: context.l10n.headerFooter,
                  onPressed: () => _showHeaderFooterDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Selection Pane (Track 26, P2)
                _actionButton(
                  context,
                  icon: Icons.layers_outlined,
                  label: context.l10n.selectionPane,
                  onPressed: () => _toggleAuxPane(_EditorAuxPane.selection),
                ),
                const SizedBox(width: 4),
                // Animation Pane (Track 30, P1)
                _actionButton(
                  context,
                  icon: Icons.animation,
                  label: context.l10n.animationPane,
                  onPressed: () => _toggleAuxPane(_EditorAuxPane.animation),
                ),
                const SizedBox(width: 4),
                // Comments (Track 48, P1–P7)
                _actionButton(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: context.l10n.comments,
                  onPressed: () => _toggleAuxPane(_EditorAuxPane.comments),
                ),
                const SizedBox(width: 4),
                // Profile (Track 49) + Cloud (Track 50)
                _actionButton(
                  context,
                  icon: Icons.account_circle_outlined,
                  label: context.l10n.profileTitle,
                  onPressed: _showProfileDialog,
                ),
                const SizedBox(width: 4),
                _actionButton(
                  context,
                  icon: Icons.cloud_outlined,
                  label: context.l10n.cloudTitle,
                  onPressed: () => _showCloudDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Reuse / Compare (Track 51, FEAT 85/86)
                _actionButton(
                  context,
                  icon: Icons.file_copy_outlined,
                  label: context.l10n.reuseTitle,
                  onPressed: () => _showReuseCompareDialog(presentationState),
                ),
                const SizedBox(width: 4),
                // Designer (Track 54, FEAT 87)
                _actionButton(
                  context,
                  icon: Icons.design_services_outlined,
                  label: context.l10n.designerTitle,
                  onPressed: () => _toggleAuxPane(_EditorAuxPane.designer),
                ),
                const SizedBox(width: 4),
                // Dictation (Track 56, FEAT 90)
                _actionButton(
                  context,
                  icon: _dictating ? Icons.mic : Icons.mic_none,
                  label: context.l10n.dictationMic,
                  iconColor: _dictating ? Colors.red : null,
                  onPressed: _toggleDictation,
                ),
                const SizedBox(width: 4),
                // Find & Replace (Track 57, FEAT 94)
                _actionButton(
                  context,
                  icon: Icons.find_in_page_outlined,
                  label: context.l10n.findReplace,
                  onPressed: () => _showFindReplace(presentationState),
                ),
                const SizedBox(width: 4),
                // Spellcheck (Track 57, FEAT 92)
                _actionButton(
                  context,
                  icon: Icons.spellcheck_outlined,
                  label: context.l10n.spellcheck,
                  onPressed: () => _showSpellcheck(presentationState),
                ),
                const SizedBox(width: 4),
                // Accessibility (Track 58, FEAT 95)
                _actionButton(
                  context,
                  icon: Icons.accessibility_new_outlined,
                  label: context.l10n.accessibilityTitle,
                  onPressed: () => _showAccessibility(presentationState),
                ),
                const SizedBox(width: 4),
                // Add-ins (Track 61, FEAT 98)
                _actionButton(
                  context,
                  icon: Icons.extension_outlined,
                  label: context.l10n.addinsTitle,
                  onPressed: () => _showAddins(presentationState),
                ),
                const SizedBox(width: 4),
                // Read Aloud (Track 62, FEAT 100)
                _actionButton(
                  context,
                  icon: Icons.record_voice_over_outlined,
                  label: context.l10n.readAloudTitle,
                  iconColor: _showReadAloudBar ? Colors.red : null,
                  onPressed: () =>
                      setState(() => _showReadAloudBar = !_showReadAloudBar),
                ),
                const SizedBox(width: 4),
                // Ribbon customize (Track 60, FEAT 97)
                _actionButton(
                  context,
                  icon: Icons.tune_outlined,
                  label: context.l10n.ribbonCustomize,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const RibbonCustomizeDialog(),
                  ),
                ),
                const SizedBox(width: 4),
                // Views (Track 60, FEAT 99)
                PopupMenuButton<String>(
                  tooltip: context.l10n.viewNormal,
                  icon: const Icon(Icons.grid_view_outlined, size: 16),
                  onSelected: (view) {
                    switch (view) {
                      case 'sorter':
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SlideSorterScreen(),
                        ));
                      case 'notes':
                        _showNotesDialog(presentationState);
                      case 'reading':
                        if (presentationState.slides.isNotEmpty) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PresentScreen(
                              state: presentationState,
                              startSlide: presentationState.currentSlideIndex,
                            ),
                          ));
                        }
                      default:
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'normal',
                      child: Text(context.l10n.viewNormal),
                    ),
                    PopupMenuItem(
                      value: 'sorter',
                      child: Text(context.l10n.viewSorter),
                    ),
                    PopupMenuItem(
                      value: 'notes',
                      child: Text(context.l10n.viewNotes),
                    ),
                    PopupMenuItem(
                      value: 'reading',
                      child: Text(context.l10n.viewReading),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 12),
              // Slide counter
              Text(
                context.l10n.slideCount(presentationState.slides.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              // Undo/Redo
              IconButton(
                icon: Icon(Icons.undo,
                    size: 16,
                    color: presentationState.canUndo
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outline.withValues(alpha: 0.3)),
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: presentationState.canUndo
                    ? () => presentationState.undo()
                    : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(Icons.redo,
                    size: 16,
                    color: presentationState.canRedo
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outline.withValues(alpha: 0.3)),
                tooltip: 'Redo (Ctrl+Y)',
                onPressed: presentationState.canRedo
                    ? () => presentationState.redo()
                    : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              // Clear all
              if (presentationState.slides.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep,
                      size: 16, color: Colors.red),
                  tooltip: context.l10n.clearAllSlides,
                  onPressed: _confirmClearAll,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: iconColor),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // ---- M7: comments (T48), profile (T49), cloud (T50) ----------------------

  Widget _buildCommentsPane(PresentationState presentationState) {
    if (presentationState.slides.isEmpty) return const SizedBox.shrink();
    final slide = presentationState.slides[presentationState.currentSlideIndex];
    return CommentsPanel(
      slide: slide.toMap(),
      onChanged: () {
        if (mounted) setState(() {});
      },
      authorName: _profile?.name ?? 'User',
      authorColor: _profile?.color ?? '#FF9800',
    );
  }

  /// Toggle dictation (Track 56, FEAT 90). Each recognized phrase is
  /// inserted at the cursor of the active HTML editor.
  Future<void> _toggleDictation() async {
    if (_dictating) {
      await _dictation.stop();
      if (mounted) setState(() => _dictating = false);
      return;
    }
    // Fall back to EN when the UI locale's recognizer is unavailable.
    final locale = context.l10n.localeName.contains('vi') ? 'vi' : 'en';
    var effective = locale;
    if (locale == 'vi' && !await _dictation.localeAvailable('vi')) {
      effective = 'en';
      if (mounted) {
        showAppSnackBar(
            context,
            'Vietnamese speech not found on this machine — using English.');
      }
    }
    _dictation.onPhrase = (phrase) {
      _insertDictatedText(phrase);
    };
    await _dictation.start(locale: effective);
    if (mounted) setState(() => _dictating = _dictation.listening);
  }

  /// Insert dictated text into the current slide's HTML content.
  void _insertDictatedText(String phrase) {
    final state = Provider.of<PresentationState>(context, listen: false);
    final i = state.currentSlideIndex;
    if (i < 0 || i >= state.slides.length) return;
    final slide = state.slides[i];
    final html = slide.htmlContent;
    final esc = phrase
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    state.updateSlide(i, slide.copyWith(htmlContent: '$html<p>$esc</p>'));
  }

  /// Notes view (Track 60, FEAT 99) — simple per-slide notes dialog.
  Future<void> _showNotesDialog(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty || !mounted) return;
    final i = presentationState.currentSlideIndex;
    final slide = presentationState.slides[i];
    final controller = TextEditingController(text: slide.notes);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notes — Slide ${i + 1}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Speaker notes…',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              presentationState.updateSlide(
                  i, slide.copyWith(notes: controller.text));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Import slides — advanced markdown / file / web (Track 66, M10).
  Future<void> _showImportDialog(PresentationState presentationState) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ImportDialog(
        onImportSlides: (slides) {
          if (slides.isEmpty) return;
          for (final s in slides) {
            presentationState.addSlide(s);
          }
        },
      ),
    );
  }

  /// Spellcheck (Track 57, FEAT 92).
  Future<void> _showSpellcheck(PresentationState presentationState) async {
    if (presentationState.slides.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SpellcheckDialog(state: presentationState),
    );
  }

  /// Find & Replace (Track 57, FEAT 94).
  Future<void> _showFindReplace(PresentationState presentationState) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => FindReplaceDialog(state: presentationState),
    );
  }

  /// Accessibility checker (Track 58, FEAT 95).
  Future<void> _showAccessibility(PresentationState presentationState) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AccessibilityPanel(state: presentationState),
    );
  }

  /// Add-in manager (Track 61, FEAT 98).
  Future<void> _showAddins(PresentationState presentationState) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AddinManagerDialog(state: presentationState),
    );
  }

  /// Reuse slides from another deck / compare & merge (Track 51, FEAT 85/86).
  Future<void> _showReuseCompareDialog(
      PresentationState presentationState) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ReuseCompareDialog(state: presentationState),
    );
  }

  Future<void> _showProfileDialog() async {
    final profile = await UserProfile.load();
    if (!mounted) return;
    final result = await showDialog<UserProfile>(
      context: context,
      builder: (_) => ProfileDialog(initial: profile),
    );
    if (result != null) {
      _profile = result;
      if (mounted) setState(() {});
    }
  }

  Future<void> _showCloudDialog(PresentationState presentationState) async {
    await UserProfile.load(); // warm the profile cache (author metadata)
    if (!mounted) return;
    final projectName =
        'ghita_deck_${DateTime.now().millisecondsSinceEpoch % 100000}';
    // Serialize the current deck to a .ghita bundle for upload.
    List<int> bytes;
    try {
      final tmp = await File(
              '${Directory.systemTemp.path}/ghita_cloud_${DateTime.now().millisecondsSinceEpoch}.ghita')
          .create(recursive: true);
      await tmp.writeAsString(
          jsonEncode({
            'slides': [for (final s in presentationState.slides) s.toMap()],
          }),
          flush: true);
      bytes = await tmp.readAsBytes();
      try {
        tmp.deleteSync();
      } catch (_) {}
    } catch (_) {
      bytes = utf8.encode(jsonEncode({
        'slides': [for (final s in presentationState.slides) s.toMap()],
      }));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CloudSyncDialog(
        projectName: projectName,
        deckBytes: bytes,
      ),
    );
  }

  UserProfile? _profile;
}
