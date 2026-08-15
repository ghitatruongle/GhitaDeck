import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/remote_control_service.dart';
import 'package:ghita_ppt_converter/services/subtitle_service.dart';

/// Track 37 tests — Remote control & live subtitles (FEAT 61, 62).
void main() {
  group('RemoteCommand (P1/P2)', () {
    test('parses next/prev/jump from JSON', () {
      final next = RemoteCommand.fromJson(jsonEncode({'action': 'next'}));
      expect(next.action, 'next');
      final jump = RemoteCommand.fromJson(jsonEncode({'action': 'jump', 'slide': 4}));
      expect(jump.action, 'jump');
      expect(jump.slide, 4);
    });

    test('tolerates malformed JSON', () {
      final cmd = RemoteCommand.fromJson('not-json');
      expect(cmd.action, '');
      final empty = RemoteCommand.fromJson('');
      expect(empty.action, '');
    });
  });

  group('RemoteState (P3)', () {
    test('serializes current slide, total and notes', () {
      const state = RemoteState(
          currentSlide: 3, totalSlides: 10, notes: 'hello', elapsedSeconds: 42);
      final map = jsonDecode(state.toJson()) as Map<String, dynamic>;
      expect(map['currentSlide'], 3);
      expect(map['totalSlides'], 10);
      expect(map['notes'], 'hello');
      expect(map['elapsedSeconds'], 42);
    });
  });

  group('RemoteControlService (P2/P4)', () {
    test('token is 64 hex chars (32 bytes)', () {
      final svc = RemoteControlService();
      final token = svc.generateToken();
      expect(token.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(token), isTrue);
      // Two tokens differ.
      expect(token, isNot(svc.generateToken()));
    });

    test('start(requireToken: false) admits a token-less client', () async {
      final svc = RemoteControlService();
      final url = await svc.start(port: 8093, maxPort: 8099, requireToken: false);
      expect(url, isNotNull);
      try {
        final ws = await WebSocket.connect(
          'ws://127.0.0.1:${svc.port}/ws',
          customClient: HttpClient()..findProxy = (u) => 'DIRECT',
        ).timeout(const Duration(seconds: 5));
        // Authorized → the server immediately pushes a state snapshot.
        final first = await ws.first.timeout(const Duration(seconds: 5));
        final msg = jsonDecode(first as String) as Map<String, dynamic>;
        expect(msg['type'], 'state');
        await ws.close();
      } finally {
        await svc.stop();
      }
    });

    test('start(requireToken: true) rejects a token-less client', () async {
      final svc = RemoteControlService();
      final url = await svc.start(port: 8093, maxPort: 8099, requireToken: true);
      expect(url, isNotNull);
      try {
        final ws = await WebSocket.connect(
          'ws://127.0.0.1:${svc.port}/ws',
          customClient: HttpClient()..findProxy = (u) => 'DIRECT',
        ).timeout(const Duration(seconds: 5));
        final first = await ws.first.timeout(const Duration(seconds: 5));
        final msg = jsonDecode(first as String) as Map<String, dynamic>;
        expect(msg['type'], 'error');
        expect(msg['message'], 'bad_token');
        await ws.close();
      } finally {
        await svc.stop();
      }
    });
  });

  group('SubtitleService (P5–P7)', () {
    test('starts in listening mode and captures manual transcript lines', () {
      final svc = SubtitleService()
        ..availabilityProbe = () => true;
      // Start will try to spawn powershell — in the test env this fails fast
      // (caught) so we can still assert the listening flag and manual feed.
      svc.start();
      svc.pushManualText('Hello everyone');
      svc.pushManualText('Welcome');
      expect(svc.listening, isTrue);
      expect(svc.lines.length, greaterThanOrEqualTo(2));
      expect(svc.currentText, 'Welcome');
      svc.stop();
      expect(svc.listening, isFalse);
    });

    test('currentText skips error lines and empty text', () {
      final svc = SubtitleService();
      svc.pushManualText('   ');
      svc.pushManualText('Real words');
      expect(svc.currentText, 'Real words');
    });

    test('clear empties the history', () {
      final svc = SubtitleService();
      svc.pushManualText('one');
      svc.clear();
      expect(svc.lines, isEmpty);
      expect(svc.currentText, isNull);
    });
  });
}
