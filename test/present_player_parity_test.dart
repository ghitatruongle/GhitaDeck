// P1 follow-up — present-player parity & resilience regression tests for
// HtmlExportService.buildPresentationHtml.
//
// Real-world failure locked down here: a deck without explicit backgrounds
// rendered as a full-screen dark-purple letterbox (body #1a1a2e bleeding
// through transparent slides) that looked nothing like the editor preview,
// and the starting slide only became visible via player JS — one script
// error killed both the picture and the navigation.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';

// A real 1x1 PNG (same fixture the export tests use).
const kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  final service = HtmlExportService();

  group('slide surface parity with the editor preview', () {
    test('slides default to a white surface with dark text', () {
      final html = service.buildPresentationHtml(
        [
          {'title': 'Plain', 'htmlContent': '<p>body text</p>'},
        ],
        imageMaxWidth: 1200,
      );

      final slideRule =
          RegExp(r'\.slide \{[^}]+\}').firstMatch(html)!.group(0)!;
      expect(slideRule, contains('background: #ffffff;'));
      expect(slideRule, contains('color: #1f2937;'));
      expect(slideRule, isNot(contains('#e0e0e0')),
          reason: 'the grey-on-dark palette must not leak into slides');
      expect(html, contains('color: #1f4e78;'), reason: 'heading blue');
      expect(html, contains('.slide b, .slide strong { color: #111827; }'));
    });

    test('explicit per-slide background still wins', () {
      final html = service.buildPresentationHtml(
        [
          {
            'title': 'Tinted',
            'htmlContent':
                '<div data-bg-color="#123456"><p>on brand colour</p></div>',
          },
        ],
        imageMaxWidth: 1200,
      );
      expect(html, contains('#slide-0 { background-color: #123456; }'));
    });
  });

  group('server-side activation resilience', () {
    test('starting slide ships with the active class pre-applied', () {
      final html = service.buildPresentationHtml(
        [
          {'title': 'One', 'htmlContent': '<p>1</p>'},
          {'title': 'Two', 'htmlContent': '<p>2</p>'},
        ],
        imageMaxWidth: 1200,
      );
      expect(html, contains('class="slide active"'),
          reason: 'slide 1 must be visible even if the player script dies');
    });

    test('startIndex shifts both the active class and the JS cursor',
        () {
      final html = service.buildPresentationHtml(
        [
          {'title': 'One', 'htmlContent': '<p>1</p>'},
          {'title': 'Two', 'htmlContent': '<p>2</p>'},
        ],
        imageMaxWidth: 1200,
        startIndex: 1,
      );
      expect(html, contains('let currentSlide = 1;'));
      expect(
        RegExp('<div class="slide[^"]*active" id="slide-1">').hasMatch(html),
        isTrue,
        reason: '"Present from current" opens on the picked slide',
      );
      expect(html, contains('showSlide(1);'),
          reason: 'the script tail activates the requested start slide');
    });
  });

  group('script-block integrity', () {
    test('stray closing-tag text cannot break the inline player script',
        () {
      final html = service.buildPresentationHtml(
        [
          {
            'title': 'Stray tag',
            'htmlContent': '<p>before</p></script><p>after</p>',
          },
        ],
        imageMaxWidth: 1200,
      );
      // Exactly one '</script>' may exist in the whole document: the
      // player's own final closing tag. Anything the parser keeps as body
      // text must not add another one.
      expect(html.split('</script>').length, 2);
    });

    test('hoisted image payloads keep valid json after escaping', () {
      final html = service.buildPresentationHtml(
        [
          {
            'title': 'Pic',
            'htmlContent': '<img src="data:image/png;base64,$kTinyPngBase64">',
          },
        ],
        imageMaxWidth: 1200,
      );
      final match = RegExp(r'const ghitaImages = (\{.*?\});', dotAll: true)
          .firstMatch(html);
      expect(match, isNotNull);
      final decoded = jsonDecode(match!.group(1)!) as Map;
      expect(decoded.values.join(), contains(kTinyPngBase64.substring(0, 24)),
          reason: 'escaping must not corrupt legitimate media payloads');
    });

    test('no prev/next buttons; vertical arrows navigate instead', () {
      final html = service.buildPresentationHtml(
        [
          {'title': 'One', 'htmlContent': '<p>1</p>'},
          {'title': 'Two', 'htmlContent': '<p>2</p>'},
        ],
        imageMaxWidth: 1200,
      );
      // P1b: the floating controls bar keeps only the counter — WebView2's
      // native HWND swallowed clicks aimed at Flutter-drawn buttons anyway,
      // and PowerPoint itself navigates by keyboard.
      expect(html, isNot(contains('prevBtn')));
      expect(html, isNot(contains('nextBtn')));
      expect(html, contains('id="counter"'));

      // Vertical arrows join the PPT-style navigation set.
      final keyHandler = html.substring(
        html.indexOf('document.addEventListener("keydown"'),
        html.lastIndexOf('</script>'),
      );
      expect(keyHandler, contains('"ArrowUp"'), reason: 'ArrowUp advances');
      expect(keyHandler, contains('"ArrowDown"'), reason: 'ArrowDown goes back');
    });

    test('player script wires navigation and runs initial activation',
        () {
      final html = service.buildPresentationHtml(
        [
          {
            'title': 'Order',
            'htmlContent':
                '<img src="data:image/png;base64,$kTinyPngBase64">',
          },
        ],
        imageMaxWidth: 1200,
      );
      final scriptBlock = html.substring(
        html.indexOf('<script>'),
        html.lastIndexOf('</script>'),
      );
      expect(scriptBlock, contains('function changeSlide'));
      expect(scriptBlock, contains('const ghitaImages'));
      expect(scriptBlock.trimRight(), endsWith('showSlide(0);'),
          reason: 'initial activation is the final statement of the '
              'player script');
    });
  });
}
