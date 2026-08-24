// T03 (v2.0.1-beta.2) — SmartDraftManager tests (phases 3–4).
//
// The manager persists drafts under <documents>/GhitaPPT/drafts, so the tests
// point path_provider at a throwaway temp dir. Crash recovery is exercised by
// loading through a fresh manager instance — the class is stateless on
// purpose, everything lives in the files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/smart_draft_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ghita_draft_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Slide slide(String title) =>
      Slide(title: title, htmlContent: '<h1>$title</h1>');

  group('save / detect / load round-trip', () {
    test('a fresh sandbox has no recoverable draft', () async {
      final manager = SmartDraftManager();
      expect(await manager.hasRecoverableDraft(), isFalse);
      expect(await manager.loadRecoverableDraft(), isNull);
    });

    test('saved draft round-trips slides and metadata', () async {
      final manager = SmartDraftManager();
      await manager.saveDraft(
        [slide('Alpha'), slide('Beta')],
        metadata: {'aspectRatio': '16:9'},
      );

      expect(await manager.hasRecoverableDraft(), isTrue);

      final draft = await manager.loadRecoverableDraft();
      expect(draft, isNotNull);
      final titles =
          (draft!['slides'] as List).map((s) => s['title']).toList();
      expect(titles, ['Alpha', 'Beta']);
      expect(draft['metadata']['aspectRatio'], '16:9');
      expect(draft['version'], isNotEmpty,
          reason: 'the draft records the app version that wrote it');
    });

    test('an empty deck does not count as a recoverable draft', () async {
      final manager = SmartDraftManager();
      await manager.saveDraft(const []);
      expect(await manager.hasRecoverableDraft(), isFalse);
    });

    test('recovery works through a brand-new manager instance', () async {
      // Simulates a crash + restart: nothing is carried in memory.
      await SmartDraftManager().saveDraft([slide('Survived crash')]);

      final recovered = await SmartDraftManager().loadRecoverableDraft();
      expect(recovered, isNotNull);
      expect((recovered!['slides'] as List).single['title'], 'Survived crash');
    });
  });

  group('large-deck spill format', () {
    test('decks over 1 MB spill to a pointer file and still reload fully',
        () async {
      final bigSlide = Slide(title: 'Big', htmlContent: 'x' * 1100000);
      final manager = SmartDraftManager();
      await manager.saveDraft([bigSlide]);

      final draftFile = File(
          '${tempDir.path}${Platform.pathSeparator}GhitaPPT'
          '${Platform.pathSeparator}drafts${Platform.pathSeparator}'
          'ghita_ppt_unsaved_draft.json');
      final pointer = jsonDecode(draftFile.readAsStringSync())
          as Map<String, dynamic>;
      expect(pointer.containsKey('slidesFile'), isTrue,
          reason: 'large decks keep only a pointer inline');
      expect(pointer['slidesFile'], 'ghita_ppt_unsaved_draft.slides.json');
      expect(pointer['slideCount'], 1);

      expect(await manager.hasRecoverableDraft(), isTrue);
      final draft = await manager.loadRecoverableDraft();
      expect((draft!['slides'] as List).single['title'], 'Big');
    });

    test('a later small save removes the stale spill file', () async {
      final manager = SmartDraftManager();
      final draftsDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}GhitaPPT'
          '${Platform.pathSeparator}drafts');
      final spillFile = File('${draftsDir.path}'
          '${Platform.pathSeparator}ghita_ppt_unsaved_draft.slides.json');

      await manager.saveDraft([Slide(title: 'Big', htmlContent: 'x' * 1100000)]);
      expect(spillFile.existsSync(), isTrue);

      await manager.saveDraft([slide('Small now')]);
      expect(spillFile.existsSync(), isFalse,
          reason: 'stale spill must not linger next to an inline draft');
      expect((await manager.loadRecoverableDraft())!['slides'] as List,
          hasLength(1));
    });

    test('a missing spill file degrades to an empty draft list', () async {
      final manager = SmartDraftManager();
      await manager.saveDraft([Slide(title: 'Big', htmlContent: 'x' * 1100000)]);

      final spillFile = File(
          '${tempDir.path}${Platform.pathSeparator}GhitaPPT'
          '${Platform.pathSeparator}drafts${Platform.pathSeparator}'
          'ghita_ppt_unsaved_draft.slides.json');
      spillFile.deleteSync();

      expect(await manager.hasRecoverableDraft(), isFalse);
      final draft = await manager.loadRecoverableDraft();
      expect(draft!['slides'] as List, isEmpty);
    });
  });

  group('purge and corruption', () {
    test('purgeDraft removes both the pointer and the spill file', () async {
      final manager = SmartDraftManager();
      final draftsDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}GhitaPPT'
          '${Platform.pathSeparator}drafts');

      await manager.saveDraft([Slide(title: 'Big', htmlContent: 'x' * 1100000)]);
      expect(draftsDir.listSync().length, 2);

      await manager.purgeDraft();
      expect(draftsDir.listSync(), isEmpty);
      expect(await manager.hasRecoverableDraft(), isFalse);
    });

    test('corrupt draft JSON degrades gracefully instead of crashing',
        () async {
      final manager = SmartDraftManager();
      await manager.saveDraft([slide('Whatever')]);
      // Overwrite with garbage, simulating a torn write during a crash.
      final draftFile = File(
          '${tempDir.path}${Platform.pathSeparator}GhitaPPT'
          '${Platform.pathSeparator}drafts${Platform.pathSeparator}'
          'ghita_ppt_unsaved_draft.json');
      draftFile.writeAsStringSync('{not json at all');

      expect(await manager.hasRecoverableDraft(), isFalse);
      expect(await manager.loadRecoverableDraft(), isNull);
    });
  });
}
