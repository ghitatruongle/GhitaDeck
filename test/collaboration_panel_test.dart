import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/main.dart';
import 'package:ghita_ppt_converter/screens/widgets/collaboration_panel.dart';
import 'package:ghita_ppt_converter/services/collaboration_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('editor exposes the collaboration panel in the real app tree',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Collaboration'), findsOneWidget);
    // Track 12: the toolbar scrolls horizontally now (more insert buttons);
    // bring the collaboration button into view before tapping.
    await tester.ensureVisible(find.text('Collaboration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collaboration'));
    await tester.pumpAndSettle();
    expect(find.byType(CollaborationPanel), findsOneWidget);
    expect(find.text('Start collaboration'), findsOneWidget);
  });

  testWidgets('collaboration panel is reachable and localized in Vietnamese',
      (tester) async {
    final service = CollaborationService()
      ..bindDocument(readSlides: () => [], applySlides: (_) {});
    addTearDown(service.dispose);

    await tester.pumpWidget(
      Provider<CollaborationService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const CollaborationPanel(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('C\u1ed9ng T\u00e1c'), findsOneWidget);
    expect(find.text('B\u1eaft \u0111\u1ea7u c\u1ed9ng t\u00e1c'), findsOneWidget);
    expect(find.text('M\u00e3 b\u1ea3o m\u1eadt phi\u00ean'), findsOneWidget);
    expect(
      find.textContaining('Ch\u1ec9 chia s\u1ebb li\u00ean k\u1ebft'),
      findsOneWidget,
    );
  });
}
