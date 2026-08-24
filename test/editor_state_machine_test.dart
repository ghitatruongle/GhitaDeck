// T01 (v2.0.1-beta.2) — EditorState machine + time-machine integration tests.
//
//   P6  editor_state state machine: selection, scribble, zoom, toggles,
//       HTML insertion, sanitization gate, format painter, slide removal
//       reconciliation, edit/clear round-trip
//   P7  editor_state ↔ time machine: history cap (30 snapshots) and the
//       editor reflecting undo/redo results
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ghita_editor_state_test');
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// undo()/redo() fire-and-forget saves must finish before dispose.
  Future<void> flushSaves() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  group('P6 — editor state machine', () {
    test('shape selection: single click replaces, multi click toggles',
        () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.selectShape('a');
      expect(editor.selectedShapeIds, {'a'});

      editor.selectShape('b', multi: true);
      expect(editor.selectedShapeIds, {'a', 'b'});

      editor.selectShape('b', multi: true);
      expect(editor.selectedShapeIds, {'a'}, reason: 'multi click toggles off');

      editor.selectShape('c');
      expect(editor.selectedShapeIds, {'c'});

      editor.clearShapeSelection();
      expect(editor.selectedShapeIds, isEmpty);

      var notified = 0;
      editor.addListener(() => notified++);
      editor.clearShapeSelection();
      expect(notified, 0, reason: 'clearing an empty selection is a no-op');
    });

    test('scribble mode collects points and resets on finish', () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.setScribbleMode(true);
      expect(editor.scribbleMode, isTrue);

      editor.addScribblePoint(const Offset2D(1, 2));
      editor.addScribblePoint(const Offset2D(3, 4));
      expect(editor.scribblePoints, hasLength(2));

      editor.finishScribble();
      expect(editor.scribblePoints, isEmpty);
      expect(editor.scribbleMode, isFalse);

      editor.setScribbleMode(true);
      editor.addScribblePoint(const Offset2D(5, 6));
      editor.setScribbleMode(false);
      expect(editor.scribblePoints, isEmpty,
          reason: 'leaving scribble mode drops the stroke');
    });

    test('zoom clamps to the 0.5x–2.0x range', () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.setZoom(0.1);
      expect(editor.zoomLevel, 0.5);
      editor.setZoom(9);
      expect(editor.zoomLevel, 2.0);

      editor.setZoom(1.0);
      editor.zoomOut();
      expect(editor.zoomLevel, closeTo(0.9, 0.001));
      for (var i = 0; i < 10; i++) {
        editor.zoomOut();
      }
      expect(editor.zoomLevel, 0.5);

      for (var i = 0; i < 20; i++) {
        editor.zoomIn();
      }
      expect(editor.zoomLevel, 2.0);
    });

    test('UI toggles and setters flip their flags', () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      expect(editor.showNotes, isFalse);
      editor.toggleNotes();
      expect(editor.showNotes, isTrue);

      expect(editor.showPreview, isTrue);
      editor.togglePreview();
      expect(editor.showPreview, isFalse);

      editor.setLoading(true);
      expect(editor.isLoading, isTrue);

      editor.setSlideEffectOverride(SlideEffect.fade);
      expect(editor.slideEffectOverride, SlideEffect.fade);

      editor.selectSlide(3);
      expect(editor.selectedSlideIndex, 3);
    });

    test('insertHtmlTag wraps the selection or opens a pair at the caret',
        () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.htmlController.text = 'hello world';
      editor.htmlController.selection =
          const TextSelection(baseOffset: 6, extentOffset: 11);
      editor.insertHtmlTag('<b>', '</b>');
      expect(editor.htmlController.text, 'hello <b>world</b>');
      expect(editor.htmlController.selection.baseOffset, 14,
          reason: 'caret lands right after the wrapped text, inside the pair');

      editor.htmlController.text = 'abc';
      editor.htmlController.selection =
          const TextSelection.collapsed(offset: 3);
      editor.insertHtmlTag('<u>', '</u>');
      expect(editor.htmlController.text, 'abc<u></u>');
      expect(editor.htmlController.selection.baseOffset, 6,
          reason: 'caret lands between the opened pair');
    });

    test('insertHtml replaces the selection or appends', () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.htmlController.text = 'hello world';
      editor.htmlController.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      editor.insertHtml('<i>x</i>');
      expect(editor.htmlController.text, '<i>x</i> world');

      editor.htmlController.text = 'abc';
      editor.htmlController.selection =
          const TextSelection.collapsed(offset: -1);
      editor.insertHtml('<br>');
      expect(editor.htmlController.text, 'abc<br>');
    });

    test('preview html follows the editor text after the debounce window',
        () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.htmlController.text = '<p>updated body</p>';
      expect(editor.previewHtml, '');
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(editor.previewHtml, '<p>updated body</p>');
    });

    test('validateAndSanitizeHtml gates empty and executable input',
        () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      expect(editor.validateAndSanitizeHtml('<h1>Hi</h1>'), isNull);
      expect(editor.lastSanitizedHtml, isNotEmpty);

      expect(editor.validateAndSanitizeHtml('   '), isNotNull,
          reason: 'empty HTML is rejected');

      expect(editor.validateAndSanitizeHtml('<script>alert(1)</script>'),
          isNotNull, reason: 'script-only input is fully blocked');

      final risky = editor.validateAndSanitizeHtml('<p onclick="x()">ok</p>');
      expect(risky, isNull, reason: 'content survives attribute stripping');
      expect(editor.lastSanitizedHtml, isNot(contains('onclick')));
    });

    test('format painter: capture once, paste once, then disarm', () async {
      final editor = EditorState();
      addTearDown(editor.dispose);

      expect(editor.formatPainterArmed, isFalse);
      expect(editor.pasteFormatToSelection(), isFalse,
          reason: 'nothing armed yet');

      editor.htmlController.text = '<p><b>bold</b> plain</p>';
      // '<b>bold</b>' spans offsets 3..14 inside the paragraph.
      editor.htmlController.selection =
          const TextSelection(baseOffset: 3, extentOffset: 14);
      editor.captureFormat();
      expect(editor.formatPainterArmed, isTrue);

      editor.htmlController.text = '<p>target text</p>';
      editor.htmlController.selection =
          const TextSelection(baseOffset: 3, extentOffset: 9);
      expect(editor.pasteFormatToSelection(), isTrue);
      expect(editor.htmlController.text, contains('<b>target</b>'));

      expect(editor.pasteFormatToSelection(), isFalse,
          reason: 'one-shot painter disarms after use');

      const source = DrawnShape(id: 'src', fillColor: '#FF0000');
      editor.captureFormat(selectedShape: source);
      final painted = editor.pasteFormatToShape(const DrawnShape(id: 'tgt'));
      expect(painted?.fillColor, '#FF0000');

      editor.clearFormatPainter();
      expect(editor.formatPainterArmed, isFalse);
    });

    test('effect name resolves for every transition', () async {
      for (final effect in SlideEffect.values) {
        expect(EditorState.effectName(effect), isNotEmpty);
      }
      expect(EditorState.effectName(SlideEffect.fade), 'Fade');
    });
  });

  group('P6b — editor ↔ presentation reconciliation', () {
    test('editSlide loads a slide into the controllers; clearEditor resets',
        () async {
      final pres = PresentationState();
      addTearDown(pres.dispose);
      await pres.ready;
      pres.addSlide(Slide(
        title: 'Target',
        htmlContent: '<h1>Target</h1>',
        notes: 'note line',
        effect: SlideEffect.fade,
      ));

      final editor = EditorState();
      addTearDown(editor.dispose);

      editor.editSlide(0, pres);
      expect(editor.isEditing, isTrue);
      expect(editor.editingIndex, 0);
      expect(editor.htmlController.text, '<h1>Target</h1>');
      expect(editor.titleController.text, 'Target');
      expect(editor.notesController.text, 'note line');
      expect(editor.slideEffectOverride, SlideEffect.fade);
      expect(editor.selectedSlideIndex, 0);
      expect(editor.previewHtml, '<h1>Target</h1>',
          reason: 'editSlide refreshes the preview without waiting');

      editor.clearEditor();
      expect(editor.isEditing, isFalse);
      expect(editor.htmlController.text, '');
      expect(editor.titleController.text, 'New Slide');
      expect(editor.notesController.text, '');
      expect(editor.slideEffectOverride, isNull);

      editor.editSlide(5, pres);
      expect(editor.editingIndex, isNull,
          reason: 'out-of-range index is ignored');
    });

    test('handleSlideRemoved reconciles selection and editing indices',
        () async {
      final pres = PresentationState();
      addTearDown(pres.dispose);
      await pres.ready;
      pres.addSlide(Slide(title: 'A', htmlContent: '<h1>A</h1>'));
      pres.addSlide(Slide(title: 'B', htmlContent: '<h1>B</h1>'));
      pres.addSlide(Slide(title: 'C', htmlContent: '<h1>C</h1>'));

      final editor = EditorState();
      addTearDown(editor.dispose);
      editor.editSlide(1, pres);
      editor.selectSlide(2);

      // Remove the selected slide (index 2): selection clears, editing keeps.
      editor.handleSlideRemoved(2, 2);
      expect(editor.selectedSlideIndex, -1);
      expect(editor.editingIndex, 1);

      // Remove a slide before the editing one: both indices shift left.
      editor.handleSlideRemoved(0, 2);
      expect(editor.selectedSlideIndex, -1,
          reason: 'removed index 0 is not below the cleared selection');
      expect(editor.editingIndex, 0);

      // Remove the slide being edited: the editor resets.
      editor.handleSlideRemoved(0, 1);
      expect(editor.editingIndex, isNull);
      expect(editor.htmlController.text, '');

      // Selection clamps when it runs past the shortened deck.
      editor.selectSlide(2);
      editor.handleSlideRemoved(0, 1);
      expect(editor.selectedSlideIndex, 0);
    });
  });

  group('P7 — editor ↔ time machine', () {
    test('history caps at 30 snapshots and undo walks back to the oldest',
        () async {
      final pres = PresentationState();
      addTearDown(pres.dispose);
      await pres.ready;

      for (var i = 0; i < 40; i++) {
        pres.addSlide(Slide(title: 'S$i', htmlContent: '<p>$i</p>'));
      }
      expect(pres.slides, hasLength(40));

      var undos = 0;
      while (pres.canUndo && undos < 100) {
        pres.undo();
        undos++;
      }
      expect(undos, lessThanOrEqualTo(29),
          reason: 'only 30 snapshots are retained');
      expect(pres.slides.length, 11,
          reason: 'the oldest retained snapshot is the one after 11 adds');
      await flushSaves();
    });

    test('editor reflects the deck after an undo step', () async {
      final pres = PresentationState();
      addTearDown(pres.dispose);
      await pres.ready;
      pres.addSlide(Slide(title: 'First', htmlContent: '<h1>First</h1>'));

      final editor = EditorState();
      addTearDown(editor.dispose);
      editor.editSlide(0, pres);
      expect(editor.titleController.text, 'First');

      pres.addSlide(Slide(title: 'Second', htmlContent: '<h1>Second</h1>'));
      pres.undo();
      expect(pres.slides, hasLength(1));

      editor.editSlide(pres.currentSlideIndex, pres);
      expect(editor.titleController.text, 'First');
      expect(editor.previewHtml, '<h1>First</h1>');
      await flushSaves();
    });
  });
}
