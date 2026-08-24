import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider_manager.dart';

class ConfigService {
  static const String _providersKey = 'ai_providers_config';
  static const String _selectedProviderKey = 'selected_ai_provider_id';
  static const String _slidesKey = 'presentation_slides_config';
  static const String _effectKey = 'presentation_slide_effect';
  static const String _autoAdvanceKey = 'presentation_auto_advance';
  static const String _autoAdvanceSecondsKey = 'presentation_auto_advance_seconds';

  /// Track 65 OPT 27: slide payloads larger than this spill to a file next
  /// to the app data; SharedPreferences keeps only a pointer.
  static const int _largeDeckThreshold = 1 << 20; // 1 MB
  static const String _slidesFilePointerKey = 'presentation_slides_file_pointer';

  // Secure storage only for secrets (API keys).
  // Non-secret preferences remain in SharedPreferences.
  static const _secureStorage = FlutterSecureStorage();

  // A single writer prevents overlapping debounce/manual saves from racing.
  Future<void> _slidesWriteQueue = Future<void>.value();
  int _slidesWriteGeneration = 0;

  // ---- Providers (non-secret config stored in SharedPreferences) ----

  Future<void> saveProviders(List<AIProviderConfig> providers) async {
    final prefs = await SharedPreferences.getInstance();
    // Strip apiKey before writing to SharedPreferences — keys go to secure storage.
    final sanitized = providers.map((p) => p.copyWith(apiKey: '')).toList();
    await prefs.setString(_providersKey, jsonEncode(sanitized.map((p) => p.toMap()).toList()));
  }

  Future<List<AIProviderConfig>> loadProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_providersKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(jsonStr);
        final loaded = list.map((m) => AIProviderConfig.fromMap(Map<String, dynamic>.from(m as Map))).toList();
        // Re-inject apiKey from secure storage for each provider if available.
        for (final p in loaded) {
          final storedKey = await _secureStorage.read(key: _secureKeyFor(p.id));
          if (storedKey != null && storedKey.isNotEmpty) {
            final idx = loaded.indexOf(p);
            loaded[idx] = p.copyWith(apiKey: storedKey);
          }
        }
        if (loaded.isNotEmpty) return loaded;
      } catch (e) {
        debugPrint('Error loading providers: $e');
      }
    }
    return AIProviderConfig.allDefaults();
  }

  // ---- API Key secure storage ----

  static String _secureKeyFor(String providerId) => 'api_key_$providerId';

  Future<void> saveApiKey(String providerId, String apiKey) async {
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: _secureKeyFor(providerId));
    } else {
      await _secureStorage.write(key: _secureKeyFor(providerId), value: apiKey);
    }
  }

  Future<String?> loadApiKey(String providerId) async {
    return await _secureStorage.read(key: _secureKeyFor(providerId));
  }

  // ---- Selected provider (non-secret) ----

  Future<void> saveSelectedProvider(String? providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProviderKey, providerId ?? '');
  }

  Future<String?> getSelectedProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedProviderKey);
  }

  // ---- Slides & theme (non-secret) ----

  /// Track 65 OPT 27: decks whose serialized slides exceed 1 MB are spilled
  /// to `<docs>/GhitaPPT/decks/presentation_slides.json`; SharedPreferences
  /// then holds only a file pointer (and a legacy inline key is removed).
  /// Load is backward compatible with decks saved inline before this change.
  Future<void> saveSlides(List<Map<String, dynamic>> slides, String effectName,
      [String? deckMeta]) {
    final generation = ++_slidesWriteGeneration;
    final snapshot = slides.map((slide) => Map<String, dynamic>.from(slide)).toList();
    final previous = _slidesWriteQueue;
    final next = previous.catchError((_) {}).then((_) => _saveSlidesNow(
          snapshot,
          effectName,
          deckMeta,
          generation,
        ));
    _slidesWriteQueue = next;
    return next;
  }

  Future<void> _saveSlidesNow(
    List<Map<String, dynamic>> slides,
    String effectName,
    String? deckMeta,
    int generation,
  ) async {
    // A newer request supersedes a queued older snapshot before it touches disk.
    if (generation != _slidesWriteGeneration) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(slides);
    if (utf8.encode(jsonStr).length > _largeDeckThreshold) {
      final dir = await getApplicationDocumentsDirectory();
      final decksDir = Directory(p.join(dir.path, 'GhitaPPT', 'decks'));
      await decksDir.create(recursive: true);
      final file = File(p.join(decksDir.path, 'presentation_slides.json'));
      await _writeTextAtomically(file, jsonStr);
      await prefs.setString(_slidesFilePointerKey, file.path);
      await prefs.remove(_slidesKey);
    } else {
      await prefs.setString(_slidesKey, jsonStr);
      await prefs.remove(_slidesFilePointerKey);
    }
    await prefs.setString(_effectKey, effectName);
    if (deckMeta != null) {
      await prefs.setString('presentation_deck_meta', deckMeta);
    }
  }

  Future<void> _writeTextAtomically(File target, String content) async {
    final nonce = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final temp = File('${target.path}.$nonce.tmp');
    File? backup;
    await temp.parent.create(recursive: true);
    try {
      await temp.writeAsString(content, flush: true);
      if (await target.exists()) {
        backup = File('${target.path}.$nonce.bak');
        await target.rename(backup.path);
      }
      try {
        await temp.rename(target.path);
      } catch (_) {
        if (backup != null &&
            await backup.exists() &&
            !await target.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
      if (backup != null && await backup.exists()) await backup.delete();
    } finally {
      if (await temp.exists()) await temp.delete();
      if (backup != null && await backup.exists()) await backup.delete();
    }
  }

  Future<Map<String, dynamic>> loadSlides() async {
    final prefs = await SharedPreferences.getInstance();
    final effectName = prefs.getString(_effectKey) ?? 'none';
    final deckMeta = prefs.getString('presentation_deck_meta') ?? '';
    List<Map<String, dynamic>> slides = [];

    // Large-deck pointer file first (Track 65 OPT 27).
    final pointer = prefs.getString(_slidesFilePointerKey);
    if (pointer != null && pointer.isNotEmpty) {
      try {
        final file = File(pointer);
        if (await file.exists()) {
          final content = await file.readAsString();
          final List<dynamic> list = json.decode(content);
          slides =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          debugPrint('ConfigService: spilled deck file missing: $pointer');
        }
      } catch (e) {
        debugPrint('Error loading spilled slides: $e');
      }
      return {
        'slides': slides,
        'slide_effect': effectName,
        'deckMeta': deckMeta,
      };
    }

    // Legacy inline storage.
    final jsonStr = prefs.getString(_slidesKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(jsonStr);
        slides = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        debugPrint('Error loading slides: $e');
      }
    }
    return {'slides': slides, 'slide_effect': effectName, 'deckMeta': deckMeta};
  }

  // ---- Auto advance ("Timing") ----

  Future<void> saveAutoAdvance(bool enabled, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAdvanceKey, enabled);
    await prefs.setInt(_autoAdvanceSecondsKey, seconds.clamp(1, 60));
  }

  /// Returns [enabled] and per-slide [seconds] for automatic slide advance.
  Future<({bool enabled, int seconds})> loadAutoAdvance() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoAdvanceKey) ?? false;
    final seconds = (prefs.getInt(_autoAdvanceSecondsKey) ?? 5).clamp(1, 60);
    return (enabled: enabled, seconds: seconds);
  }

  // ---- System prompt ----

  static const String _systemPromptKey = 'ai_system_prompt';

  Future<void> saveSystemPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_systemPromptKey, prompt);
  }

  Future<String?> loadSystemPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_systemPromptKey);
  }
}
