import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:ghita_ppt_converter/screens/widgets/status_bar.dart';

/// T15 (2026-09-02): the status bar must render the ACTIVE locale — the
/// export indicator and language badge used to be hard-coded Vietnamese even
/// in the English UI.
void main() {
  Widget host(String localeCode, {String? exportStatus}) => MaterialApp(
        locale: Locale(localeCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: StatusBar(
            currentSlide: 2,
            totalSlides: 5,
            zoomLevel: 1.0,
            onZoomChanged: (_) {},
            language: localeCode == 'vi' ? 'Tiếng Việt' : 'English',
            autoSaveStatus: exportStatus ?? 'saved',
            wordCount: 3,
            deckSizeBytes: null,
          ),
        ),
      );

  testWidgets('T15: EN status bar shows English export wording', (tester) async {
    await tester.pumpWidget(host('en', exportStatus: 'exporting'));
    expect(find.text('Exporting...'), findsOneWidget,
        reason: 'T15: the N3 export indicator must follow the locale');
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Đang xuất...'), findsNothing);
    expect(find.text('Slide 2 / 5'), findsOneWidget);
  });

  testWidgets('T15: VI status bar shows Vietnamese export wording',
      (tester) async {
    await tester.pumpWidget(host('vi', exportStatus: 'exporting'));
    expect(find.text('Đang xuất...'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget,
        reason: 'the language badge must use the passed language name');
  });

  testWidgets('T15: status bar has a localized Semantics label',
      (tester) async {
    await tester.pumpWidget(host('en', exportStatus: 'saved'));
    expect(
      find.bySemanticsLabel(RegExp('slide 2 of 5')),
      findsOneWidget,
      reason: 'T15: screen readers must get the localized status',
    );
  });
}
