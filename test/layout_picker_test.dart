import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide_layout.dart';
import 'package:ghita_ppt_converter/screens/widgets/layout_picker.dart';

/// Layout picker widget coverage: grid rendering (which draws every mini
/// layout through the shared painter), dialog flow and popup-menu flow.
void main() {
  testWidgets('grid renders every layout and tapping selects + closes',
      (tester) async {
    SlideLayoutType? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LayoutPicker(
          onLayoutSelected: (t) => selected = t,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Choose Layout'), findsOneWidget);
    expect(
      find.byType(InkWell),
      findsNWidgets(SlideLayout.layouts.length),
      reason: 'every layout must appear in the grid',
    );

    await tester.tap(find.text('Title Slide'));
    await tester.pumpAndSettle();
    // No Navigator above (plain pump) — the callback is the contract.
    expect(selected, SlideLayoutType.titleSlide);
  });

  testWidgets('showAsDialog closes with the selection', (tester) async {
    SlideLayoutType? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => LayoutPicker.showAsDialog(
                context,
                (t) => selected = t,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Layout'), findsOneWidget);

    await tester.tap(find.text('Title and Content'));
    await tester.pumpAndSettle();
    expect(selected, SlideLayoutType.titleAndContent);
    expect(find.byType(Dialog), findsNothing, reason: 'dialog must close');
  });

  testWidgets('popup menu (show) fires the callback', (tester) async {
    SlideLayoutType? selected;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: key,
              onPressed: () {
                final box = key.currentContext!.findRenderObject()! as RenderBox;
                LayoutPicker.show(context, box.localToGlobal(Offset.zero),
                    (t) => selected = t);
              },
              child: const Text('menu'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('menu'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<SlideLayoutType>),
        findsNWidgets(SlideLayout.layouts.length));

    await tester.tap(find.text('Blank').first);
    await tester.pumpAndSettle();
    expect(selected, SlideLayoutType.blank);
  });
}
