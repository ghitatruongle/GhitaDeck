import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('core editor controls expose actionable accessibility semantics',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'GhitaPPT presentation workspace')),
      findsOneWidget,
    );
    // T15: the sidebar tooltip no longer claims a Ctrl+1 binding that does
    // not exist — the semantics label is the localized section name.
    final editor = find.bySemanticsLabel(RegExp(r'^Editor$'));
    expect(editor, findsOneWidget);
    final editorNode = tester.getSemantics(editor);
    expect(editorNode.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
        editorNode.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final slideList = find.bySemanticsLabel(RegExp(r'Slide list, \d+ slides'));
    expect(slideList, findsAtLeastNWidgets(1));

    final save = find.bySemanticsLabel('Save (Ctrl+S)');
    expect(save, findsOneWidget);
    final saveNode = tester.getSemantics(save);
    expect(saveNode.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(saveNode.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });
}
