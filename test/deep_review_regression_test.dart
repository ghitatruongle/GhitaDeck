import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/providers/config_service.dart';
import 'package:ghita_ppt_converter/services/advanced_import_service.dart';
import 'package:ghita_ppt_converter/services/ai_pipeline_service.dart';
import 'package:ghita_ppt_converter/services/search_service.dart';
import 'package:ghita_ppt_converter/services/spellcheck_service.dart';
import 'package:ghita_ppt_converter/services/wysiwyg_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deep review regression — AI pipeline', () {
    test('repairJsonArray drops a trailing comma before closing', () {
      final repaired =
          AIPipelineService.repairJsonArray('[{ "a": 1 }, { "b": 2 },');
      final decoded = jsonDecode(repaired) as List;
      expect(decoded.length, 2);
      expect(decoded[1]['b'], 2);
    });

    test('repairJsonArray closes unclosed objects with } not ]', () {
      final repaired = AIPipelineService.repairJsonArray(
          '[{ "k": { "n": [1, 2], "m": "x" } }, { "y": 1');
      final decoded = jsonDecode(repaired) as List;
      expect(decoded.length, 2);
      expect(decoded[1]['y'], 1);
    });

    test('repairJsonArray survives empty / fence-wrapped / chatter input', () {
      expect(AIPipelineService.repairJsonArray(''), '[]');
      final fenced = AIPipelineService.repairJsonArray('```json\n[1, 2]\n```');
      expect(jsonDecode(fenced), [1, 2]);
      final chatter = AIPipelineService.repairJsonArray('Here you go: [1, 2, 3]');
      expect(jsonDecode(chatter), [1, 2, 3]);
    });
  });

  group('Deep review regression — advanced import', () {
    test('table pipe inside inline code is not a column separator', () {
      const md = '# T\n\n| A | B |\n| --- | --- |\n| `x|y` | z |';
      final html = AdvancedImportService.parseMarkdown(md).first.htmlContent;
      expect(html, contains('<table>'));
      expect(html, contains('`x|y`'), reason: 'cell content must survive whole');
      expect(html, contains('<td>`x|y`</td>'));
    });

    test('code-fence `---` does not split slides', () {
      const md = '# Slide 1\n\n```\n---\nnot a split\n```\n\n# Slide 2';
      final slides = AdvancedImportService.parseMarkdown(md);
      expect(slides.length, 2);
      expect(slides[0].htmlContent, contains('not a split'));
    });
  });

  group('Deep review regression — spellcheck', () {
    test('HTML entities do not tokenize as words', () {
      final errors = SpellcheckService.checkText('caf&eacute; &amp; more');
      expect(errors.where((i) => i.word == 'eacute').length, 0);
      expect(errors.where((i) => i.word == 'amp').length, 0);
    });
  });

  group('Deep review regression — search', () {
    test('replaceAll never touches attribute values', () {
      final slides = [
        {
          'title': 'D',
          'htmlContent':
              '<div class="color-red" data-note="red"><p>the red fox</p></div>',
        }
      ];
      final result = SearchService.replaceAll(slides, 'red', 'blue');
      expect(result.count, 1);
      final html = result.slides[0]['htmlContent'] as String;
      expect(html, contains('class="color-red"'));
      expect(html, contains('the blue fox'));
    });
  });

  group('Deep review regression — wysiwyg', () {
    test('wrapSelection wraps the exact selected text', () {
      final r = WysiwygService.wrapSelection('<p>ab</p>', 3, 5, '<i>', '</i>');
      expect(r.html, '<p><i>ab</i></p>');
    });

    test('colorSelection keeps tags intact', () {
      final r = WysiwygService.colorSelection('<p><b>x</b>y</p>', 3, 12, 'ff0000');
      expect(r.html, contains('<span style="color:ff0000">'));
      expect(r.html, contains('<b>'));
    });
  });

  group('Deep review regression — ConfigService large-deck spill (T65 OPT 27)', () {
    late ConfigService service;
    late Directory tempDir;

    setUp(() async {
      service = ConfigService();
      tempDir = Directory.systemTemp.createTempSync('ghita_spill_test');
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('large deck spills to file; small deck stays inline', () async {
      final small = [
        for (var i = 0; i < 5; i++)
          {'title': 'S$i', 'htmlContent': '<p>small $i</p>'}
      ];
      await service.saveSlides(small, 'fade');
      final loadedSmall = await service.loadSlides();
      expect((loadedSmall['slides'] as List).length, 5);

      // ~200 KB of text per slide → 10 slides cross the 1 MB threshold.
      final big = [
        for (var i = 0; i < 10; i++)
          {
            'title': 'B$i',
            'htmlContent': '<p>${'x' * 200000}</p>',
          }
      ];
      await service.saveSlides(big, 'fade');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('presentation_slides_config'), isNull,
          reason: 'inline key must be dropped for large decks');
      expect(prefs.getString('presentation_slides_file_pointer'), isNotNull);

      final loaded = await service.loadSlides();
      final slides = loaded['slides'] as List;
      expect(slides.length, 10);
      expect((slides.first as Map)['title'], 'B0');
      expect((slides.last as Map)['title'], 'B9');
    });
  });
}
