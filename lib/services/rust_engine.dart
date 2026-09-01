import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../src/rust/api/engine.dart' as rust_api;
import '../src/rust/frb_generated.dart' as rust_bridge;
import 'zip_codec.dart';

/// Processing core the app runs export/media work on.
enum EngineKind { rust, dart }

/// How a Rust initialisation attempt ended up. [RustEngineService] never
/// crashes when the native library is missing or broken — it reports
/// [EngineStatus.fallingBack] and the app keeps working on the Dart path.
enum EngineStatus { rustReady, dart, fallingBack }

/// Reactive facade over the `ghita_core` Rust library (flutter_rust_bridge).
///
/// Track T01 (v2.0.5-demo): loads the DLL lazily on first access (Settings),
/// never at startup, so boot stays light and privacy posture is unchanged.
/// The default initialiser can be swapped in tests to simulate a broken DLL.
class RustEngineService extends ChangeNotifier {
  RustEngineService({Future<String> Function()? rustInit})
      : _rustInitOverride = rustInit;

  static const String prefKey = 'app_engine_kind';
  // T02 measurement-driven default: on media-heavy decks Dart encode (105–119
  // ms / 21.1 MB) beats Rust via FRB copies (132–142 ms), while Rust is 3.6×
  // faster on text-only deflate; see tool/benchmark_results_media.md.
  // Dart keeps the safe, measured-fast path for the demo; Rust stays opt-in.
  static const EngineKind defaultEngine = EngineKind.dart;

  /// Test hook: supplies the real [RustLib.init] + round-trip call unless a
  /// failing fake is injected to exercise the fallback path.
  Future<String> Function()? get rustInit => _rustInitOverride;
  final Future<String> Function()? _rustInitOverride;

  EngineKind _preferred = defaultEngine;
  EngineStatus _status = EngineStatus.dart;
  String _detail = '';
  bool _initialized = false;
  bool _initializing = false;

  EngineKind get preferred => _preferred;
  EngineStatus get status => _status;

  /// Version/detail line from the Rust crate, or the failure reason.
  String get detail => _detail;

  bool get isInitialized => _initialized;

  /// Loads the persisted engine preference (Settings -> Engine).
  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefKey);
    _preferred = stored == 'rust' ? EngineKind.rust : EngineKind.dart;
    ZipEngineConfig.setPreferredRust(_preferred == EngineKind.rust);
    notifyListeners();
  }

  /// Attempts Rust init once; on any failure keeps the app on Dart.
  /// Never throws — fallback is the contract, not an edge case.
  Future<void> ensureInitialized() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      final init = _rustInitOverride;
      final version =
          init != null ? await init() : await _defaultRustInit();
      _status = EngineStatus.rustReady;
      _detail = version;
      ZipEngineConfig.markRustReady();
    } catch (e) {
      _status = EngineStatus.fallingBack;
      _detail = '$e';
      debugPrint('RustEngineService: falling back to Dart — $e');
    } finally {
      _initialized = true;
      _initializing = false;
      notifyListeners();
    }
  }

  /// Persists the user's engine choice. Re-selecting Rust while it is still in
  /// fallback retries the native load.
  Future<void> setEngine(EngineKind kind) async {
    _preferred = kind;
    ZipEngineConfig.setPreferredRust(kind == EngineKind.rust);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, kind.name);
    if (kind == EngineKind.rust && _status != EngineStatus.rustReady) {
      _initialized = false;
      await ensureInitialized();
    } else {
      notifyListeners();
    }
  }

  Future<String> _defaultRustInit() async {
    await rust_bridge.RustLib.init();
    // Round-trip call proves the bridge, not just the DLL load.
    final version = await rust_api.helloZip();
    if (version.isEmpty) {
      throw StateError('ghita_core returned an empty version');
    }
    return version;
  }
}
