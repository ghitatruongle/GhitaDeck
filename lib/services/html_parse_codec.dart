import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../src/rust/api/htmlparse.dart' as rust_api;
import 'engine_audit_log.dart';
import 'rust_bridge_init.dart';

/// Engine preference for the HTML tokenizer (T13).
///
/// Mirrors [ZipEngineConfig]/[ImageEngineConfig]: [RustEngineService] keeps
/// [preferredRust] in sync with the Settings choice and calls [markRustReady]
/// after the DLL is loaded in this isolate. The sync [parseToJson] is only
/// used after a successful async init (see [HtmlParseCache]).
///
/// T13 measurement: parse is 16–21% of deck export time (see
/// `tool/t13_parse_profile_test.dart`) and the Rust tokenizer is parity-tested
/// against the Dart one (`test/htmlparse_parity_test.dart`), so Rust is the
/// default here, with Dart fallback on any error.
class HtmlParseEngineConfig {
  HtmlParseEngineConfig._();

  static bool preferredRust = true;

  static void setPreferredRust(bool value) => preferredRust = value;

  static bool _rustReady = false;

  static void markRustReady() {
    _rustReady = true;
  }

  /// Whether the DLL is usable in THIS isolate. The sync tokenizer cannot
  /// await an async init, so exports run the Dart path until
  /// [ensureRustReadyOnce] has completed here.
  static bool get rustReady => _rustReady;

  /// Test hook: replaces the real DLL load probe (unit tests have no exe dir).
  static Future<bool> Function()? rustReadyProbe;

  /// Loads the real `ghita_core.dll` once per isolate. Never throws — a
  /// missing/broken DLL simply resolves to "not usable" → Dart backend.
  static Future<bool> ensureRustReadyOnce() async {
    if (_rustReady) return true;
    if (rustReadyProbe != null) return rustReadyProbe!();
    try {
      // B6c: per-isolate single-flight hub (zip/image/htmlparse share it).
      await RustBridgeInit.ensureReady();
      _rustReady = true;
    } catch (e) {
      // "Should not initialize flutter_rust_bridge twice" means another
      // component already loaded the DLL in this isolate — treat as ready,
      // anything else as unavailable.
      final msg = e.toString().toLowerCase();
      _rustReady = msg.contains('twice');
      if (!_rustReady) {
        debugPrint('HtmlParseEngineConfig: ghita_core.dll unavailable '
            '($e); Dart html parser');
        await EngineAuditLog.append('engine fallback', 'htmlparse: $e');
      }
    }
    return _rustReady;
  }
}

/// One-shot tokenizer result: the four artifacts of a single HTML parse.
class HtmlParseResult {
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> blocksNoFirstH2;
  final String notes;
  final String subtitle;

  const HtmlParseResult({
    required this.blocks,
    required this.blocksNoFirstH2,
    required this.notes,
    required this.subtitle,
  });
}

/// Rust tokenizer facade (T13.4). Returns null on any failure so the caller
/// falls back to the Dart parser without propagating errors.
class HtmlParseCodec {
  HtmlParseCodec._();

  /// JSON decoding yields `Map<String, dynamic>`; the Dart block tree keeps
  /// string-keyed maps all the way down (runs/items/cells are
  /// `Map<String, String>`), so maps with no List values become
  /// `Map<String, String>` and maps with List values stay dynamic.
  static dynamic _deepMapValue(dynamic v) {
    if (v is Map) {
      final hasList = v.values.any((x) => x is List);
      if (hasList) {
        return Map<String, dynamic>.from(
            v.map((k, val) => MapEntry(k.toString(), _deepMapValue(val))));
      }
      return Map<String, String>.from(
          v.map((k, val) => MapEntry(k.toString(), val.toString())));
    }
    if (v is List) {
      return v.map(_deepMapValue).toList();
    }
    return v;
  }

  static List<Map<String, dynamic>> _decodeBlocks(Object? raw) {
    if (raw == null) return const [];
    return (raw as List)
        .map((e) => _deepMapValue(e) as Map<String, dynamic>)
        .toList();
  }

  /// Parse [html] to the shared block artifacts via Rust. Returns null when
  /// the engine is not used, not ready, or failed — callers then use Dart.
  static HtmlParseResult? parseToJson(String html) {
    if (!HtmlParseEngineConfig.rustReady) return null;
    try {
      final raw = rust_api.htmlparseBlocks(html: html);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map.containsKey('error')) return null;
      return HtmlParseResult(
        blocks: _decodeBlocks(map['blocks']),
        blocksNoFirstH2: _decodeBlocks(map['blocksNoFirstH2']),
        notes: map['notes'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('HtmlParseCodec: Rust tokenize failed ($e); Dart fallback');
      return null;
    }
  }
}
