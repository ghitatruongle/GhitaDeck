import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'subtitle_service.dart';

/// Dictation (Track 56, FEAT 90).
///
/// Wraps [SubtitleService]'s Windows SAPI recognizer and adds what dictation
/// needs on top:
///
/// * auto-stop after [silenceTimeout] of no recognized speech;
/// * a callback so the editor can insert each recognized phrase at the
///   cursor;
/// * per-locale availability reporting (EN always; VI only when the machine
///   has a Vietnamese recognizer — otherwise the UI warns and falls back to
///   EN).
class DictationService extends ChangeNotifier {
  final SubtitleService _subtitle = SubtitleService();
  Timer? _silenceTimer;
  bool _subscribed = false;
  int _handledLineCount = 0;

  static const Duration initialSilenceTimeout = Duration(seconds: 8);
  static const Duration silenceTimeout = Duration(seconds: 3);

  bool get listening => _subtitle.listening;

  /// Latest recognized phrase (null when silent).
  String? get lastPhrase => _subtitle.currentText;

  /// Callback fired with each new recognized phrase.
  void Function(String phrase)? onPhrase;

  /// Whether a specific locale's recognizer is likely available.
  Future<bool> localeAvailable(String locale) async {
    if (locale == 'en') return true;
    // SAPI Vietnamese availability probe — best-effort.
    try {
      return await _probeLocale(locale);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeLocale(String locale) async {
    final code = locale == 'vi' ? 'vi-VN' : locale;
    final process = await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Speech; '
            '\$culture = [System.Globalization.CultureInfo]::GetCultureInfo("$code"); '
            '\$recognizer = [System.Speech.Recognition.SpeechRecognitionEngine]::new(\$culture); '
            '\$recognizer.Dispose(); \$true',
      ],
    );
    final output = process.stdout.transform(systemEncoding.decoder).join();
    process.stderr.drain<void>();
    try {
      final exitCode =
          await process.exitCode.timeout(const Duration(seconds: 6));
      return exitCode == 0 &&
          (await output).trim().toLowerCase().contains('true');
    } on TimeoutException {
      process.kill();
      return false;
    }
  }

  Future<void> start({String locale = 'en'}) async {
    if (_subtitle.listening) return;
    _handledLineCount = 0;
    _subtitle.clear();
    // Re-arm the silence timer on every new line.
    if (!_subscribed) {
      _subtitle.addListener(_onLine);
      _subscribed = true;
    }
    await _subtitle.start(locale: locale);
    if (_subtitle.listening) {
      _armSilenceTimer(initialSilenceTimeout);
    }
    notifyListeners();
  }

  void _onLine() {
    final lines = _subtitle.lines;
    if (_handledLineCount > lines.length) _handledLineCount = 0;
    var receivedPhrase = false;
    for (var i = _handledLineCount; i < lines.length; i++) {
      final line = lines[i];
      final phrase = line.text.trim();
      if (!line.isError && phrase.isNotEmpty) {
        onPhrase?.call(phrase);
        receivedPhrase = true;
      }
    }
    _handledLineCount = lines.length;
    if (_subtitle.listening && receivedPhrase) {
      _armSilenceTimer(silenceTimeout);
    }
    notifyListeners();
  }

  void _armSilenceTimer(Duration timeout) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(timeout, () {
      if (_subtitle.listening) unawaited(stop());
    });
  }

  Future<void> stop() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (_subscribed) {
      _subtitle.removeListener(_onLine);
      _subscribed = false;
    }
    await _subtitle.stop();
    notifyListeners();
  }

  /// Manually feed a phrase (for tests / external recognizers).
  void pushManualPhrase(String text) {
    _subtitle.pushManualText(text);
    if (!_subscribed) _onLine();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    if (_subscribed) _subtitle.removeListener(_onLine);
    _subtitle.dispose();
    super.dispose();
  }
}
