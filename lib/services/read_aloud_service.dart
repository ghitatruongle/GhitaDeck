import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Read Aloud — Windows TTS via a single long-lived PowerShell + SAPI
/// process (Track 62).
///
/// Text is exchanged as base64 lines over stdin so quoting/encoding can never
/// break Vietnamese; the process answers "OK" per command so the Dart side
/// knows exactly when an utterance finished. Keeping ONE process alive means
/// reading a whole deck does not pay ~0.5 s of PowerShell startup per slide,
/// and Pause/Resume map to real SAPI Pause/Resume instead of kill/restart.
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

  bool get isPlaying => _playing;
  bool get isPaused => _paused;
  int get currentIndex => _currentIndex;
  int get totalSlides => _totalSlides;

  // Backward-compatible aliases used by tests / older UI.
  bool get playing => _playing;
  bool get paused => _paused;

  final List<Completer<void>> _pending = <Completer<void>>[];
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

  /// The PowerShell driver: sets UTF-8 console IO (PowerShell 5.1 otherwise
  /// writes UTF-16 to redirected stdout, which would corrupt the "OK" lines),
  /// then loops over stdin commands forever:
  ///   <base64>  → speak it (synchronously) then reply OK
  ///   PAUSE     → SAPI Pause + reply OK
  ///   RESUME    → SAPI Resume + reply OK
  ///   STOP      → cancel speech + reply OK + exit
  static String _buildScript(double rate, String culture) => '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Speech
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$s.Rate = $rate
try { \$s.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::NotSet, [System.Speech.Synthesis.VoiceAge]::NotSet, 0, [System.Globalization.CultureInfo]::GetCultureInfo("$culture")) } catch {}
while (\$true) {
  \$line = [Console]::In.ReadLine()
  if (\$null -eq \$line -or \$line.Length -eq 0) { break }
  if (\$line -eq "PAUSE") { \$s.Pause(); Write-Output "OK"; continue }
  if (\$line -eq "RESUME") { \$s.Resume(); Write-Output "OK"; continue }
  if (\$line -eq "STOP") { \$s.SpeakAsyncCancelAll(); Write-Output "OK"; break }
  \$text = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(\$line))
  \$s.Speak(\$text)
  Write-Output "OK"
}
''';

  /// Start (or restart when rate/locale changed) the persistent process.
  Future<void> _ensureProcess(double rate, String locale) async {
    if (_process != null && _rate == rate && _locale == locale) return;
    _killProcess();
    _rate = rate;
    _locale = locale;
    final culture = locale == 'vi' ? 'vi-VN' : 'en-US';
    try {
      _process = await Process.start('powershell', [
        '-NoProfile',
        '-Command',
        _buildScript(rate, culture),
      ]);
      _listenOutput();
      _process!.stderr.drain<void>();
      unawaited(_process!.exitCode.then((_) {
        // Process died (crash or killed) — fail every in-flight command so
        // awaiters do not hang forever.
        _process = null;
        _playing = false;
        _paused = false;
        for (final c in _pending) {
          if (!c.isCompleted) c.complete();
        }
        _pending.clear();
        notifyListeners();
      }));
    } catch (e) {
      debugPrint('ReadAloud error: $e');
      _process = null;
    }
  }

  void _listenOutput() {
    _outSub?.cancel();
    _outSub = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim() == 'OK' && _pending.isNotEmpty) {
        _pending.removeAt(0).complete();
      }
    });
  }

  Future<void> _send(String command) {
    final completer = Completer<void>();
    _pending.add(completer);
    _process!.stdin.writeln(command);
    return completer.future;
  }

  /// Speak [text] using the persistent SAPI process (restarts it only when
  /// the rate or locale changes). Completes when the utterance finished.
  Future<void> speak(String text,
      {double rate = rateNormal, String locale = 'en'}) async {
    await _ensureProcess(rate, locale);
    if (_process == null) return;
    // Cancel any in-flight utterance first (deck mode awaits each OK so this
    // is normally a no-op; direct UI calls can overlap).
    try {
      await _send('STOP');
      await _send(base64Encode(utf8.encode(text)));
    } catch (_) {
      // stdin closed — process died; fall back to no-op.
    }
    _playing = true;
    _paused = false;
    notifyListeners();
  }

  /// Speak the whole deck from [startIndex], one slide at a time — reusing
  /// the same PowerShell process across every slide.
  Future<void> speakDeck(List<Map<String, dynamic>> slides,
      {int startIndex = 0, double rate = rateNormal, String locale = 'en'}) async {
    if (slides.isEmpty) return;
    await _ensureProcess(rate, locale);
    if (_process == null) return;
    _totalSlides = slides.length;
    _playing = true;
    _paused = false;
    notifyListeners();
    for (var i = startIndex; i < slides.length; i++) {
      if (!_playing) break; // stopped by user
      _currentIndex = i;
      notifyListeners();
      final text = slideText(slides[i]);
      if (text.isNotEmpty) {
        try {
          await _send(base64Encode(utf8.encode(text)));
        } catch (_) {
          break;
        }
      }
    }
    if (_playing) {
      _playing = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (!_playing || _paused) return;
    _paused = true;
    try {
      await _send('PAUSE');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> resume() async {
    if (!_paused) return;
    try {
      await _send('RESUME');
    } catch (_) {}
    _paused = false;
    _playing = true;
    notifyListeners();
  }

  Future<void> stop() async {
    if (_process != null) {
      try {
        await _send('STOP');
      } catch (_) {}
    }
    _playing = false;
    _paused = false;
    _killProcess();
    notifyListeners();
  }

  void _killProcess() {
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    _outSub?.cancel();
    _outSub = null;
    for (final c in _pending) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }

  @override
  void dispose() {
    _killProcess();
    super.dispose();
  }
}
