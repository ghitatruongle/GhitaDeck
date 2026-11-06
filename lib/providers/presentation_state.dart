import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'deck_export_actions.dart';
import '../models/guide_settings.dart';
import '../models/object_animation.dart';
import '../models/chart_data.dart';
import '../models/free_shape.dart';
import '../models/icon_item.dart';
import '../models/media_item.dart';
import '../models/model3d_item.dart';
import '../models/smartart.dart';
import '../models/slide.dart';
import '../models/slide_layout.dart';
import '../models/drawn_shape.dart';
import '../models/layer.dart';
import '../models/custom_show.dart';
import '../services/setup_show_service.dart';
import '../services/shape_engine.dart';
import '../services/group_service.dart';
import '../services/layer_service.dart';
import '../services/chart_service.dart';
import '../services/icon_library_service.dart';
import '../services/smartart_service.dart';
import '../services/model3d_service.dart';
import '../services/video_embed_service.dart';
import '../services/action_button_service.dart';
import '../services/equation_service.dart';
import '../services/ole_service.dart';
import '../services/zoom_feature_service.dart';
import '../services/cameo_service.dart';
import '../services/html_export_service.dart';
import '../services/smart_draft_manager.dart';
import '../services/time_machine_history_service.dart';
import '../services/project_bundle_service.dart';
import '../services/header_footer_service.dart';
import 'config_service.dart';

// SlideEffect moved to models/slide.dart in 0.3.0; re-export so existing
// imports of presentation_state.dart keep working.
export '../models/slide.dart' show Slide, SlideEffect;

class PresentationState with ChangeNotifier, DeckExportActions {
  List<Slide> _slides = [];
  SlideEffect _slideEffect = SlideEffect.none;
  DeckMeta _deckMeta = const DeckMeta();
  String _aspectRatio = '16:9';
  String _presentationTitle = '';
  @override
  String? exportStatus;
  @override
  String? lastExportedPath;

  // Document lifecycle state. The editor can render a recovery/loading state
  // instead of guessing while the first asynchronous hydrate is in flight.
  bool _isHydrating = true;
  bool _isSaving = false;
  bool _disposed = false;
  bool _hasUnsavedChanges = false;
  String? _lastPersistenceError;
  int _documentRevision = 0;
  int _savedRevision = 0;
  bool _draftRecoveryPending = false;
  Map<String, dynamic>? _pendingDraft;
  late final Future<void> _readyFuture;

  // Current slide in the editor (session-only, used by "Present From Current").
  int _currentSlideIndex = 0;
  // Automatic slide advance ("Timing") — persisted across sessions.
  bool _autoAdvance = false;
  int _autoAdvanceSeconds = 5;

  // Track 36 — Set Up Show settings (session) + custom shows (persisted).
  SetupShowSettings _setupShow = const SetupShowSettings();
  List<CustomShow> _customShows = [];

  @override
  SetupShowSettings get setupShow => _setupShow;

  set setupShow(SetupShowSettings value) {
    _setupShow = value;
    notifyListeners();
  }

  List<CustomShow> get customShows => List.unmodifiable(_customShows);

  set customShows(List<CustomShow> shows) {
    _customShows = List.of(shows);
    notifyListeners();
    _persistCustomShows();
  }

  /// The active custom show (if one was picked for this session).
  CustomShow? _activeCustomShow;
  @override
  CustomShow? get activeCustomShow => _activeCustomShow;
  set activeCustomShow(CustomShow? show) {
    _activeCustomShow = show;
    notifyListeners();
  }

  Future<void> _persistCustomShows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'custom_shows', CustomShowService.toJsonList(_customShows));
    } catch (_) {}
  }

  Future<void> loadCustomShows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('custom_shows');
      if (raw != null && raw.isNotEmpty) {
        _customShows = CustomShowService.fromJsonList(raw);
        if (_disposed) return;
        notifyListeners();
      }
    } catch (_) {}
  }

  final ConfigService _configService = ConfigService();
  final SmartDraftManager _smartDraftManager = SmartDraftManager();
  final TimeMachineHistoryService _historyService = TimeMachineHistoryService();
  final ProjectBundleService _bundleService = ProjectBundleService();
  Timer? _saveDebounce;
  Timer? _exportStatusTimer;
  // Reuse the HTML export service to avoid rebuilding presentation logic and
  // to benefit from its image downscaling / in-memory optimizations.
  final HtmlExportService _htmlExportService = HtmlExportService();

  @override
  List<Slide> get slides => _slides;
  @override
  SlideEffect get slideEffect => _slideEffect;
  DeckMeta get deckMeta => _deckMeta;
  bool get isHydrating => _isHydrating;
  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  String? get lastPersistenceError => _lastPersistenceError;
  bool get draftRecoveryPending => _draftRecoveryPending;
  int get documentRevision => _documentRevision;
  int get savedRevision => _savedRevision;
  Future<void> get ready => _readyFuture;

  void setDeckMeta(DeckMeta meta) {
    _deckMeta = meta;
    _recordHistory('Sửa thông tin Deck');
    notifyListeners();
    _debouncedSave();
  }

  /// Track 27, P6: update the canvas editing aids (guides / snap / grid /
  /// ruler) stored as deck meta.
  void updateGuideSettings(GuideSettings settings) {
    _deckMeta = _deckMeta.copyWith(guides: settings);
    _recordHistory('Sửa hướng dẫn Canvas');
    notifyListeners();
    _debouncedSave();
  }

  // ---- Track 29/30/31: per-object animations ----------------------------

  /// Animations attached to the current slide (from visualElements).
  List<ObjectAnimation> get currentAnimations {
    final visual = currentSlide?.visualElements;
    final raw = visual?['animations'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map<String, dynamic>
            ? ObjectAnimation.fromMap(e)
            : (e is Map
                ? ObjectAnimation.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<ObjectAnimation>()
        .toList();
  }

  /// Replace the animation list of the current slide. Records undo.
  void updateAnimations(List<ObjectAnimation> animations) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    _recordHistory('Sửa Animations');
    final slide = _slides[index];
    final visual = Map<String, dynamic>.of(slide.visualElements);
    if (animations.isEmpty) {
      visual.remove('animations');
    } else {
      visual['animations'] = [for (final a in animations) a.toMap()];
    }
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Add or replace one animation. Records undo once.
  void upsertAnimation(ObjectAnimation animation) {
    final current = currentAnimations;
    final without = [
      for (final a in current)
        if (!(a.shapeId == animation.shapeId && a.effect == animation.effect))
          a,
    ];
    updateAnimations([...without, animation]);
  }

  String get aspectRatio => _aspectRatio;
  String get presentationTitle => _presentationTitle;
  bool get canUndo => _historyService.canUndo;
  bool get canRedo => _historyService.canRedo;
  int get currentSlideIndex => _currentSlideIndex;

  /// The slide currently being edited, or null when the deck is empty.
  Slide? get currentSlide {
    if (_currentSlideIndex < 0 || _currentSlideIndex >= _slides.length) {
      return null;
    }
    return _slides[_currentSlideIndex];
  }

  @override
  bool get autoAdvance => _autoAdvance;
  @override
  int get autoAdvanceSeconds => _autoAdvanceSeconds;

  /// Backward-compatible alias: returns effect name as string.
  String get currentTheme => _slideEffect.name;

  PresentationState() {
    _readyFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait<void>([
        loadPresentation(),
        _loadAutoAdvance(),
        loadCustomShows(),
      ]);
      _lastPersistenceError = null;
    } catch (error, stack) {
      _lastPersistenceError = error.toString();
      debugPrint('PresentationState initialization failed: $error');
      debugPrint('$stack');
    } finally {
      _isHydrating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> scanRecoverableDraft() async {
    try {
      if (!await _smartDraftManager.hasRecoverableDraft()) return;
      final draft = await _smartDraftManager.loadRecoverableDraft();
      if (_disposed || draft == null) return;
      final rawSlides = draft['slides'];
      if (rawSlides is! List || rawSlides.isEmpty) return;
      _pendingDraft = draft;
      _draftRecoveryPending = true;
    } catch (_) {}
  }

  Future<void> restoreDraft() async {
    final draft = _pendingDraft;
    if (draft == null) return;
    _pendingDraft = null;
    _draftRecoveryPending = false;
    final rawSlides = draft['slides'];
    if (rawSlides is List) {
      final slides = rawSlides
          .map((e) => Slide.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (slides.isNotEmpty) {
        _slides = slides;
        _keepCurrentSlideInRange();
        final meta = draft['metadata'];
        if (meta is Map) {
          final title = meta['title'];
          if (title is String && title.isNotEmpty) {
            _presentationTitle = title;
          }
          final ratio = meta['aspectRatio'];
          if (ratio is String && ratio.isNotEmpty) {
            _aspectRatio = ratio;
          }
        }
        _historyService.clear();
        _recordHistory('Recovered draft');
        _markDirty();
      }
    }
    if (_disposed) return;
    notifyListeners();
    try {
      await savePresentation();
      await _smartDraftManager.purgeDraft();
    } catch (_) {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> discardDraft() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _pendingDraft = null;
    _draftRecoveryPending = false;
    await _smartDraftManager.purgeDraft();
  }

  Future<void> purgeDraftSandbox() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _smartDraftManager.purgeDraft();
  }

  // ---- Auto advance ("Timing") ----

  Future<void> _loadAutoAdvance() async {
    final data = await _configService.loadAutoAdvance();
    if (_disposed) return;
    _autoAdvance = data.enabled;
    _autoAdvanceSeconds = data.seconds;
    notifyListeners();
  }

  void _persistAutoAdvance() {
    unawaited(
        _configService.saveAutoAdvance(_autoAdvance, _autoAdvanceSeconds));
  }

  /// Track the slide currently selected in the editor (used by the ribbon's
  /// "From Current" presenter). Not persisted. Also notifies listeners so
  /// editors/panels (find&replace, accessibility) can jump to the slide.
  void setCurrentSlide(int index) {
    if (index < 0 || index >= _slides.length) return;
    if (_currentSlideIndex == index) return;
    _currentSlideIndex = index;
    notifyListeners();
  }

  /// Alias used by search dialogs (Track 57, FEAT 94).
  void selectSlide(int index) => setCurrentSlide(index);

  /// Keep [currentSlideIndex] valid when the slide list shrinks (undo/redo,
  /// delete, load). A stale index would crash "Present From Current" /
  /// Presenter View flows.
  void _keepCurrentSlideInRange() {
    if (_slides.isEmpty) {
      _currentSlideIndex = 0;
    } else if (_currentSlideIndex >= _slides.length) {
      _currentSlideIndex = _slides.length - 1;
    }
  }

  void setAutoAdvance(bool enabled) {
    _autoAdvance = enabled;
    notifyListeners();
    _persistAutoAdvance();
  }

  /// Set the per-slide auto-advance duration. Setting a duration implies the
  /// author wants automatic pacing, so it also enables auto-advance.
  void setAutoAdvanceSeconds(int seconds) {
    _autoAdvanceSeconds = seconds.clamp(1, 60);
    _autoAdvance = true;
    notifyListeners();
    _persistAutoAdvance();
  }

  // ---- History Undo/Redo ----

  void undo() {
    final previous = _historyService.undo();
    if (previous != null) {
      _slides = previous.map((s) => s.copyWith()).toList();
      _keepCurrentSlideInRange();
      _markDirty();
      notifyListeners();
      savePresentation('Undo');
    }
  }

  void redo() {
    final next = _historyService.redo();
    if (next != null) {
      _slides = next.map((s) => s.copyWith()).toList();
      _keepCurrentSlideInRange();
      _markDirty();
      notifyListeners();
      savePresentation('Redo');
    }
  }

  void _recordHistory(String action) {
    _historyService.recordSnapshot(action, _slides);
  }

  void _markDirty() {
    _documentRevision++;
    _hasUnsavedChanges = true;
    _lastPersistenceError = null;
  }

  /// Debounced save to avoid excessive disk I/O during rapid edits (drag-reorder, typing).
  void _debouncedSave() {
    _markDirty();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      _saveDebounce = null;
      savePresentation();
      unawaited(_smartDraftManager.saveDraft(_slides,
          metadata: {'title': _presentationTitle, 'aspectRatio': _aspectRatio}));
    });
  }

  /// Auto-reset exportStatus after 5 seconds so UI doesn't show stale state.
  void _resetExportStatus() {
    _exportStatusTimer?.cancel();
    _exportStatusTimer = Timer(const Duration(seconds: 5), () {
      if (exportStatus != null && exportStatus != 'exporting') {
        exportStatus = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    final hadPendingSave = _saveDebounce?.isActive ?? false;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (hadPendingSave) {
      unawaited(savePresentation().catchError((Object _) {}));
    }
    _disposed = true;
    _exportStatusTimer?.cancel();
    super.dispose();
  }

  // ---- Project Bundle (.ghita) ----

  Future<bool> saveProjectToFile(String targetPath) async {
    // Track 13, P8: narration audio rides inside the bundle under media/ —
    // every slide's audio file is collected (deduped by name) and the slide
    // maps are rewritten to bundle-relative paths by the service.
    final mediaFiles = <MapEntry<String, Uint8List>>[];
    final nameByDigest = <String, String>{};
    final mediaPathNames = <String, String>{};
    for (final slide in _slides) {
      final path = slide.audioPath;
      if (path.isEmpty || path.startsWith('media/')) continue;
      try {
        final bytes = File(path).readAsBytesSync();
        final digest = crypto.sha256.convert(bytes).toString();
        var name = nameByDigest[digest];
        if (name == null) {
          final basename = p.basename(path);
          final extension = p.extension(basename);
          final stem = p.basenameWithoutExtension(basename);
          name = '$stem-${digest.substring(0, 12)}$extension';
          nameByDigest[digest] = name;
          mediaFiles.add(MapEntry(name, bytes));
        }
        mediaPathNames[path] = name;
      } catch (_) {}
    }
    final success = await _bundleService.saveProjectBundle(
      targetPath: targetPath,
      slides: _slides,
      title: _presentationTitle,
      aspectRatio: _aspectRatio,
      mediaFiles: mediaFiles,
      mediaPathNames: mediaPathNames,
      useEngineZip: true,
    );
    if (success) {
      await purgeDraftSandbox();
    }
    return success;
  }

  Future<bool> loadProjectFromFile(String sourcePath) async {
    final data = await _bundleService.loadProjectBundle(sourcePath);
    if (data != null) {
      final rawSlides = data['slides'] as List<dynamic>?;
      if (rawSlides == null) return false;
      _slides = rawSlides.map((e) => e as Slide).toList();
      _keepCurrentSlideInRange();
      final manifest = data['manifest'] as Map<String, dynamic>?;
      if (manifest != null) {
        _presentationTitle =
            (manifest['title'] ?? '').toString();
        _aspectRatio = (manifest['aspectRatio'] ?? '16:9').toString();
      }
      _historyService.clear();
      _recordHistory('Loaded Project');
      notifyListeners();
      await savePresentation();
      return true;
    }
    return false;
  }

  // ---- Slide CRUD ----

  void addSlide(Slide slide) {
    _slides.add(slide);
    _recordHistory('Thêm Slide mới');
    notifyListeners();
    _debouncedSave();
  }

  void removeSlide(int index) {
    if (index >= 0 && index < _slides.length) {
      _slides.removeAt(index);
      _keepCurrentSlideInRange();
      // Record AFTER the mutation so the snapshot is the post-state
      // (matches addSlide semantics — keeps redo correct too).
      _recordHistory('Xóa Slide');
      notifyListeners();
      _debouncedSave();
    }
  }

  /// Insert a slide at an explicit [index] (used by delete-undo to restore the
  /// original position rather than appending at the end).
  void insertSlide(int index, Slide slide) {
    final clamped = index.clamp(0, _slides.length);
    _slides.insert(clamped, slide);
    _recordHistory('Chèn Slide');
    notifyListeners();
    _debouncedSave();
  }

  /// Update a slide at the given index with new data.
  void updateSlide(int index, Slide updatedSlide) {
    if (index >= 0 && index < _slides.length) {
      _slides[index] = updatedSlide;
      _recordHistory('Cập nhật Slide');
      notifyListeners();
      _debouncedSave();
    }
  }

  /// Track 05, P8 (two-way sync): the layout the user picks in the editor is
  /// written back into [Slide.layoutType], so exports bind that slide to the
  /// matching `<p:sldLayout>` part and re-imports keep the choice.
  void setSlideLayout(SlideLayoutType type) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    updateSlide(index, _slides[index].copyWith(layoutType: type.name));
  }

  /// Track 10, P7: insert a SmartArt diagram into the current slide, or
  /// replace the [editIndex]-th one — the `<div data-smartart>` block is
  /// what every export format renders.
  void upsertSmartArt(SmartArtGraph graph, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < SmartArtService.diagramsIn(html).length) {
      html = SmartArtService.replaceDiagramAt(html, editIndex, graph);
    } else {
      html = '${html.trimRight()}\n${SmartArtService.smartartMarkup(graph)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 08, P7–P8: insert a new chart into the current slide, or replace
  /// the [editIndex]-th existing chart — the `<div data-chart>` block is
  /// what every export format renders.
  void upsertChart(ChartData chart, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null && editIndex < ChartService.chartsIn(html).length) {
      html = ChartService.replaceChartAt(html, editIndex, chart);
    } else {
      html = '${html.trimRight()}\n${ChartService.chartMarkup(chart)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 11, P6–P7: insert a video into the current slide, or replace the
  /// [editIndex]-th existing one — the `<video data-video>` tag is what
  /// every export format renders.
  void upsertVideo(VideoData video, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < VideoEmbedService.videosIn(html).length) {
      html = VideoEmbedService.replaceVideoAt(html, editIndex, video);
    } else {
      html = '${html.trimRight()}\n${VideoEmbedService.videoMarkup(video)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 14, P2: insert a 3D model into the current slide, or replace the
  /// [editIndex]-th existing one — the `<div data-model3d>` block is what
  /// every export format renders.
  void upsertModel3d(Model3DData model, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null && editIndex < Model3DService.modelsIn(html).length) {
      html = Model3DService.replaceModel3dAt(html, editIndex, model);
    } else {
      html = '${html.trimRight()}\n${Model3DService.model3dMarkup(model)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 15, P2: insert an icon into the current slide, or replace the
  /// [editIndex]-th existing one — the `<span data-icon='...'>` block is
  /// what every export format renders.
  void upsertIcon(IconItem icon, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < IconLibraryService.iconsIn(html).length) {
      html = IconLibraryService.replaceIconAt(html, editIndex, icon);
    } else {
      html = '${html.trimRight()}\n${IconLibraryService.iconMarkup(icon)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 18, P1–P2: insert an action button into the current slide, or
  /// replace the [editIndex]-th one — the `<div data-action>` block is what
  /// every export format renders (PPTX p:sp with slideJump/URL action).
  void upsertActionButton(ActionButton button, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < ActionButtonService.actionsIn(html).length) {
      html = ActionButtonService.replaceActionAt(html, editIndex, button);
    } else {
      html = '${html.trimRight()}\n${ActionButtonService.actionMarkup(button)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 18, P3–P4: insert an equation into the current slide.
  void upsertEquation(EquationData equation, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < EquationService.equationsIn(html).length) {
      html = EquationService.replaceEquationAt(html, editIndex, equation);
    } else {
      html = '${html.trimRight()}\n${EquationService.equationMarkup(equation)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 20, P5: insert a slide zoom into the current slide.
  void upsertZoom(ZoomItem zoom, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < ZoomFeatureService.zoomsIn(html).length) {
      html = ZoomFeatureService.replaceZoomAt(html, editIndex, zoom);
    } else {
      html = '${html.trimRight()}\n${ZoomFeatureService.zoomMarkup(zoom)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 20, P6: insert a Section/Summary Zoom grid into the current slide.
  void upsertSectionZoom(SectionZoomData zoom, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null &&
        editIndex < SectionZoomService.sectionZoomCount(html)) {
      html = SectionZoomService.replaceSectionZoomAt(html, editIndex, zoom);
    } else {
      html =
          '${html.trimRight()}\n${SectionZoomService.sectionZoomMarkup(zoom)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 20, P7: insert a cameo (camera) into the current slide.
  void upsertCameo(CameoData cameo, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null && editIndex < CameoService.cameosIn(html).length) {
      html = CameoService.replaceCameoAt(html, editIndex, cameo);
    } else {
      html = '${html.trimRight()}\n${CameoService.cameoMarkup(cameo)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 18, P6: insert an OLE object (embedded file) into the current
  /// slide, or replace the [editIndex]-th one — the `<div data-ole>` block.
  void upsertOle(OleData ole, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    var html = slide.htmlContent;
    if (editIndex != null && editIndex < OleService.olesIn(html).length) {
      html = OleService.replaceOleAt(html, editIndex, ole);
    } else {
      html = '${html.trimRight()}\n${OleService.oleMarkup(ole)}';
    }
    updateSlide(index, slide.copyWith(htmlContent: html));
  }

  /// Track 17, P3/P8: replace the free-form text elements of the current slide.
  /// The elements live in `Slide.visualElements['freeTexts']`; the export
  /// engines read them (PPTX p:sp with xfrm, HTML absolute divs, PDF).
  ///
  /// [record] snapshots the pre-state into the time-machine history so a
  /// discrete edit (add/edit/delete via dialog) is undoable; continuous
  /// drag/resize streams pass `record: false` to avoid flooding history.
  void updateFreeTexts(List<FreeTextShape> elements, {bool record = true}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    if (record) _recordHistory('Sửa TextBox');
    final slide = _slides[index];
    final visual = Map<String, dynamic>.of(slide.visualElements);
    if (elements.isEmpty) {
      visual.remove('freeTexts');
    } else {
      visual['freeTexts'] = elements.map((e) => e.toMap()).toList();
    }
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Track 21, P8: replace the drawn shapes of the current slide
  /// (`Slide.visualElements['shapes']`). Same history semantics as
  /// [updateFreeTexts]: discrete operations record, drag streams don't.
  void updateShapes(List<DrawnShape> shapes, {bool record = true}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    if (record) _recordHistory('Sửa Shape');
    final slide = _slides[index];
    final visual = Map<String, dynamic>.of(slide.visualElements);
    if (shapes.isEmpty) {
      visual.remove('shapes');
    } else {
      visual['shapes'] = shapes.map((e) => e.toMap()).toList();
    }
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Track 21: insert or replace a drawn shape in the current slide.
  /// Shapes are stored in `Slide.visualElements['shapes']` as a
  /// List<Map<String, dynamic>>. Records history so the insert is undoable.
  void upsertShape(DrawnShape shape, {int? editIndex}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    _recordHistory('Chèn Shape');
    final slide = _slides[index];
    final visual = Map<String, dynamic>.of(slide.visualElements);
    final rawList = visual['shapes'];
    final list = rawList is List
        ? rawList
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList()
        : <Map<String, dynamic>>[];
    if (editIndex != null && editIndex >= 0 && editIndex < list.length) {
      list[editIndex] = shape.toMap();
    } else {
      list.add(shape.toMap());
    }
    visual['shapes'] = list;
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Track 21, P4: merge two (or more) selected shapes into one with a real
  /// boolean operation (union/combine/intersect/subtract). The sources are
  /// removed from the list and replaced by the merged shape; records undo.
  /// Returns the merged shape, or null when fewer than two shapes exist.
  DrawnShape? mergeShapes(List<String> ids, String op) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return null;
    final slide = _slides[index];
    final raw = slide.visualElements['shapes'];
    if (raw is! List || raw.length < 2) return null;
    final shapes = raw
        .map((e) => e is Map<String, dynamic>
            ? DrawnShape.fromMap(e)
            : (e is Map
                ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<DrawnShape>()
        .toList();
    // Choose the shapes to merge: the explicitly selected ids when they
    // exist and are distinct, otherwise the two most recently added.
    final targets = ids.where((id) => shapes.any((s) => s.id == id)).toSet();
    final a = targets.length >= 2
        ? shapes.firstWhere((s) => s.id == targets.first)
        : shapes[shapes.length - 2];
    final b = targets.length >= 2
        ? shapes.firstWhere((s) => s.id == targets.last)
        : shapes[shapes.length - 1];
    if (a.id == b.id) return null;

    final DrawnShape merged = switch (op) {
      'union' => ShapeEngine.mergeUnion(a, b),
      'combine' => ShapeEngine.mergeCombine(a, b),
      'intersect' => ShapeEngine.mergeIntersect(a, b),
      _ => ShapeEngine.mergeSubtract(a, b),
    };
    if (merged.mergeOp.endsWith('_noop')) {
      return null;
    }
    _recordHistory('Merge Shapes');
    final keep = shapes.where((s) => s.id != a.id && s.id != b.id).toList()
      ..add(merged);
    final visual = Map<String, dynamic>.of(slide.visualElements);
    visual['shapes'] = keep.map((e) => e.toMap()).toList();
    updateSlide(index, slide.copyWith(visualElements: visual));
    return merged;
  }

  // ---- Track 26: layers & groups ---------------------------------------

  /// Persist the Selection Pane layer state (visible/locked/name/z-order)
  /// for the current slide. Records undo.
  void updateLayerState(List<dynamic> layerMaps) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    _recordHistory('Sửa Layers');
    final slide = _slides[index];
    final visual = Map<String, dynamic>.of(slide.visualElements);
    visual['layers'] = layerMaps;
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Track 26, P2/P3: toggle visibility of [layerIds] on the current slide.
  /// Hidden layers are excluded from exports by the renderers.
  void setLayersVisible(List<String> layerIds, bool visible) {
    final layers = _currentLayers();
    if (layers.isEmpty) return;
    final updated = [
      for (final l in layers)
        if (layerIds.contains(l.id)) l.copyWith(visible: visible) else l,
    ];
    updateLayerState(LayerService.stateToMap(updated));
  }

  /// Track 26, P2: lock/unlock [layerIds] so they cannot be selected or
  /// moved on the canvas.
  void setLayersLocked(List<String> layerIds, bool locked) {
    final layers = _currentLayers();
    if (layers.isEmpty) return;
    final updated = [
      for (final l in layers)
        if (layerIds.contains(l.id)) l.copyWith(locked: locked) else l,
    ];
    updateLayerState(LayerService.stateToMap(updated));
  }

  /// Track 26, P2: rename a layer in the Selection Pane.
  void renameLayer(String layerId, String name) {
    final layers = _currentLayers();
    if (layers.isEmpty) return;
    final updated = [
      for (final l in layers)
        if (l.id == layerId) l.copyWith(name: name) else l,
    ];
    updateLayerState(LayerService.stateToMap(updated));
  }

  /// Track 26, P3: move a layer from [from] to [to] (front/back order).
  /// Only the layer *presentation state* is reordered; the underlying shape
  /// z-order is re-derived from the new order on the next canvas rebuild.
  void reorderLayer(int from, int to) {
    final layers = _currentLayers();
    if (layers.isEmpty) return;
    final reordered = LayerService.reorder(layers, from, to);
    updateLayerState(LayerService.stateToMap(reordered));
  }

  List<SlideLayer> _currentLayers() {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return const [];
    return LayerService.buildLayers(_slides[index]);
  }

  /// Track 26, P4: group [memberIds] into one group. Members keep their own
  /// geometry; the group box is the union bbox. Records undo.
  ShapeGroup? groupShapes(List<String> memberIds) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return null;
    final slide = _slides[index];
    final raw = slide.visualElements['shapes'];
    if (raw is! List) return null;
    final shapes = raw
        .map((e) => e is Map<String, dynamic>
            ? DrawnShape.fromMap(e)
            : (e is Map
                ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<DrawnShape>()
        .toList();
    if (memberIds.length < 2) return null;
    if (memberIds.where((id) => shapes.any((s) => s.id == id)).length < 2) {
      return null;
    }
    final group = GroupService.createGroup(shapes, memberIds);
    _recordHistory('Group Shapes');
    final visual = Map<String, dynamic>.of(slide.visualElements);
    final rawGroups = visual['groups'];
    final groups = rawGroups is List
        ? List<Map<String, dynamic>>.from(rawGroups.map((e) =>
            e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
    groups.add(group.toMap());
    visual['groups'] = groups;
    updateSlide(index, slide.copyWith(visualElements: visual));
    return group;
  }

  /// Track 26, P4: ungroup — drop the group and keep its members as-is.
  void ungroupShapes(String groupId) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    _recordHistory('Ungroup Shapes');
    final slide = _slides[index];
    final visual = Map<String, dynamic>.of(slide.visualElements);
    final rawGroups = visual['groups'];
    if (rawGroups is! List) return;
    final groups = rawGroups.where((e) {
      final m = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      return m == null || m['id'] != groupId;
    }).toList();
    if (groups.isEmpty) {
      visual.remove('groups');
    } else {
      visual['groups'] = groups;
    }
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Track 26, P4: move/scale a whole group through its members.
  void transformGroup(String groupId,
      {double dx = 0, double dy = 0, double scale = 1}) {
    final index = _currentSlideIndex;
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    final rawShapes = slide.visualElements['shapes'];
    final rawGroups = slide.visualElements['groups'];
    if (rawShapes is! List || rawGroups is! List) return;
    ShapeGroup? group;
    for (final e in rawGroups) {
      final m = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      if (m == null) continue;
      final g = ShapeGroup.fromMap(m);
      if (g.id == groupId) group = g;
    }
    if (group == null) return;
    final shapes = rawShapes
        .map((e) => e is Map<String, dynamic>
            ? DrawnShape.fromMap(e)
            : (e is Map
                ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                : null))
        .whereType<DrawnShape>()
        .toList();
    var updated = shapes;
    if (scale != 1) {
      updated = GroupService.scaleGroup(updated, group, scale);
    }
    if (dx != 0 || dy != 0) {
      updated = GroupService.moveGroup(updated, group, dx, dy);
    }
    final visual = Map<String, dynamic>.of(slide.visualElements);
    visual['shapes'] = updated.map((e) => e.toMap()).toList();
    // Refresh the group box (bbox recomputed from moved members).
    final newGroup = group.copyWith(
      x: group.x + dx,
      y: group.y + dy,
      w: group.w * (scale != 1 ? scale : 1),
      h: group.h * (scale != 1 ? scale : 1),
    );
    visual['groups'] = rawGroups.map((e) {
      final m = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      return m != null && m['id'] == groupId ? newGroup.toMap() : e;
    }).toList();
    updateSlide(index, slide.copyWith(visualElements: visual));
  }

  /// Duplicate a slide at the given index.
  void duplicateSlide(int index) {
    if (index >= 0 && index < _slides.length) {
      final original = _slides[index];
      final duplicate = original.copyWith(
        title: '${original.title} (Copy)',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _slides.insert(index + 1, duplicate);
      _recordHistory('Nhân bản Slide');
      notifyListeners();
      _debouncedSave();
    }
  }

  /// Move a slide from [oldIndex] to [newIndex].
  void moveSlide(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _slides.length) return;
    if (newIndex < 0 || newIndex >= _slides.length) return;
    if (oldIndex == newIndex) return;

    final slide = _slides.removeAt(oldIndex);
    _slides.insert(newIndex, slide);
    _recordHistory('Di chuyển Slide');
    notifyListeners();
    _debouncedSave();
  }

  void clearSlides() {
    if (_slides.isEmpty) return;
    _slides.clear();
    _keepCurrentSlideInRange();
    // Record AFTER the mutation (post-state snapshot) so undo restores the
    // cleared slides and redo re-clears them.
    _recordHistory('Xóa tất cả Slide');
    notifyListeners();
    _debouncedSave();
  }

  /// Replaces the document with an authenticated collaboration snapshot.
  /// The operation is recorded as one history step and persisted locally so a
  /// received update behaves exactly like a normal editor change.
  void replaceSlidesFromCollaboration(List<Slide> slides) {
    _recordHistory('Before Collaboration Sync');
    _slides = slides.map((slide) => slide.copyWith()).toList(growable: true);
    _keepCurrentSlideInRange();
    _recordHistory('Collaboration Sync');
    notifyListeners();
    _debouncedSave();
  }

  void setEffect(SlideEffect effect) {
    _slideEffect = effect;
    _recordHistory('Đổi hiệu ứng Deck');
    _markDirty();
    notifyListeners();
    savePresentation();
  }

  /// Set (or clear with null) the per-slide transition override.
  void setSlideEffectOverride(int index, SlideEffect? effect) {
    if (index >= 0 && index < _slides.length) {
      _slides[index] =
          _slides[index].copyWith(effect: effect, clearEffect: effect == null);
      _recordHistory('Đổi hiệu ứng Slide');
      _markDirty();
      notifyListeners();
      savePresentation();
    }
  }

  /// Track 34, P5: enable/disable morph-from-previous for a slide.
  void setSlideMorph(int index, bool enabled) {
    if (index < 0 || index >= _slides.length) return;
    _slides[index] = _slides[index].copyWith(morphFromPrevious: enabled);
    _recordHistory('Đổi Morph Slide');
    _markDirty();
    notifyListeners();
    savePresentation();
  }

  /// Track 33, P4: per-slide transition duration (ms) + optional sound name
  /// + per-slide auto-advance (ms).
  void setSlideTransitionSettings(
    int index, {
    int? durationMs,
    String? sound,
    int? autoAdvanceMs,
  }) {
    if (index < 0 || index >= _slides.length) return;
    _slides[index] = _slides[index].copyWith(
      transitionDurationMs: durationMs,
      transitionSound: sound,
      autoAdvanceMs: autoAdvanceMs,
    );
    _recordHistory('Sửa thiết lập chuyển Slide');
    _markDirty();
    notifyListeners();
    savePresentation();
  }

  // ---- Persistence ----

  Future<void> savePresentation([String? title]) async {
    if (_disposed) return;
    final revisionBeingSaved = _documentRevision;
    _isSaving = true;
    notifyListeners();
    try {
      await _configService.saveSlides(
          slideMaps(), _slideEffect.name, _deckMeta.toJson());
      if (_disposed) return;
      _savedRevision = revisionBeingSaved;
      if (_documentRevision == revisionBeingSaved) {
        _hasUnsavedChanges = false;
      }
      _lastPersistenceError = null;
    } catch (error, stack) {
      _lastPersistenceError = error.toString();
      debugPrint('PresentationState save failed: $error');
      debugPrint('$stack');
      unawaited(_smartDraftManager.saveDraft(_slides,
          metadata: {'title': _presentationTitle, 'aspectRatio': _aspectRatio}));
      rethrow;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> loadPresentation([String? title]) async {
    final data = await _configService.loadSlides();
    if (_disposed) return;
    _slides = (data['slides'] as List)
        .map((e) => Slide.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    _keepCurrentSlideInRange();
    try {
      _slideEffect = SlideEffect.values.byName(data['slide_effect'] ?? 'none');
    } catch (_) {
      _slideEffect = SlideEffect.none;
    }
    _deckMeta = data['deckMeta'] is String
        ? DeckMeta.fromJson(data['deckMeta'] as String)
        : const DeckMeta();
    _historyService.clear();
    _recordHistory('Trạng thái ban đầu');
    _savedRevision = _documentRevision;
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  @override
  List<Map<String, dynamic>> slideMaps() =>
      _slides.map((s) => s.toMap()).toList();

  @override
  HtmlExportService get htmlExportService => _htmlExportService;

  @override
  void resetExportStatus() => _resetExportStatus();
}
