import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../src/rust/api/zip.dart' as rust_api;
import '../src/rust/frb_generated.dart' as rust_bridge;

/// Engine preference shared across isolates (T02).
///
/// [RustEngineService] keeps [preferredRust] in sync with the Settings choice;
/// the export worker isolate reads it from the job message (plugins and
/// provider state do not cross isolates, this plain bool does).
class ZipEngineConfig {
  ZipEngineConfig._();

  // T02 measurement: Dart stays the default backend (media decks: Dart
  // 105–119 ms vs Rust 132–142 ms per 21.1 MB due to FRB data copies); Rust
  // wins text-only deflate (19.1 vs 68.7 ms) and stays available via Setting.
  static bool preferredRust = false;

  static void setPreferredRust(bool value) => preferredRust = value;

  static bool _rustReady = false;

  /// Called by [RustEngineService] after its own successful init — the DLL is
  /// already loaded in this isolate, so [ensureRustReadyOnce] must not retry
  /// (FRB throws "Should not initialize flutter_rust_bridge twice").
  static void markRustReady() {
    _rustReady = true;
  }

  /// Test hook: replaces the real DLL load probe (unit tests have no exe dir).
  static Future<bool> Function()? rustReadyProbe;

  /// Loads the real `ghita_core.dll` once per isolate. Never throws — a
  /// missing/broken DLL simply resolves to "not usable" → Dart backend.
  static Future<bool> ensureRustReadyOnce() async {
    if (_rustReady) return true;
    if (rustReadyProbe != null) return rustReadyProbe!();
    try {
      await rust_bridge.RustLib.init();
      _rustReady = true;
    } catch (e) {
      // "Should not initialize flutter_rust_bridge twice" means another
      // component already loaded the DLL in this isolate — treat as ready,
      // anything else as unavailable.
      final msg = e.toString().toLowerCase();
      _rustReady = msg.contains('twice');
      if (!_rustReady) {
        debugPrint(
            'ZipEngineConfig: ghita_core.dll unavailable ($e); Dart zip');
      }
    }
    return _rustReady;
  }
}

/// One member of the archive being encoded (name, bytes, stored flag).
class ZipCodecEntry {
  final String name;
  final Uint8List bytes;
  final bool stored;
  const ZipCodecEntry({
    required this.name,
    required this.bytes,
    required this.stored,
  });
}

/// ZIP backend selector with automatic fallback (T02).
///
/// Uses the Rust `ghita_zip` module when the user prefers it and the DLL
/// loads; any Rust failure falls back to the Dart `archive` encoder so the
/// pipeline never breaks. Both backends produce a standard ZIP: text members
/// deflated at [level], media members stored.
class ZipCodec {
  ZipCodec._();

  /// Unit-test hook: replaces the real Rust backend entirely.
  static Future<Uint8List> Function(
      List<ZipCodecEntry> entries, int level)? rustOverride;

  /// Which backend last produced a zip ('rust' | 'dart') — used by the
  /// integration probe to prove the DLL path was really exercised.
  static String lastBackend = '';

  /// Converts an [Archive] (built by the generators) preserving each member's
  /// stored/deflated decision: `compress == false` members are media that
  /// arrive already compressed → stored.
  static List<ZipCodecEntry> fromArchive(Archive archive) {
    final entries = <ZipCodecEntry>[];
    for (final f in archive.files) {
      dynamic content = f.content;
      if (content is InputStreamBase) {
        content = content.toUint8List();
      }
      if (content is! Uint8List) {
        content = Uint8List.fromList(content as List<int>);
      }
      entries.add(ZipCodecEntry(
        name: f.name,
        bytes: content,
        stored: !f.compress,
      ));
    }
    return entries;
  }

  static Future<Uint8List> encode(
    List<ZipCodecEntry> entries, {
    int level = 9,
  }) async {
    if (ZipEngineConfig.preferredRust &&
        await ZipEngineConfig.ensureRustReadyOnce()) {
      try {
        final fn = rustOverride ?? _realRustZip;
        final out = await fn(entries, level);
        lastBackend = 'rust';
        return out;
      } catch (e) {
        debugPrint('ZipCodec: Rust backend failed ($e); using Dart fallback');
      }
    }
    lastBackend = 'dart';
    return _dartZip(entries, level);
  }

  static Future<Uint8List> _realRustZip(
      List<ZipCodecEntry> entries, int level) async {
    return rust_api.zipArchive(
      entries: [
        for (final e in entries)
          rust_api.ZipEntry(name: e.name, data: e.bytes, stored: e.stored),
      ],
      level: level,
    );
  }

  static Uint8List _dartZip(List<ZipCodecEntry> entries, int level) {
    final archive = Archive();
    for (final e in entries) {
      archive.addFile(
        ArchiveFile(e.name, e.bytes.length, e.bytes)..compress = !e.stored,
      );
    }
    final bytes = ZipEncoder().encode(archive, level: level)!;
    return Uint8List.fromList(bytes);
  }
}
