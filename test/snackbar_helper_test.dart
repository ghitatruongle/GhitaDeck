import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/utils/snackbar_helper.dart';

/// F1 feedback (2026-08-31): snackbars must REPLACE each other instead of
/// queueing — rapid actions previously piled up 4 s per snackbar and the final
/// one looked like it never auto-dismissed.
void main() {
  testWidgets('showAppSnackBar replaces the current snackbar (no queue)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAppSnackBar(context, 'first'),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));

    final context = tester.element(find.byType(TextButton));
    showAppSnackBar(context, 'first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    showAppSnackBar(context, 'second');
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing,
        reason: 'the previous snackbar must be replaced, not queued');

    // Rapid-fire: a third call while the second is still visible only shows
    // the latest one — no pile-up (F1: "mãi không tự tắt").
    showAppSnackBar(context, 'third');
    await tester.pump();
    expect(find.text('third'), findsOneWidget);
    expect(find.text('second'), findsNothing);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('showAppSnackBar shows an action when provided',
      (tester) async {
    var undone = false;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: key,
              onPressed: () => showAppSnackBar(
                context,
                'deleted',
                actionLabel: 'Undo',
                onAction: () => undone = true,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.text('deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(undone, isTrue);
  });
}
