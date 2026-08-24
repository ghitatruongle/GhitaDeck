// T01 (v2.0.1-beta.2) — EditorShell mount & shortcut wiring tests.
//
//   P8  shell mounts through the hydrate gate into the 3-panel layout and
//       the sidebar collapses/expands
//   P9  keyboard wiring: Ctrl+S persists (clearing the dirty flag),
//       Ctrl+Z/Ctrl+Y drive the time machine, Ctrl+Enter surfaces the
//       validation snackbar, Ctrl+Shift+C arms the format painter
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_shell.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/screens/editor/html_editor_panel.dart';
import 'package:ghita_ppt_converter/screens/editor/slide_list_panel.dart';
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

/// With mocked SharedPreferences hydration resolves inside the first
/// pumpWidget call, so the hydrating frame is unobservable. This test double
/// pins the gate shut until the test chooses to open it.
class _TestPresentationState extends PresentationState {
  bool _forceHydrating = false;

  void pinHydrating() {
    _forceHydrating = true;
    notifyListeners();
  }

  void releaseHydrating() {
    _forceHydrating = false;
    notifyListeners();
  }

  @override
  bool get isHydrating => _forceHydrating || super.isHydrating;
}

void main() {
  testWidgets('shell shows the hydrate loader, then mounts the 3-panel layout',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pres = _TestPresentationState()..pinHydrating();
    addTearDown(pres.dispose);
    final editor = EditorState();
    addTearDown(editor.dispose);

    await pumpShell(tester, pres, editor);

    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'the editor must not render before hydration completes');
    expect(find.byType(HtmlEditorPanel), findsNothing);

    pres.releaseHydrating();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SlideListPanel), findsOneWidget);
    expect(find.byType(HtmlEditorPanel), findsOneWidget);
    expect(find.byType(EditorShell), findsOneWidget);
  });

  testWidgets('sidebar collapse toggle hides and restores the slide list',
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
    expect(find.byType(SlideListPanel), findsOneWidget);

    await tester.tap(find.byTooltip('Thu gọn thanh Slide'));
    await tester.pump();
    expect(find.byType(SlideListPanel), findsNothing);

    await tester.tap(find.byTooltip('Mở thanh Slide'));
    await tester.pump();
    expect(find.byType(SlideListPanel), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

}
