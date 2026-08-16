import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// A live subtitle line with timing (Track 37, FEAT 62).
class SubtitleLine {
  final String text;
  final DateTime timestamp;
  final bool isError;

  const SubtitleLine({
    required this.text,
    required this.timestamp,
    this.isError = false,
  });
}

/// Subtitle engine (Track 37, P5–P7).
///
/// Windows speech recognition is invoked via a PowerShell C# helper (the same
/// approach the screenshot service uses) — Windows 10/11 ships the SAPI/Media
/// speech recognizer. When speech is unavailable (no mic / no runtime) the
/// service reports a graceful error instead of crashing, and the UI can keep
/// subtitles off.
///
/// Because SAPI live dictation output can be flaky across machines, the
/// service also exposes [pushManualText] so a host AI/streaming transcript
/// can feed subtitles directly — the UI consumes [lines] either way.
class SubtitleService extends ChangeNotifier {
  Process? _process;
  bool _listening = false;
  final List<SubtitleLine> _lines = [];
  Timer? _sweepTimer;

  bool get listening => _listening;

  List<SubtitleLine> get lines => List.unmodifiable(_lines);

  /// Latest non-error subtitle (what the overlay shows).
  String? get currentText {
    for (final line in _lines.reversed) {
      if (!line.isError && line.text.trim().isNotEmpty) return line.text;
    }
    return null;
  }

  /// Whether the machine looks able to run Windows speech recognition.
  /// Overridable for tests.
  bool Function()? availabilityProbe;

  Future<bool> probeAvailable() async {
    final probe = availabilityProbe;
    if (probe != null) return probe();
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Get-WindowsCapability -Online -Name "Language.Speech~~~*" '
              '-ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty State',
        ],
      ).timeout(const Duration(seconds: 8));
      final out = (result.stdout as String).trim();
      return out.isNotEmpty && out != 'NotPresent';
    } catch (_) {
      return false;
    }
  }

  Future<void> start({String locale = 'en'}) async {
    if (_listening) return;
    _lines.clear();
    _listening = true;
    notifyListeners();
    _sweepTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      // Keep the history bounded.
      if (_lines.length > 200) {
        _lines.removeRange(0, _lines.length - 200);
        notifyListeners();
      }
    });
    try {
      await _startSapi(locale);
    } catch (e) {
      _reportUnavailable();
    }
  }

  Future<void> _startSapi(String locale) async {
    // PowerShell + System.Speech: a compact recognizer that echoes the
    // recognized phrase to stdout line by line. Exit code 0 = started;
    // a missing System.Speech or mic throws quickly.
    final culture = locale == 'vi' ? 'vi-VN' : 'en-US';
    final process = await Process.start('powershell', [
      '-NoProfile',
      '-Command',
      '''
Add-Type -AssemblyName System.Speech
\$culture = [System.Globalization.CultureInfo]::GetCultureInfo("$culture")
\$r = [System.Speech.Recognition.SpeechRecognitionEngine]::new(\$culture)
\$r.SetInputToDefaultAudioDevice()
\$r.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
\$evt = Register-ObjectEvent -InputObject \$r -EventName SpeechRecognized -Action {
  Write-Output ([string]\$event.SourceEventArgs.Result.Text)
}
\$r.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
while (\$true) { Start-Sleep -Seconds 2 }
''',
    ]);
    _process = process;
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final text = line.trim();
      if (text.isEmpty) return;
      _lines.add(SubtitleLine(text: text, timestamp: DateTime.now()));
      notifyListeners();
    });
    process.stderr.drain<void>();
    unawaited(process.exitCode.then((exitCode) {
      if (!identical(_process, process)) return;
      _process = null;
      if (_listening) _reportUnavailable();
    }));
  }

  void _reportUnavailable() {
    _listening = false;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    if (!_lines.any((line) => line.isError)) {
      _lines.add(SubtitleLine(
        text: 'subtitle_unavailable',
        timestamp: DateTime.now(),
        isError: true,
      ));
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _listening = false;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    notifyListeners();
  }

  /// Feed a transcript line from an external AI streaming recognizer.
  void pushManualText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _lines.add(SubtitleLine(text: trimmed, timestamp: DateTime.now()));
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    try {
      _process?.kill();
    } catch (_) {}
    super.dispose();
  }
}
