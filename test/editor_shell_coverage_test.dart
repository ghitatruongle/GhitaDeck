import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/l10n/app_localizations.dart';
import 'package:ghita_deck/providers/presentation_state.dart';
import 'package:ghita_deck/screens/editor/editor_shell.dart';
import 'package:ghita_deck/screens/editor/editor_state.dart';
import 'package:ghita_deck/screens/editor/html_editor_panel.dart';
import 'package:ghita_deck/screens/editor/slide_list_panel.dart';
import 'package:ghita_deck/screens/widgets/advanced_export_dialog.dart';
import 'package:ghita_deck/screens/widgets/animation_pane.dart';
import 'package:ghita_deck/screens/widgets/collaboration_panel.dart';
import 'package:ghita_deck/screens/widgets/comments_panel.dart';
import 'package:ghita_deck/screens/widgets/designer_panel.dart';
import 'package:ghita_deck/screens/widgets/import_dialog.dart';
import 'package:ghita_deck/screens/widgets/m9_productivity_dialogs.dart';
import 'package:ghita_deck/screens/widgets/profile_cloud_dialogs.dart';
import 'package:ghita_deck/screens/widgets/reuse_compare_dialog.dart';
import 'package:ghita_deck/screens/widgets/selection_pane.dart';
import 'package:ghita_deck/screens/widgets/slide_preview.dart';
import 'package:ghita_deck/services/collaboration_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _surface = Size(1440, 900);
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

String? _clipboard;

class _Harness {
  final PresentationState pres = PresentationState();
  final EditorState editor = EditorState();
  final CollaborationService collab = CollaborationService();

  void disposeAll() {
    editor.dispose();
    collab.dispose();
    pres.dispose();
  }
}

Widget _localizedApp(Widget home) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: home),
    );

Future<_Harness> _pumpShell(
  WidgetTester tester, {
  List<Slide> slides = const [],
}) async {
  final harness = _Harness();
  addTearDown(harness.disposeAll);
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PresentationState>.value(value: harness.pres),
        ChangeNotifierProvider<EditorState>.value(value: harness.editor),
        Provider<CollaborationService>.value(value: harness.collab),
      ],
      child: _localizedApp(const EditorShell()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  for (final slide in slides) {
    harness.pres.addSlide(slide);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 100));
  return harness;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 6));
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final finder = find.byIcon(icon).first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}

void _absorbKnownOverflow(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Future<void> _closeTopDialog(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Map<ShortcutActivator, VoidCallback> _shellBindings(WidgetTester tester) {
  final shortcuts = tester.widget<CallbackShortcuts>(
    find
        .ancestor(
          of: find.byType(HtmlEditorPanel),
          matching: find.byType(CallbackShortcuts),
        )
        .first,
  );
  return shortcuts.bindings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;

  setUp(() async {
    tempDocsDir = await Directory.systemTemp.createTemp('ghita_editor_docs_');
    addTearDown(() => tempDocsDir.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({});
    _clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDocsDir;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': _clipboard ?? ''};
      }
      return null;
    });
  });

  tearDown(() {
    _clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
      'empty deck mounts the 3-panel layout with disabled undo and redo',
      (tester) async {
    await _pumpShell(tester);

    expect(find.byType(EditorShell), findsOneWidget);
    expect(find.byType(SlideListPanel), findsOneWidget);
    expect(find.byType(HtmlEditorPanel), findsOneWidget);
    expect(find.byType(SelectionPane), findsNothing);
    expect(find.byType(AnimationPane), findsNothing);
    expect(find.byType(CommentsPanel), findsNothing);
    expect(find.byType(DesignerPanel), findsNothing);
    expect(find.text('Slides (0)'), findsNWidgets(2));
    expect(find.text('No slides yet'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.redo))
          .onPressed,
      isNull,
    );
    await _settle(tester);
  });

  testWidgets('top bar undo, redo and clear-all buttons drive the deck',
      (tester) async {
    final harness = await _pumpShell(tester, slides: [
      Slide(title: 'One', htmlContent: '<h1>One</h1>', timestamp: 1),
      Slide(title: 'Two', htmlContent: '<h1>Two</h1>', timestamp: 2),
    ]);
    expect(find.text('Slides (2)'), findsNWidgets(2));

    final undo = find.widgetWithIcon(IconButton, Icons.undo);
    final redo = find.widgetWithIcon(IconButton, Icons.redo);
    expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
    expect(tester.widget<IconButton>(redo).onPressed, isNull);

    tester.widget<IconButton>(undo).onPressed!();
    await tester.pump();
    await tester.pump();
    expect(harness.pres.slides, hasLength(1));
    expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
    expect(tester.widget<IconButton>(redo).onPressed, isNotNull);

    tester.widget<IconButton>(redo).onPressed!();
    await tester.pump();
    await tester.pump();
    expect(harness.pres.slides, hasLength(2));
    expect(tester.widget<IconButton>(redo).onPressed, isNull);

    await _tapIcon(tester, Icons.delete_sweep);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.pres.slides, hasLength(2));

    await _tapIcon(tester, Icons.delete_sweep);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Clear All Slides'),
    ));
    await tester.pump();
    expect(harness.pres.slides, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(
      of: find.byType(SnackBar),
      matching: find.text('Undo'),
    ));
    await tester.pump();
    expect(harness.pres.slides, hasLength(2));
    await _settle(tester);
  });

  testWidgets('sidebar splitter resizes and the toggle collapses the panel',
      (tester) async {
    await _pumpShell(tester,
        slides: [
      Slide(title: 'S1', htmlContent: '<h1>S1</h1>', timestamp: 3),
    ]);

    double panelWidth() => tester.getSize(find.byType(SlideListPanel)).width;
    expect(panelWidth(), 180);

    Future<void> dragSplitter(double dx) async {
      final edge = tester.getTopRight(find.byType(SlideListPanel));
      await tester.dragFrom(Offset(edge.dx + 4, 300), Offset(dx, 0));
      await tester.pump();
    }

    await dragSplitter(60);
    expect(panelWidth(), 240);
    await dragSplitter(200);
    expect(panelWidth(), 360);
    await dragSplitter(-200);
    expect(panelWidth(), 160);

    await _tapIcon(tester, Icons.view_sidebar);
    expect(find.byType(SlideListPanel), findsNothing);

    await _tapIcon(tester, Icons.view_sidebar_outlined);
    expect(find.byType(SlideListPanel), findsOneWidget);
    expect(panelWidth(), 160);
    await _settle(tester);
  });

  testWidgets('slide thumbnails wire selection into presentation and editor',
      (tester) async {
    final harness = await _pumpShell(tester, slides: [
      Slide(title: 'One', htmlContent: '<h1>One</h1>', timestamp: 1),
      Slide(title: 'Two', htmlContent: '<h1>Two</h1>', timestamp: 2),
    ]);
    final pres = harness.pres;
    final editor = harness.editor;

    await _tapIcon(tester, Icons.add);
    expect(pres.slides, hasLength(3));
    expect(pres.currentSlideIndex, 2);
    expect(editor.isEditing, isTrue);
    expect(editor.editingIndex, 2);
    expect(editor.titleController.text, 'New Slide');

    await tester.tap(find.text('Two'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(pres.currentSlideIndex, 1);
    expect(editor.selectedSlideIndex, 1);
    expect(editor.editingIndex, 1);
    expect(editor.htmlController.text, '<h1>Two</h1>');
    expect(editor.previewHtml, '<h1>Two</h1>');
    expect(find.byType(SlidePreview), findsOneWidget);

    await _tapIcon(tester, Icons.copy);
    expect(pres.slides, hasLength(4));

    await _tapIcon(tester, Icons.delete_outline);
    await tester.pump(const Duration(milliseconds: 500));
    expect(pres.slides, hasLength(3));
    await tester.tap(find.descendant(
      of: find.byType(SnackBar),
      matching: find.text('Undo'),
    ));
    await tester.pump();
    expect(pres.slides, hasLength(4));
    await _settle(tester);
  });

  testWidgets('advanced tools expand and aux panes switch exclusively',
      (tester) async {
    final harness = await _pumpShell(tester,
        slides: [
      Slide(title: 'S1', htmlContent: '<h1>S1</h1>', timestamp: 4),
    ]);
    expect(find.text('Selection Pane'), findsNothing);

    await _tapLabel(tester, 'More tools');
    expect(find.text('Collapse tools'), findsOneWidget);
    expect(find.text('Selection Pane'), findsOneWidget);

    await _tapLabel(tester, 'Selection Pane');
    _absorbKnownOverflow(tester);
    expect(find.byType(SelectionPane), findsOneWidget);
    expect(find.text('Selection Pane'), findsNWidgets(2));

    await _tapLabel(tester, 'Animations');
    _absorbKnownOverflow(tester);
    expect(find.byType(AnimationPane), findsOneWidget);
    expect(find.byType(SelectionPane), findsNothing);

    await _tapLabel(tester, 'Comments');
    _absorbKnownOverflow(tester);
    expect(find.byType(CommentsPanel), findsOneWidget);
    expect(find.byType(AnimationPane), findsNothing);

    await _tapLabel(tester, 'Designer');
    _absorbKnownOverflow(tester);
    expect(find.byType(DesignerPanel), findsOneWidget);
    expect(find.byType(CommentsPanel), findsNothing);

    await _tapLabel(tester, 'Designer');
    expect(find.byType(DesignerPanel), findsNothing);

    await _tapLabel(tester, 'Layout');
    await tester.pumpAndSettle();
    expect(find.text('Blank'), findsOneWidget);
    await tester.tap(find.text('Blank'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Layout applied'), findsOneWidget);
    expect(find.text('Blank'), findsNothing);
    expect(harness.pres.slides.first.layoutType, 'blank');

    await _tapLabel(tester, 'Read aloud');
    expect(find.byType(ReadAloudBar), findsOneWidget);
    await _tapLabel(tester, 'Read aloud');
    expect(find.byType(ReadAloudBar), findsNothing);

    await _tapLabel(tester, 'Collapse tools');
    expect(find.text('Selection Pane'), findsNothing);
    await _settle(tester);
  });

  testWidgets(
      'editor shortcuts open the export dialog and drive the format painter',
      (tester) async {
    final harness = await _pumpShell(tester);
    final editor = harness.editor;

    _shellBindings(tester)[const SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
    )]!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AdvancedExportDialog), findsOneWidget);
    await _closeTopDialog(tester);
    expect(find.byType(AdvancedExportDialog), findsNothing);

    _shellBindings(tester)[const SingleActivator(
      LogicalKeyboardKey.keyC,
      control: true,
      shift: true,
    )]!();
    await tester.pump();
    expect(editor.formatPainterArmed, isTrue);

    editor.htmlController.text = 'abc';
    editor.htmlController.selection =
        const TextSelection(baseOffset: 0, extentOffset: 3);
    _shellBindings(tester)[const SingleActivator(
      LogicalKeyboardKey.keyV,
      control: true,
      shift: true,
    )]!();
    await tester.pump();
    expect(editor.formatPainterArmed, isFalse);

    _shellBindings(tester)[const SingleActivator(
      LogicalKeyboardKey.keyI,
      control: true,
      shift: true,
    )]!();
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
  });

  testWidgets('views popup, top bar and advanced dialogs open and close',
      (tester) async {
    final harness = await _pumpShell(tester,
        slides: [
          Slide(title: 'S1', htmlContent: '<h1>S1</h1>\n<p>body</p>')
        ]);

    await _tapLabel(tester, 'Templates');
    await tester.pumpAndSettle();
    expect(find.text('Choose a Template'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    await tester.tap(find.byType(ListTile).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('HTML Preview:'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Use This Template'),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(harness.editor.htmlController.text, isNotEmpty);
    expect(find.textContaining('Applied template'), findsOneWidget);
    expect(find.text('Choose a Template'), findsOneWidget);
    await tester.tap(find.text('Close'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Choose a Template'), findsNothing);
    await _settle(tester);

    await _tapLabel(tester, 'Import');
    expect(find.byType(ImportDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ImportDialog),
        matching: find.byIcon(Icons.close),
      ).first,
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ImportDialog), findsNothing);

    await _tapLabel(tester, 'Collaboration');
    expect(find.byType(CollaborationPanel), findsOneWidget);
    await _closeTopDialog(tester);
    expect(find.byType(CollaborationPanel), findsNothing);

    await _tapLabel(tester, 'More tools');

    await _tapIcon(tester, Icons.grid_view_outlined);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Notes'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Notes — Slide'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'hello notes',
    );
    await tester.pump();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Save'),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.pres.slides.first.notes, 'hello notes');
    await _settle(tester);

    await _tapLabel(tester, 'Find / Replace');
    expect(find.byType(FindReplaceDialog), findsOneWidget);
    await _closeTopDialog(tester);

    await _tapLabel(tester, 'Spell check');
    expect(find.byType(SpellcheckDialog), findsOneWidget);
    await _closeTopDialog(tester);

    await _tapLabel(tester, 'Accessibility');
    expect(find.byType(AccessibilityPanel), findsOneWidget);
    await _closeTopDialog(tester);

    await _tapLabel(tester, 'Add-ins');
    expect(find.byType(AddinManagerDialog), findsOneWidget);
    await _closeTopDialog(tester);

    await _tapLabel(tester, 'Reuse slides');
    expect(find.byType(ReuseCompareDialog), findsOneWidget);
    await _closeTopDialog(tester);

    await _tapLabel(tester, 'Your profile');
    expect(find.byType(ProfileDialog), findsOneWidget);
    await _closeTopDialog(tester);
    await _settle(tester);
  });
}
