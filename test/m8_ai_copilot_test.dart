import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/services/ai_html_guard.dart';
import 'package:ghita_ppt_converter/services/ai_pipeline_service.dart';
import 'package:ghita_ppt_converter/services/compare_merge_service.dart';
import 'package:ghita_ppt_converter/services/copilot_service.dart';
import 'package:ghita_ppt_converter/services/deck_translation_service.dart';
import 'package:ghita_ppt_converter/services/designer_service.dart';
import 'package:ghita_ppt_converter/services/dictation_service.dart';
import 'package:ghita_ppt_converter/services/reuse_slide_service.dart';

void main() {
  // -------------------------------------------------------------------------
  // T51 — Reuse slides & Compare/Merge
  // -------------------------------------------------------------------------
  group('T51 ReuseSlideService', () {
    test('parses a valid .ghita bundle', () {
      final json = jsonEncode({
        'slides': [
          {'title': 'A', 'htmlContent': '<h1>A</h1>'},
          {'title': 'B', 'html': '<h1>B</h1>'},
        ]
      });
      final result = ReuseSlideService.parseBundle(json);
      expect(result.error, isNull);
      expect(result.slides, hasLength(2));
      // html alias normalized to htmlContent
      expect(result.slides[1]['htmlContent'], '<h1>B</h1>');
    });

    test('rejects non-bundle JSON', () {
      final result = ReuseSlideService.parseBundle('{"foo": 1}');
      expect(result.error, isNotNull);
      expect(result.slides, isEmpty);
    });

    test('splits plain text on --- separators', () {
      final slides = ReuseSlideService.slidesFromText(
          'Title one\n\n- point a\n\n---\n\nTitle two\n\n- point b');
      expect(slides, hasLength(2));
      expect(slides[0]['title'], 'Title one');
      expect(slides[1]['title'], 'Title two');
    });

    test('splits HTML on h1 headings', () {
      final slides = ReuseSlideService.slidesFromText(
          '<h1>First</h1><p>x</p><h1>Second</h1><p>y</p>');
      expect(slides, hasLength(2));
      expect(slides[0]['title'], 'First');
      expect(slides[1]['title'], 'Second');
    });

    test('useCurrentTheme rebuilds HTML to theme baseline', () {
      final slide = {
        'title': 'T',
        'htmlContent':
            '<h1 style="color:red;">T</h1><div><span>body</span></div>'
      };
      final themed = ReuseSlideService.useCurrentTheme(slide);
      expect(themed['htmlContent'], contains('<h1>T</h1>'));
      expect(themed['htmlContent'], contains('<p>body</p>'));
    });
  });

  group('T51 CompareMergeService', () {
    Map<String, dynamic> slide(String title, String html) =>
        {'title': title, 'htmlContent': html};

    test('compare reports added/removed/changed/same', () {
      final a = [
        slide('Same', '<h1>Same</h1>'),
        slide('Changed', '<h1>Old title</h1><p>old body</p>'),
        slide('Removed', '<h1>Gone</h1>'),
      ];
      final b = [
        slide('Same', '<h1>Same</h1>'),
        slide('Changed', '<h1>New title</h1><p>new body here</p>'),
        slide('Added', '<h1>Fresh</h1>'),
      ];
      final diffs = CompareMergeService.compare(a, b);
      expect(diffs, hasLength(3));
      expect(diffs[0].kind, 'same');
      expect(diffs[1].kind, 'changed');
      expect(diffs[1].textChanged, isTrue);
      expect(diffs[2].kind, 'changed');
    });

    test('compare flags length mismatch as added/removed', () {
      final a = [slide('Only', '<h1>Only</h1>')];
      final b = [
        slide('Only', '<h1>Only</h1>'),
        slide('Extra', '<h1>Extra</h1>'),
      ];
      final diffs = CompareMergeService.compare(a, b);
      expect(diffs, hasLength(2));
      expect(diffs[1].kind, 'added');
    });

    test('merge with A/B/both choices', () {
      final a = [slide('A1', '<h1>A1</h1>'), slide('A2', '<h1>A2</h1>')];
      final b = [slide('B1', '<h1>B1</h1>'), slide('B2', '<h1>B2</h1>')];
      final result = CompareMergeService.merge(a, b, {0: 'A', 1: 'both'});
      expect(result.slides, hasLength(3));
      expect(result.slides[0]['title'], 'A1');
      expect(result.slides[1]['title'], 'A2');
      expect(result.slides[2]['title'], 'B2');
      expect(result.fromA, 1);
      expect(result.both, 1);
      // Index beyond both lists keeps whichever side exists.
      final partial = CompareMergeService.merge(a, b, {4: 'B'});
      expect(partial.slides, hasLength(2));
    });

    test('report lists every diff line', () {
      final a = [slide('Same', '<h1>Same</h1>'), slide('Gone', '<h1>Gone</h1>')];
      final b = [slide('Same', '<h1>Same</h1>'), slide('New', '<h1>New</h1>')];
      final report = CompareMergeService.report(CompareMergeService.compare(a, b));
      expect(report, contains('same: Same'));
      expect(report, contains('changed'));
    });
  });

  // -------------------------------------------------------------------------
  // T52 — AI context + validate output
  // -------------------------------------------------------------------------
  group('T52 AI context & HTML guard', () {
    test('buildDeckContextPrompt includes layout/theme/language', () {
      final prompt = AIProviderManager.buildDeckContextPrompt(
        layoutType: 'two_content',
        themeSummary: 'primary #1F4E79, font Segoe UI',
        uiLanguage: 'vi',
        currentSlideSummary: 'Budget overview',
      );
      expect(prompt, contains('two_content'));
      expect(prompt, contains('#1F4E79'));
      expect(prompt, contains('vi'));
      expect(prompt, contains('Budget overview'));
    });

    test('buildDeckContextPrompt omits empty optional fields', () {
      final prompt = AIProviderManager.buildDeckContextPrompt(
        layoutType: 'blank',
        themeSummary: 'dark',
        uiLanguage: 'en',
      );
      expect(prompt, isNot(contains('Deck outline')));
      expect(prompt, isNot(contains('Current slide content')));
    });

    test('guard strips script/iframe and reports warning', () {
      final result = AIHtmlGuard.guard(
          '<h1>ok</h1><script>alert(1)</script><iframe src="x"></iframe>');
      expect(result.html, isNot(contains('<script')));
      expect(result.html, isNot(contains('<iframe')));
      expect(result.warnings.any((w) => w.contains('dangerous_tag')),
          isTrue);
      expect(result.warnings.first, contains('script'));
    });

    test('guard strips event handlers and javascript: URLs', () {
      final result = AIHtmlGuard.guard(
          '<p onclick="evil()">hi</p><a href="javascript:alert(1)">x</a>');
      expect(result.html, isNot(contains('onclick')));
      expect(result.html, isNot(contains('javascript:')));
    });

    test('guard shrinks oversized HTML', () {
      final big = '<div class="a">${'x' * 5000}</div>'
          '${List.filled(30, '<p class="dup">y</p>').join()}';
      final result = AIHtmlGuard.guard(big, maxBytes: 2000);
      expect(result.shrunk, isTrue);
      expect(AIHtmlGuard.utf8Length(result.html), lessThanOrEqualTo(2100));
    });

    test('isBalanced detects unbalanced HTML', () {
      expect(AIHtmlGuard.isBalanced('<h1>x</h1><p>y</p>'), isTrue);
      expect(AIHtmlGuard.isBalanced('<h1>x<p>y</h1>'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // T53 — Resilient pipeline
  // -------------------------------------------------------------------------
  group('T53 AI pipeline', () {
    test('repairJsonArray balances truncated array', () {
      final repaired =
          AIPipelineService.repairJsonArray('[{"title":"a","html":"<h1>a</h1>"}');
      expect(repaired, endsWith(']'));
      final decoded = jsonDecode(repaired) as List;
      expect(decoded, hasLength(1));
    });

    test('repairJsonArray handles code fences', () {
      final repaired = AIPipelineService.repairJsonArray(
          '```json\n[{"title":"a"}]\n```');
      final decoded = jsonDecode(repaired) as List;
      expect(decoded, hasLength(1));
    });

    test('parseIncremental keeps completed slides from a partial stream', () {
      const partial = '[{"title":"one"},{"title":"two"}';
      final result = AIPipelineService.parseIncremental(partial);
      expect(result.slides, hasLength(2));
      expect(result.complete, isFalse);
    });

    test('parseIncremental marks complete arrays', () {
      final result =
          AIPipelineService.parseIncremental('[{"title":"one"}]');
      expect(result.complete, isTrue);
      expect(result.slides, hasLength(1));
    });

    test('estimateTokens scales with length', () {
      final short = AIPipelineService.estimateTokens('hello world');
      final long = AIPipelineService.estimateTokens('x' * 400);
      expect(long, greaterThan(short));
    });

    test('trimHistoryByTokens keeps newest and reports dropped', () {
      final history = [
        for (var i = 0; i < 20; i++)
          {'role': 'user', 'content': 'message number $i ' * 20},
      ];
      final result = AIPipelineService.trimHistoryByTokens(history,
          maxTokens: 300);
      expect(result.dropped, greaterThan(0));
      // The newest message survives (at the end, order preserved).
      expect(result.history.last['content'], contains('message number 19'));
      // Order is preserved — first kept is older than last kept.
      expect(result.history.first['content'], contains('message number 17'));
    });
  });

  // -------------------------------------------------------------------------
  // T54 — Designer
  // -------------------------------------------------------------------------
  group('T54 DesignerService', () {
    test('detectContent finds list items and numbers', () {
      final profile = DesignerService.detectContent(
          '<h1>Q3</h1><ul><li>a</li><li>b</li></ul><p>Sales 40% growth</p>');
      expect(profile['listItems'], 2);
      expect(profile['numbers'], greaterThanOrEqualTo(1));
      expect(profile['title'], 'Q3');
    });

    test('long list suggests two-column layout', () {
      final html = '<h1>T</h1>${List.filled(8, '<li>item</li>').join()}';
      final suggestions = DesignerService.suggest(html);
      expect(suggestions.firstWhere((s) => s.id == 'two_column_list'),
          isNotNull);
    });

    test('numeric content suggests KPI cards', () {
      const html = '<h1>Metrics</h1><p>Revenue 120%</p><p>Users 5k</p>';
      final suggestions = DesignerService.suggest(html);
      expect(suggestions.any((s) => s.id == 'kpi_cards'), isTrue);
    });

    test('applyAccentVariant replaces first non-gray color', () {
      final out = DesignerService.applyAccentVariant(
          '<h1 style="color:#C00000">t</h1><p style="color:#333">b</p>',
          '#1F4E79');
      expect(out, contains('#1F4E79'));
      // gray #333 kept
      expect(out, contains('#333'));
    });

    test('applyDarkVariant swaps backgrounds and lightens text', () {
      final out = DesignerService.applyDarkVariant(
          '<div style="background:#ffffff;color:#000000">x</div>');
      expect(out, contains('#1F2430'));
      expect(out, contains('#EDEFF4'));
    });

    test('suggest always returns a clean baseline (max 5)', () {
      const html = '<h1>T</h1><p>single short quote</p>';
      final suggestions = DesignerService.suggest(html);
      expect(suggestions.length, lessThanOrEqualTo(5));
      expect(suggestions.any((s) => s.id == 'clean'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // T55 — Copilot creator
  // -------------------------------------------------------------------------
  group('T55 CopilotService', () {
    test('slidesFromDocument splits on headings', () {
      final slides = CopilotService.slidesFromDocument(
          '# Intro\nSome text here.\n\n# Details\nMore content words here.');
      expect(slides, hasLength(2));
      expect(slides[0]['title'], 'Intro');
      expect(slides[1]['title'], 'Details');
      expect(slides[0]['htmlContent'], contains('<h1>Intro</h1>'));
    });

    test('slidesFromDocument chunks without headings, capped at maxSlides',
        () {
      final text = List.filled(60, 'This is a sentence about the topic.')
          .join(' ');
      final slides = CopilotService.slidesFromDocument(text, maxSlides: 4);
      expect(slides.length, lessThanOrEqualTo(4));
      expect(slides.length, greaterThanOrEqualTo(2));
    });

    test('buildDeckIndex + searchDeckIndex finds relevant slides', () {
      final slides = [
        {'title': 'Budget', 'htmlContent': '<h1>Budget</h1><p>money plan</p>'},
        {'title': 'Team', 'htmlContent': '<h1>Team</h1><p>people</p>'},
      ];
      final index = CopilotService.buildDeckIndex(slides);
      final hits = CopilotService.searchDeckIndex(index, 'budget money');
      expect(hits, isNotEmpty);
      expect(hits.first, 0);
    });

    test('buildDeckSummaryPrompt includes titles', () {
      final prompt = CopilotService.buildDeckSummaryPrompt([
        {'title': 'Alpha', 'htmlContent': '<p>one two three</p>'},
      ]);
      expect(prompt, contains('Alpha'));
      expect(prompt, contains('one two three'));
    });
  });

  // -------------------------------------------------------------------------
  // T56 — Dictation & deck translation
  // -------------------------------------------------------------------------
  group('T56 DeckTranslationService', () {
    test('textNodes extracts text outside tags', () {
      final nodes = DeckTranslationService.textNodes(
          '<h1>Hello</h1><p><b>World</b></p>');
      expect(nodes, hasLength(2));
      expect(nodes[0].text, 'Hello');
      expect(nodes[1].text, 'World');
    });

    test('applyTranslations swaps only text, keeps tags', () {
      const html = '<h1>Hello</h1><p><b>World</b></p>';
      final nodes = DeckTranslationService.textNodes(html);
      final out = DeckTranslationService.applyTranslations(
          html, ['Xin chào', 'Thế giới']);
      expect(out, '<h1>Xin chào</h1><p><b>Thế giới</b></p>');
      expect(nodes, hasLength(2));
    });

    test('buildTranslationPrompt keeps structure instruction', () {
      final prompt = DeckTranslationService.buildTranslationPrompt(
          '<h1>x</h1>', 'vi');
      expect(prompt, contains('Tiếng Việt'));
      expect(prompt, contains('keep every tag'));
    });

    test('supportedLanguages covers 8 languages', () {
      expect(DeckTranslationService.supportedLanguages, hasLength(8));
      expect(DeckTranslationService.supportedLanguages, contains('vi'));
    });
  });

  group('T56 DictationService (offline logic)', () {
    test('pushManualPhrase fires onPhrase and auto-stop arms', () async {
      final dictation = DictationService();
      final phrases = <String>[];
      dictation.onPhrase = (p) => phrases.add(p);
      dictation.pushManualPhrase('Xin chào');
      expect(phrases, ['Xin chào']);
      expect(dictation.lastPhrase, 'Xin chào');
      // Auto-stop fires after the silence window.
      await Future<void>.delayed(DictationService.silenceTimeout +
          const Duration(milliseconds: 200));
      expect(dictation.listening, isFalse);
      dictation.dispose();
    });
  });
}
