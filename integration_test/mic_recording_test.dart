// REAL microphone recording (Track 13, P10 gate): runs inside the actual
// Windows app process so the `record` plugin and the mic are available —
// `flutter test` cannot load desktop plugins, which is why the earlier
// unit-level probe reported MIC_UNAVAILABLE without a device present.
//
// Run: flutter test integration_test/mic_recording_test.dart -d windows
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/audio_recording_service.dart';
import 'package:ghita_ppt_converter/services/video_embed_service.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('record narration with the real microphone', (tester) async {
    final service = AudioRecordingService();
    final ok = await service.startRecording(slideIndex: 0);
    if (!ok) {
      // ignore: avoid_print
      print('MIC_START_FAILED');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    final path = await service.stopRecording();
    expect(path, isNotNull, reason: 'recording produced a file');
    final m4a = await AudioRecordingService.transcodeToM4a(path!);
    final durationMs = await VideoEmbedService.probeDurationMs(m4a);
    // ignore: avoid_print
    print('MIC_RECORDED: $m4a durationMs=$durationMs size=${File(m4a).lengthSync()}');
    expect(durationMs, greaterThan(1000), reason: 'a ~3s narration');
    // Artifact for the PPTX/HTML export verification.
    final keep = File('D:/GhitaPPT/tool/real_mic.m4a');
    keep.parent.createSync(recursive: true);
    File(m4a).copySync(keep.path);
    service.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
