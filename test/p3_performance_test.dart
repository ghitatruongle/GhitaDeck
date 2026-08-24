// P3 (v2.0.1-beta.2) — performance & resource regression benchmarks.
//
// Locks in the P3 optimisations with measurable budgets:
//   * adaptive present-poll cadence (idle backoff, fast after a change)
//   * player HTML generation scales linearly on large decks
// Memory ceilings (RAM < 150 MB during long sessions) stay on the manual
// sign-off checklist — dart tests cannot measure process RSS portably.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/screens/present_screen.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';

void main() {
  group('present poll cadence (P3 backoff)', () {
    test('fast right after a change, mid after a few idle ticks', () {
      expect(PresentScreen.pollDelay(0), PresentScreen.pollFast);
      expect(PresentScreen.pollDelay(2), PresentScreen.pollFast);
      expect(PresentScreen.pollDelay(3), PresentScreen.pollMid);
      expect(PresentScreen.pollDelay(5), PresentScreen.pollMid);
    });

    test('idle backoff caps the round-trip rate', () {
      expect(PresentScreen.pollDelay(6), PresentScreen.pollIdle);
      expect(PresentScreen.pollDelay(100), PresentScreen.pollIdle);
      expect(PresentScreen.pollIdle, greaterThan(PresentScreen.pollFast),
          reason: 'backoff must actually reduce the work rate');
      // Worst case: 1 JS round-trip every 2 s while idle — effectively zero
      // CPU compared to the old fixed 700 ms periodic ping.
      expect(60 / PresentScreen.pollIdle.inSeconds,
          lessThan(60 / PresentScreen.pollFast.inSeconds / 2));
    });
  });

  group('player generation benchmark', () {
    final service = HtmlExportService();

    List<Map<String, String>> deck(int count) => [
          for (var i = 1; i <= count; i++)
            {
              'title': 'Slide $i',
              'htmlContent': '<h1>Mục $i</h1>'
                  '<p>Đoạn văn có dấu tiếng Việt để kiểm tra encoding '
                  'trên slide số $i.</p><ul><li>Điểm a</li><li>Điểm b</li></ul>',
            },
        ];

    test('50-slide deck builds in under 5 seconds', () async {
      final watch = Stopwatch()..start();
      final html = service.buildPresentationHtml(deck(50));
      watch.stop();
      expect(html.length, greaterThan(15000));
      expect(html, contains('Slide 50'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)),
          reason: 'player generation drifted: 50 slides took ${watch.elapsed}');
    });

    test('generation scales linearly (150 slides under 15 seconds)',
        () async {
      final watch = Stopwatch()..start();
      final html = service.buildPresentationHtml(deck(150));
      watch.stop();
      expect(html.length, greaterThan(40000));
      expect(html, contains('Slide 150'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 15)),
          reason: '150 slides took ${watch.elapsed}');
    });
  });

  group('resource hygiene', () {
    test('poll constants stay in a sane range', () {
      expect(PresentScreen.pollFast.inMilliseconds, greaterThanOrEqualTo(500),
          reason: 'too fast would burn CPU on every presentation');
      expect(PresentScreen.pollIdle.inMilliseconds, lessThanOrEqualTo(5000),
          reason: 'too slow would make the slide counter feel laggy');
    });

    test('debugPrint throttling is not disabled globally', () {
      // debugPrint is the project-wide logging path; leaving its throttle
      // disabled floods the console (and any attached logger) on large decks.
      expect(debugPrint, same(debugPrintThrottled));
    });
  });
}
