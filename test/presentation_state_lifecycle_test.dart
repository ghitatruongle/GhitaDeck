// T01 (v2.0.1-beta.2) — PresentationState lifecycle tests.
//
// Covers the document lifecycle contract the editor relies on:
//   P2  hydrate/readiness — UI sees a safe empty deck until `ready` completes
//   P3  dirty revision + saving state transitions
//   P4  persistence error paths (spill save failure, corrupt/missing data)
//   P5  slide mutation history consistency (undo/redo, index clamping)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/chart_data.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/models/free_shape.dart';
import 'package:ghita_ppt_converter/models/guide_settings.dart';
import 'package:ghita_ppt_converter/models/icon_item.dart';
import 'package:ghita_ppt_converter/models/media_item.dart';
import 'package:ghita_ppt_converter/models/model3d_item.dart';
import 'package:ghita_ppt_converter/models/slide_layout.dart';
import 'package:ghita_ppt_converter/models/smartart.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/services/action_button_service.dart';
import 'package:ghita_ppt_converter/services/cameo_service.dart';
import 'package:ghita_ppt_converter/services/chart_service.dart';
import 'package:ghita_ppt_converter/services/equation_service.dart';
import 'package:ghita_ppt_converter/services/header_footer_service.dart';
import 'package:ghita_ppt_converter/services/layer_service.dart';
import 'package:ghita_ppt_converter/services/ole_service.dart';
import 'package:ghita_ppt_converter/services/smartart_service.dart';
import 'package:ghita_ppt_converter/services/zoom_feature_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ghita_lifecycle_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Slide slide(String title) => Slide(
        title: title,
        htmlContent: '<h1>$title</h1>\n<p>body</p>',
      );

  /// The debounced save fires after 400 ms; waiting past it makes the
  /// persistence assertions deterministic without fake clocks.
  Future<void> settleDebounce() =>
      Future<void>.delayed(const Duration(milliseconds: 700));

  /// undo()/redo() kick off a fire-and-forget save whose finally block still
  /// notifies listeners; let it finish before teardown disposes the state.
  Future<void> flushSaves() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  group('P2 — hydrate & readiness', () {
    test('fresh state is hydrating and exposes a safe empty deck until ready',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);

      expect(state.isHydrating, isTrue);
      expect(state.slides, isEmpty);
      expect(state.currentSlide, isNull);

      await state.ready;

      expect(state.isHydrating, isFalse);
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.lastPersistenceError, isNull);
      expect(state.documentRevision, state.savedRevision);
    });

    test('hydrate restores persisted slides, effect and auto-advance',
        () async {
      SharedPreferences.setMockInitialValues({
        'presentation_slides_config': jsonEncode([
          {'title': 'First', 'htmlContent': '<h1>First</h1>'},
          {'title': 'Second', 'htmlContent': '<h1>Second</h1>'},
        ]),
        'presentation_slide_effect': 'fade',
        'presentation_auto_advance': true,
        'presentation_auto_advance_seconds': 15,
      });

      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      expect(state.slides.map((s) => s.title), ['First', 'Second']);
      expect(state.slideEffect.name, 'fade');
      expect(state.autoAdvance, isTrue);
      expect(state.autoAdvanceSeconds, 15);
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.lastPersistenceError, isNull);
    });

    test('auto-advance settings persist across instances', () async {
      final first = PresentationState();
      addTearDown(first.dispose);
      await first.ready;
      first.setAutoAdvance(true);
      first.setAutoAdvanceSeconds(15);
      // setAutoAdvance persists via an unawaited future; give it a beat.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final second = PresentationState();
      addTearDown(second.dispose);
      await second.ready;

      expect(second.autoAdvance, isTrue);
      expect(second.autoAdvanceSeconds, 15);
    });

    test('setAutoAdvanceSeconds clamps to 1..60 and implies enabled',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      state.setAutoAdvanceSeconds(500);
      expect(state.autoAdvanceSeconds, 60);
      expect(state.autoAdvance, isTrue);

      state.setAutoAdvance(false);
      expect(state.autoAdvance, isFalse);

      state.setAutoAdvanceSeconds(0);
      expect(state.autoAdvanceSeconds, 1);
      expect(state.autoAdvance, isTrue);
    });

    test('missing spill pointer file degrades gracefully to an empty deck',
        () async {
      SharedPreferences.setMockInitialValues({
        'presentation_slides_file_pointer':
            '${tempDir.path}${Platform.pathSeparator}missing_deck.json',
      });

      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      expect(state.slides, isEmpty);
      expect(state.isHydrating, isFalse);
      expect(state.lastPersistenceError, isNull,
          reason: 'a missing spill file is handled inside loadSlides');
    });

    test('corrupt inline JSON degrades gracefully to an empty deck',
        () async {
      SharedPreferences.setMockInitialValues({
        'presentation_slides_config': '{not valid json',
      });

      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      expect(state.slides, isEmpty);
      expect(state.isHydrating, isFalse);
      expect(state.lastPersistenceError, isNull);
    });
  });

  group('P3 — dirty revision & saving state', () {
    test('mutations mark dirty; debounced save converges the revisions',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      expect(state.hasUnsavedChanges, isFalse);
      state.addSlide(slide('A'));

      expect(state.documentRevision, greaterThan(0));
      expect(state.hasUnsavedChanges, isTrue);

      await settleDebounce();

      expect(state.isSaving, isFalse);
      expect(state.savedRevision, state.documentRevision);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('savePresentation toggles isSaving synchronously and clears it',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      final saving = state.savePresentation();
      expect(state.isSaving, isTrue);
      await saving;
      expect(state.isSaving, isFalse);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('edit during in-flight save keeps unsaved flag until re-save',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      final firstSave = state.savePresentation();
      state.addSlide(slide('A')); // bumps the revision mid-save
      expect(state.hasUnsavedChanges, isTrue);

      await firstSave;
      expect(state.savedRevision, lessThan(state.documentRevision));
      expect(state.hasUnsavedChanges, isTrue,
          reason: 'revision moved past the saved one during the save');

      await state.savePresentation();
      expect(state.savedRevision, state.documentRevision);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('setEffect saves immediately instead of debouncing', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      var notified = 0;
      state.addListener(() => notified++);

      state.setEffect(SlideEffect.fade);
      expect(state.slideEffect.name, 'fade');
      expect(state.isSaving, isTrue,
          reason: 'setEffect kicks off an immediate save');
      expect(notified, greaterThanOrEqualTo(2));

      await settleDebounce();
      expect(state.isSaving, isFalse);
      expect(state.hasUnsavedChanges, isFalse);
    });
  });

  group('P4 — persistence error paths', () {
    test('spill save failure surfaces lastPersistenceError and resets saving',
        () async {
      // A deck whose JSON exceeds the 1 MB spill threshold forces
      // ConfigService onto the file path, where the platform channel fails.
      final bigSlide = {
        'title': 'Big',
        'htmlContent': 'x' * 1100000,
      };
      SharedPreferences.setMockInitialValues({
        'presentation_slides_config': jsonEncode([bigSlide]),
      });

      final state = PresentationState();
      await state.ready;
      expect(state.slides.length, 1);

      // Simulate an unwritable documents directory.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        throw Exception('simulated disk full');
      });

      state.addSlide(Slide(title: 'Big', htmlContent: 'x' * 1100000));
      await expectLater(state.savePresentation(), throwsA(anything));

      expect(state.lastPersistenceError, isNotNull);
      expect(state.isSaving, isFalse);
      expect(state.hasUnsavedChanges, isTrue);

      // Cancel the pending debounced save so it cannot fire into the
      // broken channel after the test ends.
      state.dispose();
    });
  });

  group('P5 — mutation history consistency', () {
    test('undo/redo round-trips an added slide', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      expect(state.canUndo, isFalse,
          reason: 'only the initial snapshot exists after hydrate');

      state.addSlide(slide('A'));
      expect(state.canUndo, isTrue);
      expect(state.slides.length, 1);

      state.undo();
      expect(state.slides, isEmpty);
      expect(state.currentSlideIndex, 0);
      expect(state.canRedo, isTrue);
      expect(state.hasUnsavedChanges, isTrue);

      state.redo();
      expect(state.slides.map((s) => s.title), ['A']);
      await flushSaves();
    });

    test('removeSlide clamps current index and records the post-state',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      state.addSlide(slide('A'));
      state.addSlide(slide('B'));
      state.addSlide(slide('C'));
      state.setCurrentSlide(2);
      expect(state.currentSlide?.title, 'C');

      state.removeSlide(2);
      expect(state.currentSlideIndex, 1,
          reason: 'index must stay valid for Present-From-Current flows');

      state.undo();
      expect(state.slides.length, 3);
      expect(state.currentSlideIndex, lessThan(3));
      await flushSaves();
    });

    test('duplicateSlide inserts a copy right after the original', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      state.duplicateSlide(0);
      expect(state.slides.map((s) => s.title), ['A', 'A (Copy)']);

      state.undo();
      expect(state.slides.map((s) => s.title), ['A']);
      await flushSaves();
    });

    test('moveSlide reorders; invalid moves are ignored without history',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));
      state.addSlide(slide('B'));
      state.addSlide(slide('C'));

      state.moveSlide(-1, 0);
      state.moveSlide(0, 99);
      state.moveSlide(1, 1);
      expect(state.slides.map((s) => s.title), ['A', 'B', 'C']);

      state.moveSlide(0, 2);
      expect(state.slides.map((s) => s.title), ['B', 'C', 'A']);

      state.undo();
      expect(state.slides.map((s) => s.title), ['A', 'B', 'C'],
          reason: 'invalid moves must not leave extra history steps');
      await flushSaves();
    });

    test('updateSlide ignores out-of-range indices silently', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      var notified = 0;
      state.addListener(() => notified++);
      final before = notified;

      state.updateSlide(5, slide('Ghost'));
      expect(notified, before);
      expect(state.slides.first.title, 'A');
    });

    test('clearSlides on an empty deck is a no-op', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      var notified = 0;
      state.addListener(() => notified++);
      final before = notified;

      state.clearSlides();
      expect(notified, before);
      expect(state.canUndo, isFalse);
    });

    test('collaboration replace records pre/post snapshots', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('Local'));

      state.replaceSlidesFromCollaboration([slide('Remote')]);
      expect(state.slides.map((s) => s.title), ['Remote']);

      state.undo();
      expect(state.slides.map((s) => s.title), ['Local']);

      state.redo();
      expect(state.slides.map((s) => s.title), ['Remote']);
      await flushSaves();
    });

    test('a new mutation truncates the redo branch', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;

      state.addSlide(slide('A'));
      state.undo();
      expect(state.canRedo, isTrue);

      state.addSlide(slide('C'));
      expect(state.canRedo, isFalse);
      expect(state.slides.map((s) => s.title), ['C']);
      await flushSaves();
    });

    test('insertSlide clamps out-of-range indices to the deck bounds',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      state.insertSlide(99, slide('X'));
      expect(state.slides.map((s) => s.title), ['A', 'X']);

      state.insertSlide(-5, slide('Y'));
      expect(state.slides.map((s) => s.title), ['Y', 'A', 'X']);
    });
  });

  group('P5b — insert pipeline & canvas objects', () {
    test('deck meta, guide settings and slide layout write through', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      const meta = DeckMeta();
      state.setDeckMeta(meta);
      expect(identical(state.deckMeta, meta), isTrue);

      state.updateGuideSettings(const GuideSettings(showGrid: true));
      state.setSlideLayout(SlideLayoutType.values.first);
      expect(
        state.currentSlide!.layoutType,
        SlideLayoutType.values.first.name,
      );
      await flushSaves();
    });

    test('upsert families embed markup in the current slide', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));
      String html() => state.currentSlide!.htmlContent;

      state.upsertSmartArt(const SmartArtGraph(
        layout: SmartArtLayout.basicProcess,
        nodes: [SmartArtNode(id: 1, text: 'N1')],
      ));
      expect(html(), contains('data-smartart'));

      state.upsertChart(const ChartData(
        type: ChartType.column,
        title: 'C',
        categories: ['Q1'],
        series: [ChartSeries(name: 'S', values: [1])],
      ));
      expect(html(), contains('data-chart'));

      state.upsertVideo(const VideoData(src: 'data:video/mp4;base64,AAAA'));
      expect(html(), contains('data-video'));

      state.upsertModel3d(const Model3DData(
        src: 'data:model/gltf-binary;base64,QUJD',
      ));
      expect(html(), contains('data-model3d'));

      state.upsertIcon(const IconItem(
        name: 'Home',
        category: 'UI',
        svgPath: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',
        color: '#FF0000',
        size: 48,
      ));
      expect(html(), contains('data-icon'));

      state.upsertActionButton(const ActionButton(kind: ActionButtonKind.home));
      expect(html(), contains('data-action'));

      final lengthBeforeEquation = html().length;
      state.upsertEquation(
          const EquationData(mathml: '<math><mn>1</mn></math>'));
      expect(html().length, greaterThan(lengthBeforeEquation));

      final lengthBeforeZoom = html().length;
      state.upsertZoom(const ZoomItem(targetSlide: 1));
      expect(html().length, greaterThan(lengthBeforeZoom));

      final lengthBeforeSection = html().length;
      state.upsertSectionZoom(const SectionZoomData());
      expect(html().length, greaterThan(lengthBeforeSection));

      final lengthBeforeCameo = html().length;
      state.upsertCameo(const CameoData(label: 'Camera'));
      expect(html().length, greaterThan(lengthBeforeCameo));

      state.upsertOle(const OleData(fileName: 'a.xlsx', iconLabel: 'Sheet'));
      expect(html(), contains('data-ole'));
      await flushSaves();
    });

    test('smart art and chart upserts replace in place via editIndex',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      const graph = SmartArtGraph(
        layout: SmartArtLayout.basicProcess,
        nodes: [SmartArtNode(id: 1, text: 'N1')],
      );
      state.upsertSmartArt(graph);
      state.upsertSmartArt(graph, editIndex: 0);
      expect(SmartArtService.diagramsIn(state.currentSlide!.htmlContent),
          hasLength(1));

      const chart = ChartData(
        type: ChartType.column,
        title: 'C',
        categories: ['Q1'],
        series: [ChartSeries(name: 'S', values: [1])],
      );
      state.upsertChart(chart);
      state.upsertChart(chart, editIndex: 0);
      expect(ChartService.chartsIn(state.currentSlide!.htmlContent),
          hasLength(1));
      await flushSaves();
    });

    test('free texts and shapes mutate visualElements with history control',
        () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));
      Map<String, dynamic> visual() => state.currentSlide!.visualElements;

      state.updateFreeTexts([
        const FreeTextShape(text: 'Hello', x: 1, y: 2, w: 10, h: 5),
      ]);
      expect(visual()['freeTexts'], isA<List>());

      state.updateFreeTexts(const [], record: false);
      expect(visual().containsKey('freeTexts'), isFalse);

      const a = DrawnShape(
          id: 'sh_a', type: ShapeType.rect, x: 0, y: 0, w: 20, h: 20);
      const b = DrawnShape(
          id: 'sh_b', type: ShapeType.rect, x: 5, y: 5, w: 20, h: 20);
      state.upsertShape(a);
      state.upsertShape(b);
      expect(visual()['shapes'], hasLength(2));

      state.upsertShape(
        const DrawnShape(
            id: 'sh_c', type: ShapeType.oval, x: 1, y: 1, w: 5, h: 5),
        editIndex: 0,
      );
      expect((visual()['shapes'] as List).first['id'], 'sh_c');

      state.updateShapes(const []);
      expect(visual().containsKey('shapes'), isFalse);

      // Re-seed two shapes for the merge/group flows below.
      state.upsertShape(a);
      state.upsertShape(b);

      expect(state.mergeShapes(const [], 'union'), isNotNull,
          reason: 'fewer than two explicit ids fall back to the last two');
      expect(visual()['shapes'], hasLength(1));

      expect(state.mergeShapes(<String>['missing'], 'union'), isNull,
          reason: 'a single shape cannot merge');
      await flushSaves();
    });

    test('groups and layers write through to visualElements', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('A'));

      const a = DrawnShape(
          id: 'sh_a', type: ShapeType.rect, x: 0, y: 0, w: 20, h: 20);
      const b = DrawnShape(
          id: 'sh_b', type: ShapeType.rect, x: 5, y: 5, w: 20, h: 20);
      state.upsertShape(a);
      state.upsertShape(b);

      expect(state.groupShapes(<String>['sh_a']), isNull,
          reason: 'a group needs at least two members');
      final group = state.groupShapes(const ['sh_a', 'sh_b']);
      expect(group, isNotNull);
      expect(state.currentSlide!.visualElements['groups'], hasLength(1));

      state.transformGroup(group!.id, dx: 5);
      final moved =
          (state.currentSlide!.visualElements['shapes'] as List)
              .map((e) => DrawnShape.fromMap(Map<String, dynamic>.from(e)))
              .toList();
      expect(moved.first.x, 5,
          reason: 'group move shifts member shapes');

      state.ungroupShapes(group.id);
      expect(
        state.currentSlide!.visualElements.containsKey('groups'),
        isFalse,
      );

      state.setLayersVisible(const ['does-not-exist'], false);
      state.setLayersLocked(const ['does-not-exist'], true);
      state.renameLayer('does-not-exist', 'X');
      state.reorderLayer(0, 0);

      final layers =
          LayerService.buildLayers(state.slides[state.currentSlideIndex]);
      expect(layers, isNotEmpty);
      state.updateLayerState(LayerService.stateToMap(layers));
      state.setLayersVisible([layers.first.id], false);
      state.setLayersLocked([layers.first.id], true);
      state.renameLayer(layers.first.id, 'Renamed');
      state.reorderLayer(0, 0);
      expect(state.currentSlide!.visualElements['layers'], isA<List>());
      await flushSaves();
    });

    test('buildHtmlDeck renders a standalone player document', () async {
      final state = PresentationState();
      addTearDown(state.dispose);
      await state.ready;
      state.addSlide(slide('Alpha'));
      state.addSlide(slide('Beta'));

      final deck = state.buildHtmlDeck(startIndex: 1);
      expect(deck, isNotEmpty);
      expect(deck, contains('Alpha'));
      expect(deck, contains('Beta'));
    });
  });
}
