import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../src/rust/api/htmlparse.dart' as rust_api;
import '../../services/engine_audit_log.dart';
import '../../services/rust_bridge_init.dart';

class HtmlParseEngineConfig {
  HtmlParseEngineConfig._();

  static bool preferredRust = true;

  static void setPreferredRust(bool value) => preferredRust = value;

  static bool _rustReady = false;

  static void markRustReady() {
    _rustReady = true;
  }

  static bool get rustReady => _rustReady;

  static Future<bool> Function()? rustReadyProbe;

  static Future<bool> ensureRustReadyOnce() async {
    if (_rustReady) return true;
    if (rustReadyProbe != null) return rustReadyProbe!();
    try {
      await RustBridgeInit.ensureReady();
      _rustReady = true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      _rustReady = msg.contains('twice');
      if (!_rustReady) {
        debugPrint(
          'HtmlParseEngineConfig: ghita_core.dll unavailable '
          '($e); Dart html parser',
        );
        await EngineAuditLog.append('engine fallback', 'htmlparse: $e');
      }
    }
    return _rustReady;
  }
}

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

class HtmlParseCodec {
  HtmlParseCodec._();

  static dynamic _deepMapValue(dynamic v) {
    if (v is Map) {
      final hasList = v.values.any((x) => x is List);
      if (hasList) {
        return Map<String, dynamic>.from(
          v.map((k, val) => MapEntry(k.toString(), _deepMapValue(val))),
        );
      }
      return Map<String, String>.from(
        v.map((k, val) => MapEntry(k.toString(), val.toString())),
      );
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
