// T05 (v2.0.1-beta.2) — end-to-end flows: diagram insert, boolean shape
// merge through the real EditorShell, and export retention.
//
// The diagram dialog test needs the Flutter binding (localization); the
// export-retention part only touches pure Dart engines.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/l10n/app_localizations.dart';
import 'package:archive/archive.dart';
import 'package:ghita_ppt_converter/models/drawn_shape.dart';
import 'package:ghita_ppt_converter/providers/presentation_state.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_shell.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/screens/widgets/diagram_dialog.dart';
import 'package:ghita_ppt_converter/services/mermaid_diagram_service.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('ghita_t05').path;
      }
      return null;
    });
  });

  group('DiagramDialog flow', () {
    testWidgets('flowchart: steps + accent produce the themed block',
        (tester) async {
      String? inserted;
      await tester.pumpWidget(_localizedApp(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                inserted = await showDialog<String>(
                  context: context,
                  builder: (_) => const DiagramDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Insert Diagram'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);

      // Fill the three default steps.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Thu thập yêu cầu');
      await tester.enterText(fields.at(1), 'Phân tích');
      await tester.enterText(fields.at(2), 'Triển khai');
      await tester.pump();

      // The structural preview mirrors numbering and accent.
      expect(find.text('1. Thu thập yêu cầu'), findsOneWidget);
      expect(find.text('3. Triển khai'), findsOneWidget);

      // Pick the purple accent, then insert.
      await tester.tap(find.byKey(const Key('accent-#8B5CF6')).last);
      await tester.pump();
      await tester.tap(find.text('Insert into slide'));
      await tester.pumpAndSettle();

      expect(inserted, isNotNull);
      expect(inserted!, contains('diagram-flowchart'));
      expect(inserted, contains('background: #8B5CF6'));
      expect(inserted, contains('1. Thu thập yêu cầu'));
      expect(inserted, contains('3. Triển khai'));
    });

    testWidgets('mindmap mode returns the mindmap block with topic',
        (tester) async {
      String? inserted;
      await tester.pumpWidget(_localizedApp(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                inserted = await showDialog<String>(
                  context: context,
                  builder: (_) => const DiagramDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mindmap').last);
      await tester.pump();

      await tester.enterText(
          find.byType(TextField).first, 'Kế hoạch 2026');
      await tester.enterText(find.byType(TextField).at(1), 'Ngân sách');
      await tester.enterText(find.byType(TextField).at(2), 'Nhân sự');
      await tester.pump();

      await tester.tap(find.text('Insert into slide'));
      await tester.pumpAndSettle();

      expect(inserted, isNotNull);
      expect(inserted!, contains('diagram-mindmap'));
      expect(inserted, contains('Kế hoạch 2026'));
      expect(inserted, contains('Ngân sách'));
    });
  });

  group('boolean merge through the real EditorShell', () {
    testWidgets('union of two selected shapes merges and undoes cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pres = PresentationState();
      addTearDown(pres.dispose);
      final editor = EditorState();
      addTearDown(editor.dispose);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PresentationState>.value(value: pres),
          ChangeNotifierProvider<EditorState>.value(value: editor),
        ],
        child: _localizedApp(const EditorShell()),
      ));
      await tester.pump(const Duration(seconds: 1));

      pres.addSlide(Slide(title: 'Shapes', htmlContent: '<p>shapes</p>'));
      const a = DrawnShape(
          id: 'sh_a', type: ShapeType.rect, x: 0, y: 0, w: 20, h: 20);
      const b = DrawnShape(
          id: 'sh_b', type: ShapeType.rect, x: 5, y: 5, w: 20, h: 20);
      pres.upsertShape(a);
      pres.upsertShape(b);
      await tester.pump();

      // Open the advanced-tools row, then scroll the horizontal toolbar
      // until the merge button is on screen before tapping it.
      await tester.tap(find.text('More tools'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Merge shapes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Merge shapes'));
      await tester.pumpAndSettle();

      // Four boolean operations are offered.
      expect(find.text('Union'), findsOneWidget);
      expect(find.text('Subtract'), findsOneWidget);
      expect(find.text('Intersect'), findsOneWidget);

      await tester.tap(find.text('Union'));
      await tester.pumpAndSettle();

      final shapes = pres
          .slides[pres.currentSlideIndex].visualElements['shapes'] as List;
      expect(shapes, hasLength(1));
      expect((shapes.single as Map)['mergeOp'], 'union');

      // Undo through the time machine restores both source shapes.
      pres.undo();
      expect(
        pres.slides[pres.currentSlideIndex].visualElements['shapes'],
        hasLength(2),
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('merge is refused with a hint when fewer than two shapes',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pres = PresentationState();
      addTearDown(pres.dispose);
      final editor = EditorState();
      addTearDown(editor.dispose);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PresentationState>.value(value: pres),
          ChangeNotifierProvider<EditorState>.value(value: editor),
        ],
        child: _localizedApp(const EditorShell()),
      ));
      await tester.pump(const Duration(seconds: 1));

      pres.addSlide(Slide(title: 'Solo', htmlContent: '<p>one shape</p>'));
      pres.upsertShape(const DrawnShape(
          id: 'only', type: ShapeType.rect, x: 0, y: 0, w: 10, h: 10));
      await tester.pump();

      await tester.tap(find.text('More tools'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Merge shapes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Merge shapes'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'no merge dialog with a single shape');
      expect(find.byType(SnackBar), findsOneWidget,
          reason: 'the need-two-shapes hint is surfaced');
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('export retention (pure Dart engines)', () {
    final diagramHtml = MermaidDiagramService()
        .generateFlowchartHtml(['Khảo sát', 'Thiết kế', 'Bàn giao'],
            accentColor: '#8B5CF6');
    final slides = [
      {'title': 'Quy trình', 'htmlContent': diagramHtml},
    ];

    test('PPTX export keeps the diagram step text', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_t05_pptx');
      try {
        await PPTGenerator.generatePPT(slides, '${dir.path}/out.pptx');
        final archive = ZipDecoder()
            .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
        final slideXml = utf8.decode(
          archive.files
              .firstWhere((f) => f.name == 'ppt/slides/slide1.xml')
              .content as List<int>,
          allowMalformed: true,
        );
        expect(slideXml, contains('Khảo sát'),
            reason: 'slide text carries the diagram steps');
        expect(slideXml, contains('Bàn giao'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('HTML export carries the diagram block verbatim', () {
      final html = HtmlExportService()
          .buildPresentationHtml(slides, imageMaxWidth: 1200);
      expect(html, contains('diagram-flowchart'));
      expect(html, contains('background: #8B5CF6'));
      expect(html, contains('2. Thiết kế'));
    });

    test('PDF export renders the diagram without losing content', () async {
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}t05_diagram.pdf';
      final out = await PdfExportService().exportToPdf(slides, path);
      expect(File(out).lengthSync(), greaterThan(2000));
      File(out).deleteSync();
    });
  });
}
