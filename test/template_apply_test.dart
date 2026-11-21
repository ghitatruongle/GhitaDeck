import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/l10n/app_localizations.dart';
import 'package:ghita_deck/models/slide_template.dart';
import 'package:ghita_deck/screens/template_studio_screen.dart';

const String _mockTemplateManifest = '['
    '{"id":"business","name":"Business","description":"Corporate template",'
    '"htmlFile":"mock_template.html","recommendedEffect":"none",'
    '"iconCodePoint":null,"accentColor":4282534075,"category":"Corporate"}'
    ']';

const String _mockTemplateHtml = '<h1>Business Overview</h1><p>Content</p>';

void main() {
  testWidgets('card apply button invokes onApplyTemplate', (tester) async {
    SlideTemplate? applied;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TemplateStudioScreen(onApplyTemplate: (t) => applied = t),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sử dụng'), findsWidgets);
    await tester.tap(find.text('Sử dụng').first);
    await tester.pump();

    expect(applied, isNotNull);
    expect(applied!.id, isNotEmpty);
  });

  testWidgets('without a callback nothing is applied and no success snackbar shows',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!
            .buffer
            .asUint8List(message.offsetInBytes, message.lengthInBytes));
        final String content;
        if (key.endsWith('templates.json')) {
          content = _mockTemplateManifest;
        } else if (key.endsWith('.html')) {
          content = _mockTemplateHtml;
        } else {
          content = '';
        }
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
      },
    );
    rootBundle.evict('assets/templates/templates.json');
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TemplateStudioScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sử dụng').first);
    await tester.pump();

    expect(find.textContaining('Applied template'), findsNothing);
  });
}
