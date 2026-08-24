// T03 (v2.0.1-beta.2) — WebViewRuntimeService contract tests (phase 8).
//
// The probe goes through the webview_windows plugin channel
// (`io.jns.webview.win` / `getWebViewVersion`). Mocking that channel covers
// all three outcomes: runtime present (version string), runtime missing
// (null/empty), and the no-plugin case (MissingPluginException → false).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/webview_runtime_service.dart';

void _mockVersion(String? version) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('io.jns.webview.win'),
    (call) async =>
        call.method == 'getWebViewVersion' ? version : throw MissingPluginException(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No handler installed: the plugin is absent in the test environment,
    // which is exactly the "runtime missing" production scenario.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('io.jns.webview.win'),
            null);
  });

  group('probeWebView2', () {
    test('a reported version means the runtime is available', () async {
      _mockVersion('120.0.2210.61');
      expect(await WebViewRuntimeService.probeWebView2(), isTrue);
    });

    test('a null or empty version means it is not', () async {
      _mockVersion(null);
      expect(await WebViewRuntimeService.probeWebView2(), isFalse);

      _mockVersion('');
      expect(await WebViewRuntimeService.probeWebView2(), isFalse);
    });

    test('an unresponsive plugin channel degrades to false', () async {
      // No handler at all → invokeMethod throws MissingPluginException.
      expect(await WebViewRuntimeService.probeWebView2(), isFalse);
    });
  });

  group('service state machine', () {
    test('starts unknown, settles after the probe and notifies listeners',
        () async {
      _mockVersion('91.0.864.41');
      final service = WebViewRuntimeService();

      var notifications = 0;
      service.addListener(() => notifications++);

      await service.recheck();
      expect(service.probed, isTrue);
      expect(service.unknown, isFalse);
      expect(service.available, isTrue);
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('recheck picks up a newly installed (or removed) runtime', () async {
      _mockVersion(null);
      final service = WebViewRuntimeService();
      await service.recheck();
      expect(service.available, isFalse);

      // The user just installed the WebView2 runtime…
      _mockVersion('125.0.0.0');
      await service.recheck();
      expect(service.available, isTrue);
    });
  });
}
