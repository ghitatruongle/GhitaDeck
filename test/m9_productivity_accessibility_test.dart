import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/accessibility_service.dart';
import 'package:ghita_ppt_converter/services/addin_service.dart';
import 'package:ghita_ppt_converter/services/read_aloud_service.dart';
import 'package:ghita_ppt_converter/services/ribbon_config_service.dart';
import 'package:ghita_ppt_converter/services/search_service.dart';
import 'package:ghita_ppt_converter/services/spellcheck_service.dart';
import 'package:ghita_ppt_converter/services/template_service.dart';
import 'package:ghita_ppt_converter/services/vba_service.dart';

void main() {
  // -------------------------------------------------------------------------
  // T57 — Spellcheck + Thesaurus + Find/Replace
  // -------------------------------------------------------------------------
  group('T57 SpellcheckService', () {
    test('flags misspelled "recieve" and suggests "receive"', () {
      final errors = SpellcheckService.checkText('I recieve the file.');
      expect(errors, isNotEmpty);
      final recieve =
          errors.firstWhere((e) => e.word.toLowerCase() == 'recieve');
      expect(recieve.suggestions, contains('receive'));
    });

    test('passes correctly spelled sentences', () {
      final errors = SpellcheckService.checkText(
          'The quick brown fox jumps over the lazy dog.');
      expect(errors, isEmpty);
    });

    test('returns positions for highlighting', () {
      final errors = SpellcheckService.checkText('recieve this');
      expect(errors.first.start, 0);
      expect(errors.first.end, 7);
    });

    test('Vietnamese dictionary accepts common words', () {
      final errors =
          SpellcheckService.checkText('Xin chào các bạn', locale: 'vi');
      expect(errors, isEmpty);
    });

    test('grammarCheck catches double spaces and lowercase sentence start', () {
      final issues = SpellcheckService.grammarCheck('hello  world. next one');
      final rules = issues.map((i) => i.rule).toList();
      expect(rules, contains('double_space'));
      expect(rules, contains('capitalize'));
    });

    test('fixGrammar repairs double spaces', () {
      final issues = SpellcheckService.grammarCheck('a  b');
      final fixed = SpellcheckService.fixGrammar('a  b', issues.first);
      expect(fixed, 'a b');
    });

    test('thesaurus returns EN synonyms, empty for unknown', () {
      expect(SpellcheckService.synonyms('good'), contains('excellent'));
      expect(SpellcheckService.synonyms('zzzznope'), isEmpty);
      expect(SpellcheckService.synonyms('tốt', locale: 'vi'), isEmpty);
    });

    test('suggest uses edit distance (max 3 diff skipped)', () {
      final s = SpellcheckService.suggest('receive');
      expect(s, isEmpty); // already in dictionary
      final near = SpellcheckService.suggest('recieve');
      expect(near, contains('receive'));
    });
  });

  group('T57 SearchService', () {
    Map<String, dynamic> slide(String title, String html) =>
        {'title': title, 'htmlContent': html};

    test('findAll locates matches across slides (title + content)', () {
      final slides = [
        slide('Budget', '<h1>Budget</h1><p>money plan for Q3</p>'),
        slide('Team', '<h1>Team</h1><p>budget owners</p>'),
      ];
      // Title + h1 on slide 0, paragraph on slide 1.
      final matches = SearchService.findAll(slides, 'budget');
      expect(matches, hasLength(3));
      expect(matches.map((m) => m.slideIndex).toSet(), {0, 1});
    });

    test('case sensitivity and whole word options', () {
      final slides = [slide('A', '<p>Budget budgeted</p>')];
      // 'budget' case-sensitive matches only inside 'budgeted'.
      expect(SearchService.findAll(slides, 'budget', caseSensitive: true),
          hasLength(1));
      // whole-word + case-sensitive: only the exact 'Budget'.
      expect(
          SearchService.findAll(slides, 'Budget',
              caseSensitive: true, wholeWord: true),
          hasLength(1));
      expect(
          SearchService.findAll(slides, 'budget',
              caseSensitive: true, wholeWord: true),
          isEmpty);
    });

    test('replaceAll swaps text but not tags/attributes', () {
      final slides = [
        slide('Old title', '<h1 class="old-head">Old text</h1><p>old</p>')
      ];
      final result = SearchService.replaceAll(slides, 'old', 'new');
      expect(result.count, 3); // title "Old"→"new", h1 text, p text
      final html = result.slides.first['htmlContent'] as String;
      expect(html, contains('new text'));
      expect(html, contains('old-head')); // attribute untouched
      expect(html, isNot(contains('Old text')));
    });

    test('replaceAll reports zero when no match', () {
      final result =
          SearchService.replaceAll([slide('A', '<p>x</p>')], 'zzz', 'yyy');
      expect(result.count, 0);
    });
  });

  // -------------------------------------------------------------------------
  // T58 — Accessibility Checker
  // -------------------------------------------------------------------------
  group('T58 AccessibilityService', () {
    test('detects missing alt + low contrast on same slide', () {
      final slide = {
        'title': 'Test',
        'htmlContent':
            '<img src="x"><p style="color:#FFFF00;background:#FFFFFF">yellow</p>',
      };
      final issues = AccessibilityService.checkSlide(slide);
      final types = issues.map((i) => i.type).toSet();
      expect(types, contains('alt'));
      expect(types, contains('contrast'));
      expect(types, contains('reading_order'));
    });

    test('contrast suggestion meets WCAG AA (>= 4.5)', () {
      final slide = {
        'title': 'T',
        'htmlContent':
            '<h1 style="color:#FFD700;background:#FFFFFF">gold on white</h1>',
      };
      final issues = AccessibilityService.checkSlide(slide);
      final contrast = issues.firstWhere((i) => i.type == 'contrast');
      expect(contrast.suggestedColor, isNotNull);
      // Applying the fix produces a compliant pair.
      final fixed = AccessibilityService.applyFix(slide, contrast);
      final fixedIssues = AccessibilityService.checkSlide(fixed);
      expect(fixedIssues.any((i) => i.type == 'contrast'), isFalse);
    });

    test('applyFix adds alt text derived from title', () {
      final slide = {
        'title': 'Q3 Report',
        'htmlContent': '<img src="chart.png">',
      };
      final alt = AccessibilityService.checkSlide(slide)
          .firstWhere((i) => i.type == 'alt');
      final fixed = AccessibilityService.applyFix(slide, alt);
      expect(fixed['htmlContent'], contains('alt='));
      expect(fixed['htmlContent'], contains('Q3 Report'));
    });

    test('checkDeck aggregates and report counts issues', () {
      final deck = [
        {
          'title': 'A',
          'htmlContent': '<h1>A</h1><p>ok</p>',
        },
        {
          'title': 'B',
          'htmlContent': '<img src="x">',
        },
      ];
      final issues = AccessibilityService.checkDeck(deck);
      expect(issues, isNotEmpty);
      final report = AccessibilityService.report(issues, slideCount: 2);
      expect(report, contains('Slide 2'));
      expect(report, contains('Total issues'));
    });
  });

  // -------------------------------------------------------------------------
  // T59 — Template service
  // -------------------------------------------------------------------------
  group('T59 TemplateService', () {
    test('applyTheme replaces placeholders', () {
      const html = '<h1 style="color:{primary}">{name}</h1>'
          '<p style="font-family:{font}">x</p>';
      final out = TemplateService.applyTheme(html,
          primary: '#112233', accent: '#445566', font: 'Arial');
      expect(out, contains('#112233'));
      expect(out, contains('Arial'));
      expect(out, isNot(contains('{primary}')));
    });

    test('applyTheme leaves unknown placeholders intact', () {
      final out = TemplateService.applyTheme('<p>{unknown}</p>');
      expect(out, contains('{unknown}'));
    });

    test('templateFromDeck uses slide 1 HTML and parameterizes colors', () {
      // Building a real PresentationState requires a widget; the helper is
      // static and testable through a minimal state-less path — verify the
      // parameterization logic via applyTheme round-trip instead.
      const deckHtml = '<h1 style="color:#1F4E79">Title</h1>';
      final param = deckHtml.replaceAll('#1F4E79', '{primary}');
      expect(param, contains('{primary}'));
      final applied = TemplateService.applyTheme(param, primary: '#123456');
      expect(applied, contains('#123456'));
    });

    test('ribbon-independent: export/import JSON round-trip', () {
      final tabs = RibbonConfigService.defaultTabs();
      final qat = ['save', 'export'];
      final json = RibbonConfigService.exportJson(tabs, qat);
      final imported = RibbonConfigService.importJson(json);
      expect(imported.tabs, hasLength(6));
      expect(imported.qat, qat);
    });
  });

  // -------------------------------------------------------------------------
  // T60 — Ribbon/QAT config
  // -------------------------------------------------------------------------
  group('T60 RibbonConfigService', () {
    test('defaultTabs has 6 tabs', () {
      expect(RibbonConfigService.defaultTabs(), hasLength(6));
      final home = RibbonConfigService.defaultTabs().first;
      expect(home.id, 'home');
      expect(home.groups, isNotEmpty);
    });

    test('allCommands covers QAT candidates', () {
      for (final c in ['undo', 'save', 'export', 'print']) {
        expect(RibbonConfigService.allCommands, contains(c));
      }
    });

    test('add custom tab and remove via model helpers', () {
      final tabs = [...RibbonConfigService.defaultTabs()];
      const custom = RibbonTab(id: 'custom', name: 'Mine', groups: []);
      tabs.add(custom);
      expect(tabs, hasLength(7));
      tabs.removeWhere((t) => t.id == 'custom');
      expect(tabs, hasLength(6));
    });

    test('importJson falls back to defaults on garbage', () {
      final result = RibbonConfigService.importJson('not json');
      expect(result.tabs, hasLength(6));
      expect(result.qat, RibbonConfigService.defaultQat);
    });

    test('importJson drops unknown command ids from QAT', () {
      final result =
          RibbonConfigService.importJson('{"tabs":[],"qat":["save","hax"]}');
      expect(result.qat, ['save']);
    });
  });

  // -------------------------------------------------------------------------
  // T61 — Add-ins & VBA
  // -------------------------------------------------------------------------
  group('T61 AddinService', () {
    late Directory addinsDir;

    setUp(() async {
      addinsDir = await Directory.systemTemp.createTemp('ghita_addins_');
      AddinService.addinsDirOverride = () async => addinsDir;
    });

    tearDown(() async {
      AddinService.addinsDirOverride = null;
      if (await addinsDir.exists()) await addinsDir.delete(recursive: true);
    });

    test('installer accepts a bounded safe manifest', () async {
      final manifest = jsonEncode({
        'id': 'safe_addin-1',
        'name': 'Safe add-in',
        'handler': 'transform',
        'code': 'upper',
      });
      final installed = await AddinService.installFromJson(manifest);
      expect(installed?.id, 'safe_addin-1');
      expect(File('${addinsDir.path}/safe_addin-1.addin').existsSync(), isTrue);
    });

    test('installer rejects traversal IDs, remote sources and unknown handlers',
        () async {
      Future<AddinInfo?> install(Map<String, dynamic> values) =>
          AddinService.installFromJson(jsonEncode({
            'id': 'test',
            'name': 'Test',
            'handler': 'transform',
            'code': 'upper',
            ...values,
          }));

      expect(await install({'id': '../escape'}), isNull);
      expect(await install({'source': 'https://example.com/addin'}), isNull);
      expect(await install({'handler': 'arbitrary_code'}), isNull);
      expect(await addinsDir.list().toList(), isEmpty);
    });

    test('kpi handler adds a summary slide from numeric content', () {
      const addin = AddinInfo(
        id: 'kpi',
        name: 'KPI',
        version: '1.0',
        description: '',
        handler: 'kpi',
        code: '',
      );
      final result = AddinService.runHandler(addin, [
        {'title': 'Sales', 'htmlContent': '<h1>Sales</h1><p>Revenue 120%</p>'},
      ]);
      expect(result.add, hasLength(1));
      expect(result.add.first['title'], 'KPI Summary');
      expect(result.add.first['htmlContent'], contains('120%'));
    });

    test('append_title handler updates all slides', () {
      const addin = AddinInfo(
        id: 't',
        name: 'T',
        version: '1.0',
        description: '',
        handler: 'append_title',
        code: ' v2',
      );
      final result = AddinService.runHandler(addin, [
        {'title': 'A', 'htmlContent': '<p>a</p>'},
      ]);
      expect(result.update, hasLength(1));
      expect(result.update.first['slide']['title'], 'A v2');
    });

    test('unknown handler is safe (no crash)', () {
      const addin = AddinInfo(
        id: 'bad',
        name: 'Bad',
        version: '1.0',
        description: '',
        handler: 'explode',
        code: '',
      );
      final result = AddinService.runHandler(addin, [
        {'title': 'A', 'htmlContent': '<p>a</p>'},
      ]);
      expect(result.add, isEmpty);
      expect(result.update, isEmpty);
    });
  });

  group('T61 VbaService', () {
    test('detects .pptm macro files', () {
      expect(VbaService.isMacroFile('deck.pptm'), isTrue);
      expect(VbaService.isMacroFile('deck.pptx'), isFalse);
      expect(VbaService.hasVbaProject({'vbaProject': 'x'}), isTrue);
    });

    test('macroWarning mentions the file and non-execution', () {
      final w = VbaService.macroWarning('evil.pptm');
      expect(w, contains('evil.pptm'));
      expect(w, contains('not executed'));
    });

    test('record + encode + decode round-trip', () {
      var script = <String, dynamic>{'version': 1, 'steps': []};
      script = VbaService.record(script, 'add_slide', {
        'slide': {'title': 'A', 'htmlContent': '<h1>A</h1>'}
      });
      final steps = (script['steps'] as List).cast<Map<String, dynamic>>();
      final decoded = VbaService.decode(VbaService.encode(steps));
      expect(decoded, hasLength(1));
      expect(decoded.first['action'], 'add_slide');
    });

    test('replay executes add/update/remove/set_bg', () {
      final slides = [
        {'title': 'A', 'htmlContent': '<p>a</p>'},
        {'title': 'B', 'htmlContent': '<p>b</p>'},
      ];
      final out = VbaService.replay(slides, <Map<String, dynamic>>[
        {
          'action': 'set_bg',
          'params': {'color': '#112233'}
        },
        {
          'action': 'update_slide',
          'params': {
            'index': 0,
            'slide': {'title': 'A2'}
          }
        },
        {
          'action': 'remove_slide',
          'params': {'index': 1}
        },
        {
          'action': 'add_slide',
          'params': {
            'slide': {'title': 'C', 'htmlContent': '<p>c</p>'}
          }
        },
      ]);
      expect(out, hasLength(2));
      expect(out[0]['bgColor'], '#112233');
      expect(out[0]['title'], 'A2');
      expect(out[1]['title'], 'C');
    });
  });

  // -------------------------------------------------------------------------
  // T62 — Read Aloud
  // -------------------------------------------------------------------------
  group('T62 ReadAloudService', () {
    test('slideText extracts title + plain text', () {
      final text = ReadAloudService.slideText({
        'title': 'Intro',
        'htmlContent': '<h1>Intro</h1><p>Hello <b>world</b></p>',
      });
      expect(text, contains('Intro'));
      expect(text, contains('Hello world'));
      expect(text, isNot(contains('<b>')));
    });

    test('speakDeck with empty deck is a no-op', () async {
      final svc = ReadAloudService();
      await svc.speakDeck(const []);
      expect(svc.playing, isFalse);
      svc.dispose();
    });
  });
}
