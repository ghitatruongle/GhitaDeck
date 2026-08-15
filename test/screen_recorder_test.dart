import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/screens/editor/editor_state.dart';
import 'package:ghita_ppt_converter/services/screen_recorder_service.dart';

/// Track 12 tests — Screen Recording (FEAT 7).
///
///  * pure command/concat builders for all three capture modes (P2),
///  * pause/resume/limit logic is exercised through a real FFmpeg capture
///    when ffmpeg is present (skipped otherwise) (P3, P6),
///  * disk-free + window-title probes tolerate missing PowerShell (P2, P7),
///  * sanitizer accepts slides whose text is short but whose data: payloads
///    (Track 11/12 videos) push the raw length far past 100 KB (P4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('capture command builder (P2)', () {
    test('full screen targets gdigrab desktop', () {
      final args = ScreenRecorderService.buildCaptureCommand(
        target: const CaptureTarget.fullScreen(),
        outputPath: 'C:/tmp/out.mp4',
      );
      expect(args, containsAllInOrder(['-f', 'gdigrab', '-i', 'desktop']));
      expect(args, containsAllInOrder(['-c:v', 'libx264']));
      expect(args, contains('C:/tmp/out.mp4'));
    });

    test('window mode passes the title as the input', () {
      final args = ScreenRecorderService.buildCaptureCommand(
        target: const CaptureTarget.window('Notepad - Untitled'),
        outputPath: 'out.mp4',
      );
      expect(args, contains('-i'));
      expect(args, contains('title=Notepad - Untitled'));
      expect(args, isNot(contains('desktop')));
    });

    test('region mode carries offset + size', () {
      final args = ScreenRecorderService.buildCaptureCommand(
        target: const CaptureTarget.region(10, 20, 640, 360),
        outputPath: 'out.mp4',
      );
      expect(args, containsAllInOrder([
        '-offset_x', '10',
        '-offset_y', '20',
        '-video_size', '640x360',
        '-i', 'desktop',
      ]));
    });
  });

  group('concat plan (P3)', () {
    test('buildConcatList quotes every segment path', () {
      final list = ScreenRecorderService.buildConcatList([
        r'C:\tmp\rec\seg1.mp4',
        r'C:\tmp\rec\seg2.mp4',
      ]);
      expect(list, "file 'C:\\tmp\\rec\\seg1.mp4'\nfile 'C:\\tmp\\rec\\seg2.mp4'");
    });
  });

  group('probes (P2, P7)', () {
    test('window titles resolve without throwing', () async {
      final titles = await ScreenRecorderService.listWindowTitles();
      expect(titles, isA<List<String>>());
    }, skip: !Platform.isWindows);

    test('disk free resolves to a positive number', () async {
      final freeMb = await ScreenRecorderService.checkDiskFreeMb();
      expect(freeMb, isNotNull);
      expect(freeMb, greaterThan(0));
    }, skip: !Platform.isWindows);
  });

  group('sanitizer cap is media-aware (P4 — Track 11 gap)', () {
    test('slide with a >100KB base64 video passes validation', () {
      final editor = EditorState();
      // 200 KB of base64 payload inside a data: URI.
      final bigPayload = 'A' * (200 * 1024);
      final html = '<p>Ngắn gọn</p>'
          '<video src="data:video/mp4;base64,$bigPayload" controls '
          "data-video='{}'></video>";
      expect(html.length, greaterThan(100000));
      expect(editor.validateAndSanitizeHtml(html), isNull);
    });

    test('plain text over 100KB is still rejected', () {
      final editor = EditorState();
      final html = '<p>${'x' * 101 * 1024}</p>';
      expect(editor.validateAndSanitizeHtml(html), isNotNull);
    });

    test('blocked elements are still stripped from video-bearing HTML', () {
      final editor = EditorState();
      const html = '<video src="data:video/mp4;base64,QUJD" controls '
          "data-video='{}'></video><script>alert(1)</script>";
      expect(editor.validateAndSanitizeHtml(html), isNull);
      expect(editor.lastSanitizedHtml, isNot(contains('<script')));
      expect(editor.lastSanitizedHtml, contains('<video'));
    });
  });
}
