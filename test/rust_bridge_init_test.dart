import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/rust_bridge_init.dart';

/// B6c (2026-09-02): every component funnels its RustLib.init() through one
/// single-flight hub — concurrent callers (zip + image + htmlparse race in
/// the export worker) must never initialise the FRB binding twice.
void main() {
  tearDown(() {
    RustBridgeInit.reset();
    RustBridgeInit.initOverride = null;
  });

  test('B6c: concurrent ensureReady calls share ONE native init', () async {
    var calls = 0;
    RustBridgeInit.initOverride = () async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    };
    await Future.wait([
      RustBridgeInit.ensureReady(),
      RustBridgeInit.ensureReady(),
      RustBridgeInit.ensureReady(),
    ]);
    expect(calls, 1,
        reason: 'exactly one RustLib.init() per isolate (B6c: no double '
            'binding)');
  });

  test('B6c: a failed init is retried by the next caller', () async {
    var calls = 0;
    RustBridgeInit.initOverride = () async {
      calls++;
      if (calls == 1) throw StateError('borked dll');
    };
    await expectLater(RustBridgeInit.ensureReady(), throwsStateError);
    await RustBridgeInit.ensureReady(); // retries — a broken DLL must not be
    // cached as "ready" forever.
    expect(calls, 2);
  });

  test('B6c: after a successful init later callers do NOT re-init', () async {
    var calls = 0;
    RustBridgeInit.initOverride = () async {
      calls++;
    };
    await RustBridgeInit.ensureReady();
    await RustBridgeInit.ensureReady();
    await RustBridgeInit.ensureReady();
    expect(calls, 1);
  });
}
