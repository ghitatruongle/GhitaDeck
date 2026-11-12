import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/l10n/app_localizations.dart';
import 'package:ghita_deck/providers/ai_provider_manager.dart';
import 'package:ghita_deck/providers/app_provider.dart';
import 'package:ghita_deck/providers/locale_provider.dart';
import 'package:ghita_deck/providers/presentation_state.dart';
import 'package:ghita_deck/providers/shortcuts_provider.dart';
import 'package:ghita_deck/screens/editor/editor_state.dart';
import 'package:ghita_deck/screens/home_screen.dart';
import 'package:ghita_deck/screens/recent_projects_screen.dart';
import 'package:ghita_deck/screens/widgets/command_palette_dialog.dart';
import 'package:ghita_deck/screens/widgets/office_buttons.dart';
import 'package:ghita_deck/screens/widgets/ribbon_toolbar.dart';
import 'package:ghita_deck/screens/widgets/status_bar.dart';
import 'package:ghita_deck/services/engine_audit_log.dart';
import 'package:ghita_deck/services/rust_engine.dart';
import 'package:ghita_deck/utils/shortcut_intents.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

String? _clipboard;

class _HomeHarness {
  final PresentationState pres = PresentationState();
  final AppProvider app = AppProvider();
  final ShortcutsProvider shortcuts = ShortcutsProvider();
  final AIProviderManager ai = AIProviderManager();
  final LocaleProvider locale = LocaleProvider();
  final RustEngineService engine = RustEngineService(
    rustInit: () async => throw Exception('no native library in tests'),
    rustProbe: () async => throw Exception('no native library in tests'),
  );
  EditorState? boundEditor;

  void disposeAll() {
    ai.dispose();
    engine.dispose();
    shortcuts.dispose();
    locale.dispose();
    app.dispose();
    pres.dispose();
  }
}

Future<_HomeHarness> _pumpHome(WidgetTester tester) async {
  final harness = _HomeHarness();
  addTearDown(harness.disposeAll);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PresentationState>.value(value: harness.pres),
        ChangeNotifierProvider<AppProvider>.value(value: harness.app),
        ChangeNotifierProvider<ShortcutsProvider>.value(value: harness.shortcuts),
        ChangeNotifierProvider<AIProviderManager>.value(value: harness.ai),
        ChangeNotifierProvider<LocaleProvider>.value(value: harness.locale),
        ChangeNotifierProvider<RustEngineService>.value(value: harness.engine),
      ],
      child: const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  harness.boundEditor =
      Provider.of<EditorState>(tester.element(_homeStack()), listen: false);
  return harness;
}

Future<void> _pumpRibbon(WidgetTester tester, RibbonToolbar ribbon) async {
  await tester.binding.setSurfaceSize(const Size(1400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: ribbon),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _sidebarItem(String label) => find.ancestor(
      of: find.descendant(
        of: find.byType(OfficeSidebarItem),
        matching: find.text(label),
      ),
      matching: find.byType(OfficeSidebarItem),
    );

Finder _homeStack() => find.ancestor(
      of: find.byType(RecentProjectsScreen, skipOffstage: false),
      matching: find.byType(IndexedStack),
    );

Future<void> _invoke<T extends Intent>(WidgetTester tester, T intent) async {
  final context = tester.element(_homeStack());
  Actions.maybeInvoke<T>(context, intent);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settleTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 6));
}

PresentationState _newState() => PresentationState();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ghita_home_ribbon_test');
    EngineAuditLog.debugOverridePath =
        '${tempDir.path}${Platform.pathSeparator}engine.log';
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
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
    EngineAuditLog.debugOverridePath = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('HomeScreen', () {
    testWidgets('sidebar destinations switch the IndexedStack index',
        (tester) async {
      final harness = await _pumpHome(tester);

      expect(
        tester.widget<IndexedStack>(_homeStack()).index,
        0,
      );
      expect(find.byType(RibbonToolbar), findsOneWidget);
      expect(find.byType(StatusBar), findsOneWidget);

      await tester.tap(_sidebarItem('Projects'));
      await tester.pump();
      expect(
        tester.widget<IndexedStack>(_homeStack()).index,
        1,
      );
      expect(find.byType(RibbonToolbar), findsNothing);
      expect(find.byType(StatusBar), findsNothing);

      await tester.tap(_sidebarItem('Templates'));
      await tester.pump();
      expect(
        tester.widget<IndexedStack>(_homeStack()).index,
        2,
      );

      await tester.tap(_sidebarItem('AI Chat'));
      await tester.pump();
      expect(
        tester.widget<IndexedStack>(_homeStack()).index,
        3,
      );

      await tester.tap(_sidebarItem('Settings'));
      await tester.pump();
      expect(
        tester.widget<IndexedStack>(_homeStack()).index,
        4,
      );

      await tester.tap(_sidebarItem('Editor'));
      await tester.pump();
      expect(
        tester.widget<IndexedStack>(_homeStack()).index,
        0,
      );
      expect(find.byType(RibbonToolbar), findsOneWidget);
      expect(harness.app.currentIndex, 0);

      await tester.tap(find.byTooltip('Hide Sidebar').first);
      await tester.pump();
      expect(find.byType(OfficeSidebarItem), findsNothing);
      expect(find.byTooltip('Show Sidebar'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Show Sidebar').first);
      await tester.pump();
      expect(find.byType(OfficeSidebarItem), findsNWidgets(5));
      await _settleTimers(tester);
    });

    testWidgets('command palette opens on Ctrl+K intent and navigates',
        (tester) async {
      final harness = await _pumpHome(tester);

      final context = tester.element(_homeStack());
      Actions.maybeInvoke<CommandPaletteIntent>(
          context, const CommandPaletteIntent());
      await _openDialog(tester);
      expect(find.byType(CommandPaletteDialog), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(CommandPaletteDialog),
          matching: find.byType(TextField),
        ),
        'sett',
      );
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(CommandPaletteDialog),
        matching: find.text('Settings'),
      ));
      await _openDialog(tester);
      expect(find.byType(CommandPaletteDialog), findsNothing);
      expect(harness.app.currentIndex, 4);

      await tester.tap(_sidebarItem('Editor'));
      await tester.pump();
      expect(harness.app.currentIndex, 0);

      await tester.tap(find.byTooltip('Search (Ctrl+K)').first);
      await _openDialog(tester);
      expect(find.byType(CommandPaletteDialog), findsOneWidget);

      await tester.tapAt(const Offset(10, 500));
      await _openDialog(tester);
      expect(find.byType(CommandPaletteDialog), findsNothing);
      await _settleTimers(tester);
    });

    testWidgets('status bar reflects exportStatus and zoom changes',
        (tester) async {
      final harness = await _pumpHome(tester);

      Finder statusText(String label) => find.descendant(
            of: find.byType(StatusBar),
            matching: find.text(label),
          );

      expect(statusText('Saved'), findsOneWidget);

      harness.pres.exportStatus = 'exporting';
      harness.app.toggleTheme();
      await tester.pump();
      expect(statusText('Exporting...'), findsOneWidget);

      harness.pres.exportStatus = 'success';
      harness.app.toggleTheme();
      await tester.pump();
      expect(statusText('Exported'), findsOneWidget);

      harness.pres.exportStatus = 'error';
      harness.app.toggleTheme();
      await tester.pump();
      expect(statusText('Error'), findsOneWidget);

      harness.pres.exportStatus = null;
      harness.app.toggleTheme();
      await tester.pump();
      expect(statusText('Saved'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(StatusBar),
        matching: find.byIcon(Icons.remove),
      ));
      await tester.pump();
      expect(statusText('90%'), findsOneWidget);

      await _invoke(tester, const ZoomResetIntent());
      expect(statusText('100%'), findsOneWidget);

      await _invoke(tester, const ZoomInIntent());
      expect(statusText('110%'), findsOneWidget);

      await _invoke(tester, const ZoomOutIntent());
      expect(statusText('100%'), findsOneWidget);
      await _settleTimers(tester);
    });

    testWidgets('deck intents add, navigate, duplicate, delete and restore',
        (tester) async {
      final harness = await _pumpHome(tester);
      expect(harness.pres.slides, isEmpty);

      await _invoke(tester, const NewSlideIntent());
      expect(harness.pres.slides, hasLength(1));
      expect(harness.pres.slides.first.title, 'New Slide');

      await _invoke(tester, const NewSlideIntent());
      expect(harness.pres.slides, hasLength(2));

      await _invoke(tester, const NextSlideIntent());
      expect(harness.pres.currentSlideIndex, 1);

      await _invoke(tester, const PreviousSlideIntent());
      expect(harness.pres.currentSlideIndex, 0);

      await _invoke(tester, const DuplicateSlideIntent());
      expect(harness.pres.slides, hasLength(3));
      expect(harness.pres.slides[1].title, 'New Slide (Copy)');

      await _invoke(tester, const DeleteSlideIntent());
      expect(harness.pres.slides, hasLength(2));
      expect(find.textContaining('Deleted'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Undo'),
      ));
      await tester.pump();
      expect(harness.pres.slides, hasLength(3));

      await _invoke(tester, const SaveProjectIntent());
      await tester.pump(const Duration(seconds: 1));
      expect(harness.pres.hasUnsavedChanges, isFalse);
      await _settleTimers(tester);
    });

    testWidgets('clipboard intents edit the shared editor state',
        (tester) async {
      final harness = await _pumpHome(tester);
      final editor = harness.boundEditor!;
      editor.htmlController.text = '<p>hello</p>';
      editor.htmlController.selection =
          const TextSelection.collapsed(offset: 0);

      await _invoke(tester, const SelectAllIntent());
      expect(
        harness.boundEditor!.htmlController.selection,
        const TextSelection(baseOffset: 0, extentOffset: 12),
      );

      await _invoke(tester, const CopyIntent());
      expect(_clipboard, '<p>hello</p>');

      editor.htmlController.selection =
          const TextSelection.collapsed(offset: 12);
      await _invoke(tester, const PasteIntent());
      expect(editor.htmlController.text, '<p>hello</p><p>hello</p>');

      await _invoke(tester, const SelectAllIntent());
      await _invoke(tester, const CutIntent());
      expect(editor.htmlController.text, isEmpty);
      expect(_clipboard, '<p>hello</p><p>hello</p>');

      await _invoke(tester, const PasteIntent());
      expect(editor.htmlController.text, '<p>hello</p><p>hello</p>');
      await _settleTimers(tester);
    });

    testWidgets('view tab toggles grid, ruler, fullscreen and zoom dialog',
        (tester) async {
      final harness = await _pumpHome(tester);

      await tester.tap(find.text('View'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      Finder gridPainter() => find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_OfficeGridPainter');
      expect(gridPainter(), findsNothing);

      await tester.tap(find.byTooltip('Toggle grid overlay'));
      await tester.pump();
      expect(gridPainter(), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle grid overlay'));
      await tester.pump();
      expect(gridPainter(), findsNothing);

      await tester.tap(find.byTooltip('Toggle ruler overlay'));
      await tester.pump();

      await tester.tap(find.byTooltip('Toggle fullscreen window'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      harness.boundEditor!.setZoom(1.4);
      await tester.pump();

      await tester.tap(find.byTooltip('Adjust zoom level'));
      await _openDialog(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '100%'),
      ));
      await tester.pump();
      expect(harness.boundEditor!.zoomLevel, 1.0);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Close'),
      ));
      await _openDialog(tester);
      expect(find.byType(AlertDialog), findsNothing);
      await _settleTimers(tester);
    });
  });

  group('RibbonToolbar', () {
    testWidgets('home tab formatting buttons drive the editor state',
        (tester) async {
      final pres = _newState();
      addTearDown(pres.dispose);
      await pres.ready;
      pres.addSlide(Slide(title: 'A', htmlContent: '<h1>A</h1>'));
      final editor = EditorState();
      addTearDown(editor.dispose);
      final inserted = <String>[];

      await _pumpRibbon(
        tester,
        RibbonToolbar(
          presentationState: pres,
          canUndo: true,
          canRedo: true,
          onUndo: pres.undo,
          onRedo: pres.redo,
          onInsertHtmlTag: editor.insertHtmlTag,
          onInsertHtml: inserted.add,
        ),
      );

      Future<void> wrapSelection(
          IconData icon, String open, String close) async {
        editor.htmlController.text = 'abc';
        editor.htmlController.selection =
            const TextSelection(baseOffset: 0, extentOffset: 3);
        await tester.tap(find.byIcon(icon));
        await tester.pump();
        expect(editor.htmlController.text, '$open' 'abc' '$close');
      }

      await wrapSelection(Icons.format_bold, '<strong>', '</strong>');
      await wrapSelection(Icons.format_italic, '<em>', '</em>');
      await wrapSelection(Icons.format_underlined, '<u>', '</u>');
      await wrapSelection(Icons.strikethrough_s, '<s>', '</s>');

      editor.htmlController.text = '';
      editor.htmlController.selection =
          const TextSelection.collapsed(offset: -1);

      Future<void> insert(IconData icon, String needle) async {
        await tester.tap(find.byIcon(icon));
        await tester.pump();
        expect(inserted.any((h) => h.contains(needle)), isTrue, reason: needle);
      }

      await insert(Icons.format_align_left, 'text-align: left');
      await insert(Icons.format_align_center, 'text-align: center');
      await insert(Icons.format_align_right, 'text-align: right');
      await insert(Icons.format_list_bulleted, '<ul>');
      await insert(Icons.format_list_numbered, '<ol>');
      await insert(Icons.crop_square, 'Rectangle');
      await insert(Icons.circle_outlined, 'Circle');
      await insert(Icons.horizontal_rule, '<hr');
      await insert(Icons.text_fields, 'Type your text here');

      editor.htmlController.text = 'abc';
      editor.htmlController.selection =
          const TextSelection(baseOffset: 0, extentOffset: 3);
      await tester.tap(find.byIcon(Icons.format_indent_increase));
      await tester.pump();
      expect(editor.htmlController.text, contains('margin-left: 2em'));

      await tester.tap(find.byTooltip('Font Color'));
      await _openDialog(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Chọn'),
      ));
      await _openDialog(tester);
      expect(editor.htmlController.text, contains('color: #2196f3'));

      await tester.tap(find.byIcon(Icons.content_cut));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      _clipboard = 'pasted text';
      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pump();
      expect(inserted, hasLength(10));
      expect(inserted.last, 'pasted text');
      _clipboard = null;

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      expect(pres.slides, isEmpty);

      await tester.tap(find.byIcon(Icons.redo));
      await tester.pump();
      expect(pres.slides, hasLength(1));
      await _settleTimers(tester);
    });

    testWidgets('insert tab adds slides and inserts dialog HTML',
        (tester) async {
      final pres = _newState();
      addTearDown(pres.dispose);
      await pres.ready;
      final inserted = <String>[];

      await _pumpRibbon(
        tester,
        RibbonToolbar(
          presentationState: pres,
          onInsertHtml: inserted.add,
          currentSlideIndex: 0,
        ),
      );

      await tester.tap(find.text('Insert'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('New Slide'));
      await tester.pump();
      expect(pres.slides, hasLength(1));
      expect(pres.slides.first.title, 'New Slide');

      await tester.tap(find.byTooltip('Text Box'));
      await tester.pump();
      expect(inserted.any((h) => h.contains('Type your text here')), isTrue);

      await tester.tap(find.byTooltip('Header'));
      await tester.pump();
      expect(inserted.any((h) => h.contains('<header')), isTrue);

      await tester.tap(find.byTooltip('Code'));
      await tester.pump();
      expect(inserted.any((h) => h.contains('<pre')), isTrue);

      await tester.tap(find.byTooltip('Table'));
      await _openDialog(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Chèn'),
      ));
      await _openDialog(tester);
      expect(inserted.any((h) => h.contains('<table')), isTrue);

      await tester.tap(find.byTooltip('SmartArt'));
      await _openDialog(tester);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Chèn'),
      ));
      await _openDialog(tester);
      expect(inserted.any((h) => h.contains('Start')), isTrue);

      await tester.tap(find.byTooltip('Symbol'));
      await _openDialog(tester);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('★'),
      ));
      await _openDialog(tester);
      expect(inserted.any((h) => h.contains('★')), isTrue);

      await tester.tap(find.byTooltip('WordArt'));
      await _openDialog(tester);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Chèn'),
      ));
      await _openDialog(tester);
      expect(inserted.any((h) => h.contains('WordArt Text')), isTrue);

      await tester.tap(find.byTooltip('Chart'));
      await _openDialog(tester);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Chèn'),
      ));
      await _openDialog(tester);
      expect(inserted.any((h) => h.contains('Item A')), isTrue);
      expect(pres.slides, hasLength(1));
      await _settleTimers(tester);
    });

    testWidgets('slideshow and view tabs fire their callbacks', (tester) async {
      final pres = _newState();
      addTearDown(pres.dispose);
      await pres.ready;
      var navigated = -1;
      var sorterOpened = false;
      var gridToggles = 0;
      var rulerToggles = 0;
      var fullscreenToggles = 0;
      var zoomDialogs = 0;
      var presented = 0;
      var fromCurrent = 0;
      var presenterViews = 0;

      await _pumpRibbon(
        tester,
        RibbonToolbar(
          presentationState: pres,
          canUndo: false,
          canRedo: false,
          onNavigateToTab: (tab) => navigated = tab,
          onOpenSlideSorter: () => sorterOpened = true,
          onToggleGrid: () => gridToggles++,
          onToggleRuler: () => rulerToggles++,
          onToggleFullscreen: () => fullscreenToggles++,
          onZoomDialog: () => zoomDialogs++,
          onPresent: () => presented++,
          onPresentFromCurrent: () => fromCurrent++,
          onPresenterView: () => presenterViews++,
          currentSlideIndex: 0,
        ),
      );

      await tester.tap(find.text('Slideshow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('From Beginning'));
      await tester.pump();
      await tester.tap(find.byTooltip('From Current'));
      await tester.pump();
      await tester.tap(find.byTooltip('Presenter View'));
      await tester.pump();
      expect(presented, 1);
      expect(fromCurrent, 1);
      expect(presenterViews, 1);

      await tester.tap(find.byTooltip('Set slide timings'));
      await _openDialog(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Apply'),
      ));
      await _openDialog(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(pres.autoAdvanceSeconds, 5);
      expect(pres.autoAdvance, isTrue);

      await tester.tap(find.text('View'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Normal editor view'));
      await tester.pump();
      expect(navigated, 0);

      await tester.tap(find.byTooltip('Slide sorter view'));
      await tester.pump();
      expect(sorterOpened, isTrue);

      await tester.tap(find.byTooltip('Toggle grid overlay'));
      await tester.pump();
      await tester.tap(find.byTooltip('Toggle ruler overlay'));
      await tester.pump();
      await tester.tap(find.byTooltip('Toggle fullscreen window'));
      await tester.pump();
      await tester.tap(find.byTooltip('Adjust zoom level'));
      await tester.pump();
      expect(gridToggles, 1);
      expect(rulerToggles, 1);
      expect(fullscreenToggles, 1);
      expect(zoomDialogs, 1);
      await _settleTimers(tester);
    });
  });
}
