// Regression (F1, 2026-09-01): the delete-with-undo snackbar MUST auto-dismiss
// after its display duration — a lingering white bar is a showstopper for the
// user ("mãi không tự tắt"). This drives the REAL _deleteSlideWithUndo flow
// through the REAL EditorShell instead of calling the helper in isolation.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_shell.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/screens/editor/slide_list_panel.dart';
import 'package:ghita_ppt_converter/utils/snackbar_helper.dart';
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

/// Pins the hydration gate shut until the test releases it, so the deck loaded
/// while hydration resolved is not wiped by the read (same trick as
/// editor_shell_mount_test.dart).
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
  testWidgets('control: raw showSnackBar auto-dismisses after default 4 s',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('rawbar')),
              ),
              child: const Text('raw'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('raw'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('rawbar'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('rawbar'), findsNothing);
  });

  testWidgets('helper without action: auto-dismisses after duration',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAppSnackBar(context, 'plainbar'),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('plainbar'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('plainbar'), findsNothing);
  });

  testWidgets('plain app: action snackbar auto-dismisses after duration',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAppSnackBar(
                context,
                'deleted',
                actionLabel: 'Undo',
                onAction: () {},
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('deleted'), findsNothing);
  });

  testWidgets('delete snackbar auto-dismisses: never lingers past 4 s',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pres = _TestPresentationState()..pinHydrating();
    addTearDown(pres.dispose);
    await pres.ready; // hydration finished on the empty mock store
    pres.addSlide(Slide(title: 'New Slide', htmlContent: '<h1>New Slide</h1>'));
    pres.addSlide(Slide(title: 'Second', htmlContent: '<h1>Second</h1>'));

    final editor = EditorState();
    addTearDown(editor.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PresentationState>.value(value: pres),
          ChangeNotifierProvider<EditorState>.value(value: editor),
        ],
        child: _localizedApp(const EditorShell()),
      ),
    );
    pres.releaseHydrating();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SlideListPanel), findsOneWidget);

    // Select slide 1, then delete via the footer button (same _deleteSlideWithUndo).
    editor.selectSlide(0);
    await tester.pump();
    final footerDelete = find.descendant(
      of: find.byType(SlideListPanel),
      matching: find.byTooltip('Delete'),
    );
    expect(footerDelete, findsOneWidget);
    await tester.tap(footerDelete, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Deleted "New Slide"'), findsOneWidget,
        reason: 'delete snackbar should be visible right after the action');
    expect(pres.slides.length, 1,
        reason: 'one slide removed, the other still present');

    // Wait well past the 3 s display window (+ exit animation). The
    // messenger arms its dismiss timer when it rebuilds after the entrance
    // animation completes, so give coarse test pumps some slack.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Deleted "New Slide"'), findsNothing,
        reason: 'F1: the delete snackbar must auto-dismiss, never linger');
  });
}
