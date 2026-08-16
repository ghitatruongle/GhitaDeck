import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/main.dart';
import 'package:ghita_ppt_converter/screens/widgets/collaboration_panel.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('release flow reaches collaboration and advanced export',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('More tools'), findsOneWidget);
    expect(find.text('Insert chart'), findsNothing);
    await tester.tap(find.text('More tools'));
    await tester.pumpAndSettle();
    expect(find.text('Collapse tools'), findsOneWidget);
    expect(find.text('Insert chart'), findsOneWidget);
    await tester.tap(find.text('Collapse tools'));
    await tester.pumpAndSettle();

    expect(find.text('Collaboration'), findsOneWidget);
    await tester.tap(find.text('Collaboration'));
    await tester.pumpAndSettle();
    expect(find.byType(CollaborationPanel), findsOneWidget);
    expect(find.text('Start collaboration'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Export'), findsOneWidget);
  });
}
