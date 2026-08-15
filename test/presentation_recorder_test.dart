import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/presentation_recorder_service.dart';

/// Track 39 tests — Record presentation (FEAT 65).
void main() {
  test('start sets REC state and tracks elapsed time', () async {
    final r = PresentationRecorderService();
    expect(r.recording, isFalse);
    final ok = await r.start(PresentationRecordMode.timingsNarration);
    expect(ok, isTrue);
    expect(r.recording, isTrue);
    expect(r.mode, PresentationRecordMode.timingsNarration);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(r.elapsedSeconds, greaterThanOrEqualTo(1));
    await r.stop();
    expect(r.recording, isFalse);
  });

  test('start is idempotent while recording', () async {
    final r = PresentationRecorderService();
    await r.start(PresentationRecordMode.timingsNarration);
    final again = await r.start(PresentationRecordMode.video);
    expect(again, isFalse);
    expect(r.mode, PresentationRecordMode.timingsNarration);
    await r.stop();
  });

  test('enterSlide records change timestamps in order', () async {
    final r = PresentationRecorderService();
    await r.start(PresentationRecordMode.timingsNarration);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    r.enterSlide(1);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    r.enterSlide(2);
    r.enterSlide(2); // no-op — same slide
    final result = await r.stop();
    // 3 changes: start, slide1, slide2.
    expect(result.slideChangeSeconds.length, 3);
    expect(result.slideChangeSeconds[0], 0);
    expect(result.slideChangeSeconds[1], lessThan(result.slideChangeSeconds[2]));
  });

  test('stop before start returns empty result', () async {
    final r = PresentationRecorderService();
    final result = await r.stop();
    expect(result.slideChangeSeconds, isEmpty);
    expect(result.videoPath, isNull);
  });

  test('timings-only stop has no video path', () async {
    final r = PresentationRecorderService();
    await r.start(PresentationRecordMode.timingsNarration);
    r.enterSlide(1);
    final result = await r.stop();
    expect(result.videoPath, isNull);
    expect(result.slideChangeSeconds.length, 2);
  });

  test('pause/resume toggle flags', () async {
    final r = PresentationRecorderService();
    await r.start(PresentationRecordMode.timingsNarration);
    expect(r.paused, isFalse);
    await r.pause();
    expect(r.paused, isTrue);
    await r.resume();
    expect(r.paused, isFalse);
    await r.stop();
  });

  test('cancel clears recording state', () async {
    final r = PresentationRecorderService();
    await r.start(PresentationRecordMode.timingsNarration);
    await r.cancel();
    expect(r.recording, isFalse);
    expect(r.elapsedSeconds, 0);
  });
}
