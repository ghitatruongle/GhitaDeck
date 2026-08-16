import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/screens/editor/html_editor_panel.dart';
import 'package:ghita_ppt_converter/screens/widgets/ribbon_toolbar.dart';
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

void main() {
  testWidgets('editor action bar does not expose the broken deck preview path',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final presentation = PresentationState()
      ..addSlide(Slide(
        title: 'Regression slide',
        htmlContent: '<h1>Rendered content</h1>',
      ));
    final editor = EditorState();
    addTearDown(editor.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: presentation),
          ChangeNotifierProvider.value(value: editor),
        ],
        child: _localizedApp(const HtmlEditorPanel()),
      ),
    );
    await tester.pump();

    expect(find.text('Add Slide'), findsOneWidget);
    expect(find.text('Present'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('slideshow ribbon exposes each presentation mode once',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(
        RibbonToolbar(
          onPresent: () {},
          onPresentFromCurrent: () {},
          onPresenterView: () {},
        ),
      ),
    );
    await tester.tap(find.text('Trình chiếu'));
    await tester.pumpAndSettle();

    expect(find.text('From Beginning'), findsOneWidget);
    expect(find.text('From Current'), findsOneWidget);
    expect(find.text('Presenter View'), findsOneWidget);
    expect(find.text('Rehearse'), findsNothing);
    expect(find.text('Reading View'), findsNothing);
  });
}
