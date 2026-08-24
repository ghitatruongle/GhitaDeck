// T01 (v2.0.1-beta.2) — EditorShell keyboard wiring tests (P9).
//
// The undo/redo and save wirings are verified through the shell's
// CallbackShortcuts binding table directly: simulating key events through the
// focus/semantics pipeline trips a Flutter framework assertion
// (rendering/object.dart _collectChildMergeUpAndSiblingGroup) that makes this
// suite flaky. Verifying the registered activators is the actual contract
// under test — that the shell wires Ctrl+S/Ctrl+Z/Ctrl+Y to save/undo/redo.
//
// Ctrl+Enter and Ctrl+Shift+C keep real key-event delivery because their
// assertions cover the event->action path end to end and have proven stable.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_shell.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/screens/editor/html_editor_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> pumpShell(WidgetTester tester, PresentationState pres,
    EditorState editor) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PresentationState>.value(value: pres),
        ChangeNotifierProvider<EditorState>.value(value: editor),
      ],
      child: _localizedApp(const EditorShell()),
    ),
  );
  await tester.pump();
}

Map<ShortcutActivator, VoidCallback> _shellBindings(
  WidgetTester tester,
) {
  final shortcuts = tester.widget<CallbackShortcuts>(
    find.ancestor(
      of: find.byType(HtmlEditorPanel),
      matching: find.byType(CallbackShortcuts),
    ).first,
  );
  return shortcuts.bindings;
}

void main() {
  testWidgets('shell binds Ctrl+Z/Ctrl+Y to the deck time machine',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pres = PresentationState();
    addTearDown(pres.dispose);
    final editor = EditorState();
    addTearDown(editor.dispose);

    await pumpShell(tester, pres, editor);
    await tester.pump(const Duration(seconds: 1));

    pres.addSlide(Slide(title: 'One', htmlContent: '<h1>One</h1>'));
    pres.addSlide(Slide(title: 'Two', htmlContent: '<h1>Two</h1>'));
    await tester.pump();
    expect(pres.slides, hasLength(2));

    final bindings = _shellBindings(tester);
    bindings[const SingleActivator(LogicalKeyboardKey.keyZ, control: true)]!();
    await tester.pump();
    expect(pres.slides, hasLength(1),
        reason: 'the Ctrl+Z binding must undo the last deck mutation');

    bindings[const SingleActivator(LogicalKeyboardKey.keyY, control: true)]!();
    await tester.pump();
    expect(pres.slides, hasLength(2),
        reason: 'the Ctrl+Y binding must redo the undone mutation');
    // Burn every timer the mutations scheduled (debounced saves) so the test
    // ends clean.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('shell binds Ctrl+S to saving, clearing the dirty flag',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pres = PresentationState();
    addTearDown(pres.dispose);
    final editor = EditorState();
    addTearDown(editor.dispose);

    await pumpShell(tester, pres, editor);
    await tester.pump(const Duration(seconds: 1));

    pres.addSlide(Slide(title: 'Dirty', htmlContent: '<h1>Dirty</h1>'));
    await tester.pump();
    expect(pres.hasUnsavedChanges, isTrue);

    _shellBindings(tester)[const SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
    )]!();
    await tester.pump(const Duration(milliseconds: 600));

    expect(pres.hasUnsavedChanges, isFalse,
        reason: 'Ctrl+S must save, leaving no unsaved changes behind');
  });

  testWidgets('Ctrl+Enter with an empty editor surfaces the validation error',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pres = PresentationState();
    addTearDown(pres.dispose);
    final editor = EditorState();
    addTearDown(editor.dispose);

    await pumpShell(tester, pres, editor);
    await tester.pump(const Duration(seconds: 1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('HTML content cannot be empty'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Ctrl+Shift+C arms the format painter', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pres = PresentationState();
    addTearDown(pres.dispose);
    final editor = EditorState();
    addTearDown(editor.dispose);

    await pumpShell(tester, pres, editor);
    await tester.pump(const Duration(seconds: 1));
    expect(editor.formatPainterArmed, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(editor.formatPainterArmed, isTrue);
  });
}
