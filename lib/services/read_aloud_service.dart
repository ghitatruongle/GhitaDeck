import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Read Aloud — Windows TTS via one long-lived PowerShell + SAPI process.
///
/// Commands carry an ID, so pause/resume/stop acknowledgements cannot be
/// confused with the completion event of a long utterance. Speech itself is
/// asynchronous inside the helper, allowing control commands to take effect
/// immediately while a slide is being read.
class ReadAloudService extends ChangeNotifier {
  static const double rateSlow = -2;
  static const double rateNormal = 0;
  static const double rateFast = 2;

  Process? _process;
  bool _playing = false;
  bool _paused = false;
  int _currentIndex = 0;
  int _totalSlides = 0;
  String _locale = 'en';
  double _rate = rateNormal;
  int _nextCommandId = 1;
  int _session = 0;

  bool get isPlaying => _playing;
  bool get isPaused => _paused;
  int get currentIndex => _currentIndex;
  int get totalSlides => _totalSlides;

  // Backward-compatible aliases used by tests / older UI.
  bool get playing => _playing;
  bool get paused => _paused;

  final Map<int, Completer<void>> _pending = <int, Completer<void>>{};
  StreamSubscription<String>? _outSub;

  static String slideText(Map<String, dynamic> slide) {
    final title = (slide['title'] ?? '').toString();
    final html = (slide['htmlContent'] ?? slide['html'] ?? '').toString();
    final text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return title.isEmpty ? text : '$title. $text';
  }

  static String _buildScript(double rate, String culture) => r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Speech
Add-Type -ReferencedAssemblies System.Speech -TypeDefinition @'
using System;
using System.Globalization;
using System.Speech.Synthesis;
using System.Text;

public static class GhitaSpeechDriver {
  private static readonly object OutputLock = new object();

  private static void Reply(string id, string status) {
    lock (OutputLock) {
      Console.WriteLine(id + "|" + status);
      Console.Out.Flush();
    }
  }

  public static void Run(int rate, string cultureName) {
    using (var speech = new SpeechSynthesizer()) {
      speech.Rate = rate;
      try {
        speech.SelectVoiceByHints(
          VoiceGender.NotSet,
          VoiceAge.NotSet,
          0,
          CultureInfo.GetCultureInfo(cultureName));
      } catch { }

      string utteranceId = null;
      speech.SpeakCompleted += delegate(object sender, SpeakCompletedEventArgs e) {
        var completedId = utteranceId;
        utteranceId = null;
        if (completedId != null) {
          Reply(completedId, e.Cancelled ? "CANCELLED" : "OK");
        }
      };

      string line;
      while ((line = Console.ReadLine()) != null) {
        var parts = line.Split(new[] { '|' }, 3);
        if (parts.Length < 2) continue;
        var id = parts[0];
        var command = parts[1];
        try {
          if (command == "SPEAK" && parts.Length == 3) {
            utteranceId = id;
            var text = Encoding.UTF8.GetString(
              Convert.FromBase64String(parts[2]));
            speech.SpeakAsync(text);
          } else if (command == "PAUSE") {
            if (speech.State == SynthesizerState.Speaking) speech.Pause();
            Reply(id, "OK");
          } else if (command == "RESUME") {
            if (speech.State == SynthesizerState.Paused) speech.Resume();
            Reply(id, "OK");
          } else if (command == "STOP") {
            speech.SpeakAsyncCancelAll();
            Reply(id, "OK");
            return;
          } else {
            Reply(id, "ERROR");
          }
        } catch {
          Reply(id, "ERROR");
        }
      }
    }
  }
}
'@
[GhitaSpeechDriver]::Run(__RATE__, "__CULTURE__")
'''
      .replaceAll('__RATE__', rate.round().toString())
      .replaceAll('__CULTURE__', culture);

  Future<void> _ensureProcess(double rate, String locale) async {
    if (_process != null && _rate == rate && _locale == locale) return;
    _killProcess();
    _rate = rate;
    _locale = locale;
    final culture = locale == 'vi' ? 'vi-VN' : 'en-US';
    try {
      final process = await Process.start('powershell', [
        '-NoProfile',
        '-Command',
        _buildScript(rate, culture),
      ]);
      _process = process;
      _listenOutput(process);
      process.stderr.drain<void>();
      unawaited(process.exitCode.then((_) {
        if (!identical(_process, process)) return;
        _process = null;
        _playing = false;
        _paused = false;
        _completePending();
        notifyListeners();
      }));
    } catch (error) {
      debugPrint('ReadAloud error: $error');
      _process = null;
    }
  }

  void _listenOutput(Process process) {
    _outSub?.cancel();
    _outSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final separator = line.indexOf('|');
      if (separator <= 0) return;
      final id = int.tryParse(line.substring(0, separator));
      if (id == null) return;
      final completer = _pending.remove(id);
      if (completer != null && !completer.isCompleted) completer.complete();
    });
  }

  Future<void> _send(String command, [String payload = '']) {
    final process = _process;
    if (process == null) return Future.value();
    final id = _nextCommandId++;
    final completer = Completer<void>();
    _pending[id] = completer;
    try {
      process.stdin.writeln('$id|$command|$payload');
    } catch (_) {
      _pending.remove(id);
      completer.complete();
    }
    return completer.future;
  }

  /// Speak one utterance and complete when it has finished.
  Future<void> speak(
    String text, {
    double rate = rateNormal,
    String locale = 'en',
  }) async {
    if (text.trim().isEmpty) return;
    final session = ++_session;
    await _ensureProcess(rate, locale);
    if (_process == null || session != _session) return;
    _playing = true;
    _paused = false;
    notifyListeners();
    await _send('SPEAK', base64Encode(utf8.encode(text)));
    if (session == _session) {
      _playing = false;
      _paused = false;
      notifyListeners();
    }
  }

  /// Speak the whole deck from [startIndex], one slide at a time.
  Future<void> speakDeck(
    List<Map<String, dynamic>> slides, {
    int startIndex = 0,
    double rate = rateNormal,
    String locale = 'en',
  }) async {
    if (slides.isEmpty) return;
    final session = ++_session;
    await _ensureProcess(rate, locale);
    if (_process == null || session != _session) return;
    _totalSlides = slides.length;
    _playing = true;
    _paused = false;
    notifyListeners();
    for (var i = startIndex.clamp(0, slides.length - 1);
        i < slides.length;
        i++) {
      if (!_playing || session != _session) break;
      _currentIndex = i;
      notifyListeners();
      final text = slideText(slides[i]);
      if (text.isNotEmpty) {
        await _send('SPEAK', base64Encode(utf8.encode(text)));
      }
    }
    if (_playing && session == _session) {
      _playing = false;
      _paused = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (!_playing || _paused) return;
    _paused = true;
    notifyListeners();
    await _send('PAUSE');
  }

  Future<void> resume() async {
    if (!_playing || !_paused) return;
    await _send('RESUME');
    _paused = false;
    notifyListeners();
  }

  Future<void> stop() async {
    ++_session;
    _playing = false;
    _paused = false;
    notifyListeners();
    if (_process != null) await _send('STOP');
    _killProcess();
  }

  void _completePending() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete();
    }
    _pending.clear();
  }

  void _killProcess() {
    final process = _process;
    _process = null;
    try {
      process?.kill();
    } catch (_) {}
    _outSub?.cancel();
    _outSub = null;
    _completePending();
  }

  @override
  void dispose() {
    ++_session;
    _killProcess();
    super.dispose();
  }
}
