import '../src/rust/frb_generated.dart' as rust_bridge;

/// One RustLib.init() per isolate (B6c).
///
/// Every component's "ensure ready" path — zip, image, htmlparse in the
/// export worker, plus [RustEngineService] on the UI isolate — funnels
/// through this single-flight hub, so concurrent callers never initialise
/// the flutter_rust_bridge binding twice ("Should not initialize
/// flutter_rust_bridge twice" used to make one of the racing components
/// report a permanent fallback).
class RustBridgeInit {
  RustBridgeInit._();

  static Future<void>? _inflight;
  static bool _ready = false;

  /// Test hook: replaces the real native init (unit tests have no DLL).
  static Future<void> Function()? initOverride;

  /// Test hook: clears the single-flight state (unit tests must not leak the
  /// ready flag between tests).
  static void reset() {
    _inflight = null;
    _ready = false;
  }

  static Future<void> ensureReady() async {
    if (_ready) return;
    await (_inflight ??= _load());
  }

  static Future<void> _load() async {
    try {
      final init = initOverride;
      if (init != null) {
        await init();
      } else {
        await rust_bridge.RustLib.init();
      }
      _ready = true;
    } finally {
      // A failed init is retried on the next call; a successful one short
      // circuits through [_ready] forever.
      _inflight = null;
    }
  }
}
