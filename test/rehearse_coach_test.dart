import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/rehearse_service.dart';
import 'package:ghita_ppt_converter/services/coach_service.dart';

/// Track 38 tests — Rehearse timings & Presenter Coach (FEAT 54, 63).
void main() {
  group('RehearseService (P1–P3)', () {
    test('records per-slide durations', () {
      final r = RehearseService();
      r.start();
      r.enterSlide(0);
      Future<void>.delayed(const Duration(milliseconds: 20), () {
        r.enterSlide(1);
        Future<void>.delayed(const Duration(milliseconds: 20), () {
          final session = r.finish();
          expect(session.timings.length, 2);
          expect(session.timings[0].slideIndex, 0);
          expect(session.timings[1].slideIndex, 1);
          expect(session.timings[0].durationMs, greaterThan(0));
        });
      });
    });

    test('finish returns session with total time', () async {
      final r = RehearseService();
      r.start();
      r.enterSlide(0);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      r.enterSlide(1);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final session = r.finish();
      expect(session.timings.length, 2);
      expect(session.totalMs,
          session.timings.fold(0, (a, b) => a + b.durationMs));
    });

    test('report mentions total and longest slide', () async {
      final r = RehearseService();
      r.start();
      r.enterSlide(0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      r.enterSlide(1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final session = r.finish();
      final report = r.buildReport(session);
      expect(report, contains('Rehearsal report'));
      expect(report, contains('Total time'));
      expect(report, contains('Longest slide'));
    });

    test('sessions serialize round-trip', () async {
      final r = RehearseService();
      r.start();
      r.enterSlide(0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      r.enterSlide(1);
      final session = r.finish();
      final json = RehearseService.sessionsToJson([session]);
      final restored = RehearseService.sessionsFromJson(json);
      expect(restored.length, 1);
      expect(restored.first.timings.length, 2);
    });

    test('sessionsFromJson tolerates garbage', () {
      expect(RehearseService.sessionsFromJson('x'), isEmpty);
    });
  });

  group('CoachService local analysis (P4–P6)', () {
    test('tokens strip punctuation', () {
      expect(CoachService.tokens('Hello, world!'), ['hello', 'world']);
      expect(CoachService.tokens('Xin chào mọi người'), ['xin', 'chào', 'mọi', 'người']);
    });

    test('counts EN filler words', () {
      const transcript = 'Um, well uh like basically you know, um.';
      expect(CoachService.countFillerWords(transcript), greaterThanOrEqualTo(5));
    });

    test('counts VI filler words', () {
      const transcript = 'ừm hôm nay ừm chúng ta à';
      expect(CoachService.countFillerWords(transcript), 3);
    });

    test('pauseSeconds only counts gaps >= 1.5s', () {
      expect(CoachService.pauseSeconds([1.0, 2.0, 3.0, 0.5]), 5);
      expect(CoachService.pauseSeconds([1.0, 1.2]), 0);
    });

    test('score rewards good pace and penalises fillers', () {
      final good = CoachService.analyze(
          transcript: 'Welcome to our presentation about growth.',
          durationSeconds: 4); // ~9 words → 135 wpm
      expect(good.score, greaterThanOrEqualTo(85));

      final slow = CoachService.analyze(
          transcript: 'Um hello um this um is um a um very um slow um pace um',
          durationSeconds: 60);
      expect(slow.wordsPerMinute, lessThan(90));
      expect(slow.fillerCount, greaterThan(0));
      expect(slow.score, lessThan(good.score));
    });

    test('feedback includes filler warning', () {
      final r = CoachService.analyze(
          transcript: 'um um um okay',
          durationSeconds: 5);
      expect(
        r.feedback.any((f) => f.title == 'Filler words'),
        isTrue,
      );
    });

    test('aiAnalyze parses provider JSON and falls back on error', () async {
      final r = await CoachService.aiAnalyze(
        transcript: 'hello',
        durationSeconds: 5,
        aiPrompt: (_) async =>
            '{"score": 88, "wordsPerMinute": 130, "fillerCount": 1, '
                '"pauseSeconds": 0, "feedback": [{"title": "Good", "detail": "ok"}]}',
      );
      expect(r.score, 88);
      expect(r.feedback.single.title, 'Good');

      await expectLater(
        CoachService.aiAnalyze(
          transcript: 'x',
          durationSeconds: 1,
          aiPrompt: (_) async => 'not json',
        ),
        throwsException,
      );
    });
  });
}
