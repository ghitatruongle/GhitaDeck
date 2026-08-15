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

  static const Duration silenceTimeout = Duration(seconds: 2);

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
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        '(New-Object System.Speech.Recognition.SpeechRecognitionEngine("$code")) -ne \$null',
      ],
    ).timeout(const Duration(seconds: 6));
    return result.exitCode == 0;
  }

  Future<void> start({String locale = 'en'}) async {
    if (_subtitle.listening) return;
    _subtitle.clear();
    // Re-arm the silence timer on every new line.
    _subtitle.addListener(_onLine);
    await _subtitle.start();
    _armSilenceTimer();
    notifyListeners();
  }

  void _onLine() {
    final phrase = _subtitle.currentText;
    if (phrase != null &&
        phrase.trim().isNotEmpty &&
        !phrase.contains('unavailable')) {
      onPhrase?.call(phrase.trim());
    }
    _armSilenceTimer();
    notifyListeners();
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceTimeout, () {
      if (_subtitle.listening) unawaited(stop());
    });
  }

  Future<void> stop() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _subtitle.removeListener(_onLine);
    await _subtitle.stop();
    notifyListeners();
  }

  /// Manually feed a phrase (for tests / external recognizers).
  void pushManualPhrase(String text) {
    _subtitle.pushManualText(text);
    _onLine();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _subtitle.removeListener(_onLine);
    _subtitle.dispose();
    super.dispose();
  }
}
